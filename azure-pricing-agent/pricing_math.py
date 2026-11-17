"""Standard-library pricing calculations, usable in Foundry Code Interpreter."""

import re
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from urllib.parse import urlparse


class PricingError(ValueError):
    pass


def decimal_value(value):
    try:
        result = Decimal(str(value))
    except InvalidOperation as error:
        raise PricingError("Invalid numeric quantity or price.") from error
    if not result.is_finite() or result < 0:
        raise PricingError("Quantities and prices must be finite and nonnegative.")
    return result


def money(value):
    return str(value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP))


def price_group(row):
    fields = (
        "meterId", "skuId", "productId", "armRegionName", "currencyCode",
        "type", "unitOfMeasure", "effectiveStartDate", "reservationTerm",
    )
    return tuple(str(row.get(field, "")) for field in fields)


def unit_scale(unit, row=None):
    # Key Vault's documented 10,000-operation block omits the unit name in the API.
    if unit == "10K" and row is not None and all(
        row.get(field) == value for field, value in (
            ("serviceName", "Key Vault"), ("productName", "Key Vault"),
            ("skuName", "Standard"), ("meterName", "Operations"),
            ("type", "Consumption"),
        )
    ):
        return Decimal(10000), "Operations"
    match = re.fullmatch(
        r"(\d+(?:\.\d+)?)([KM]?)\s+"
        r"(Hour|Month|GB|GiB|TB|Transactions|Requests|Tokens|Operations)",
        unit,
        re.IGNORECASE,
    )
    if match is None:
        raise PricingError("Unsupported billable unit: " + unit)
    scale = Decimal(match[1]) * {"": 1, "K": 1000, "M": 1000000}[match[2].upper()]
    if scale <= 0:
        raise PricingError("Unit scale must be positive.")
    return scale, match[3]


def tier_cost(rows, quantity):
    """Quantity is expressed in multiples of the advertised billable unit."""
    quantity = decimal_value(quantity)
    rates = {}
    for row in rows:
        if row.get("type") != "Consumption":
            raise PricingError(
                "Only Consumption is validated. Commitments and DevTest require "
                "service-specific eligibility and billing rules."
            )
        start = decimal_value(row["tierMinimumUnits"])
        rate = decimal_value(row["retailPrice"])
        if start in rates and rates[start] != rate:
            raise PricingError("Ambiguous rates at the same tier boundary.")
        rates[start] = rate
    starts = sorted(rates)
    if not starts or starts[0] != 0:
        raise PricingError("A complete tier group beginning at zero is required.")
    total = Decimal(0)
    details = []
    for index, start in enumerate(starts):
        end = starts[index + 1] if index + 1 < len(starts) else quantity
        used = max(Decimal(0), min(quantity, end) - start)
        if used:
            charge = used * rates[start]
            total += charge
            details.append({
                "tier_start_billable_units": str(start),
                "billable_units": str(used),
                "rate": str(rates[start]),
                "unrounded_cost": str(charge),
                "formula": f"{used} * {rates[start]}",
            })
    return total, details


def validate_source(url):
    parsed = urlparse(url)
    if (
        parsed.scheme != "https" or parsed.hostname != "prices.azure.com"
        or parsed.path != "/api/retail/prices" or parsed.port not in (None, 443)
        or parsed.username or parsed.password or parsed.fragment
    ):
        raise PricingError("Evidence must come from the Azure Retail Prices API.")


def lookup_rows(pages, now):
    if not isinstance(pages, list) or not 1 <= len(pages) <= 4:
        raise PricingError("A lookup must contain one to four complete API pages.")
    rows = []
    seen = set()
    next_url = None
    for index, page in enumerate(pages):
        url = page["url"]
        validate_source(url)
        if url in seen or (index and url != next_url):
            raise PricingError("Pagination is cyclic or does not follow NextPageLink.")
        seen.add(url)
        retrieved = datetime.fromisoformat(page["retrieved_at"].replace("Z", "+00:00"))
        if retrieved.tzinfo is None:
            raise PricingError("Retrieval timestamps must include a time zone.")
        age = (now - retrieved).total_seconds()
        if not -60 <= age < 600:
            raise PricingError("Price evidence expired or has a future timestamp.")
        data = page["data"]
        if not isinstance(data["Items"], list):
            raise PricingError("Items must be the actual API response array.")
        if type(data.get("Count")) is not int or data["Count"] != len(data["Items"]):
            raise PricingError("All Items must be preserved; Count must match the page.")
        rows.extend(data["Items"])
        next_url = data.get("NextPageLink")
        if index < len(pages) - 1 and not next_url:
            raise PricingError("Unexpected page after the lookup was complete.")
    if next_url:
        raise PricingError("Incomplete lookups cannot be priced. Narrow the filter.")
    return rows


def calculate_report(lookups, lines, assumptions, unpriced_components):
    """Price selected identities from complete, recent native API responses.

    lookups is an array of page arrays; each page has url, retrieved_at and data
    (the unmodified API JSON). Each line has label, lookup_index, meter_id, sku_id,
    product_id, region, arm_sku (the user's ARM SKU, or None when unspecified),
    currency and quantities (explicit monthly low/base/high raw units).
    The model selects meters; this function validates evidence and arithmetic.
    """
    if not isinstance(lookups, list) or not 1 <= len(lookups) <= 8:
        raise PricingError("Provide one to eight filtered lookups.")
    if not isinstance(lines, list) or not 1 <= len(lines) <= 40:
        raise PricingError("Provide one to forty selected meter lines.")
    if not isinstance(assumptions, list) or not isinstance(unpriced_components, list):
        raise PricingError("Assumptions and unpriced components must be arrays.")
    now = datetime.now(timezone.utc)
    catalog = [lookup_rows(pages, now) for pages in lookups]
    scenarios = {"low": [], "base": [], "high": []}
    totals = dict.fromkeys(scenarios, Decimal(0))
    currency = None
    for line in lines:
        index = line["lookup_index"]
        if type(index) is not int or not 0 <= index < len(catalog):
            raise PricingError("Invalid lookup_index.")
        rows = [
            row for row in catalog[index]
            if all(row.get(field) == line[key] for field, key in (
                ("meterId", "meter_id"), ("skuId", "sku_id"),
                ("productId", "product_id"), ("armRegionName", "region"),
            ))
        ]
        if not rows:
            raise PricingError("Selected meter identity was not retrieved.")
        if len({price_group(row) for row in rows}) != 1:
            raise PricingError("Selected meter has conflicting variants or effective dates.")
        row = rows[0]
        if line["arm_sku"] is not None and row.get("armSkuName") != line["arm_sku"]:
            raise PricingError("Retrieved ARM SKU does not match the requested SKU.")
        if row["currencyCode"] != line["currency"]:
            raise PricingError("Retrieved currency does not match the requested currency.")
        if currency is not None and currency != row["currencyCode"]:
            raise PricingError("Cannot sum mixed currencies.")
        currency = row["currencyCode"]
        scale, unit = unit_scale(row["unitOfMeasure"], row)
        if set(line["quantities"]) != set(scenarios):
            raise PricingError("Supply explicit monthly low, base and high quantities.")
        quantities = [decimal_value(line["quantities"][name]) for name in scenarios]
        if quantities != sorted(quantities):
            raise PricingError("Require low <= base <= high quantities.")
        for name, quantity in zip(scenarios, quantities):
            cost, tiers = tier_cost(rows, quantity / scale)
            totals[name] += Decimal(money(cost))
            scenarios[name].append({
                "label": line["label"], "service": row["serviceName"],
                "product": row["productName"], "sku": row.get("armSkuName"),
                "meter": row["meterName"], "meter_id": row["meterId"],
                "region": row["armRegionName"], "quantity": str(quantity),
                "quantity_unit": unit, "unit_of_measure": row["unitOfMeasure"],
                "billable_quantity": str(quantity / scale), "tiers": tiers,
                "monthly_cost": money(cost),
                "source_url": lookups[index][0]["url"],
                "retrieved_at": lookups[index][0]["retrieved_at"],
                "effective_start": row.get("effectiveStartDate"),
            })
    return {
        "status": "partial_meter_estimate", "currency": currency,
        "assumptions": assumptions, "unpriced_components": unpriced_components,
        "rounding": "Round each monthly line half-up to two decimals, then sum.",
        "billing_coverage": (
            "Selected PAYG meters only. Free allowances, minimum bills, included "
            "capacity, shared aggregation, commitments and dependencies are not inferred."
        ),
        "scenarios": {
            name: {
                "lines": scenarios[name], "monthly_priced_subtotal": money(total),
                "annual_priced_projection": money(total * 12),
            }
            for name, total in totals.items()
        },
    }
