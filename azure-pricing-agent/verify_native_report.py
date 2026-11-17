"""Reconcile exported native reports with the actual response's API evidence."""

import argparse
import json
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

if not __debug__:
    raise RuntimeError("Run verification without Python -O; evidence assertions must remain enabled.")


def reconcile(response, exported):
    assert response["status"] == "completed", "Native response was not completed"
    calls = [
        item for item in response["output"]
        if item["type"] == "mcp_call" and item.get("status") == "completed"
    ]
    assert calls, "No completed native API call"
    evidence = []
    for call in calls:
        assert not call.get("error"), "API call returned an error"
        arguments = json.loads(call["arguments"])
        text = call["output"].lstrip()
        data, end = json.JSONDecoder().raw_decode(text)
        if "response" in data:
            data = json.loads(data["response"])
        suffix = text[end:].strip()
        if suffix:
            assert json.loads(suffix)["structuredResponse"] == data
        evidence.append((arguments, data))
    code_calls = [
        item for item in response["output"]
        if item["type"] == "code_interpreter_call"
        and item.get("status") == "completed" and item.get("code", "").strip()
    ]
    assert code_calls, "No real native Python execution"
    assert any("calculate_report" in item["code"] for item in code_calls)
    emitted = []
    for call in code_calls:
        for output in call.get("outputs", []):
            if output["type"] == "logs":
                for line in output["logs"].splitlines():
                    if line.startswith('{"report":'):
                        emitted.append(json.loads(line))
    assert exported in emitted, "Downloaded report differs from executed JSON output"
    for pages in exported["lookups"]:
        for page in pages:
            parts = urlsplit(page["url"])
            assert parts.scheme == "https" and parts.netloc == "prices.azure.com"
            assert parts.path == "/api/retail/prices"
            query = parse_qs(parts.query)
            assert any(
                query == {key: [str(value)] for key, value in arguments.items()}
                and page["data"] == data
                for arguments, data in evidence
            ), "Saved URL or full API page differs from the actual tool call"
            assert page["data"]["Count"] == len(page["data"]["Items"])
    report = exported["report"]
    assert report["status"] == "partial_meter_estimate"
    assert report["unpriced_components"], "Dependencies must remain explicit"
    scenarios = {}
    for name, scenario in report["scenarios"].items():
        total = Decimal("0")
        for line in scenario["lines"]:
            matches = [
                row for pages in exported["lookups"] for page in pages
                if page["url"] == line["source_url"]
                for row in page["data"]["Items"]
                if row["meterId"] == line["meter_id"]
            ]
            assert matches, "Reported meter absent from exact source page"
            assert all(row["currencyCode"] == report["currency"] for row in matches)
            assert all(row["armRegionName"] == line["region"] for row in matches)
            assert all(row["type"] == "Consumption" for row in matches)
            assert all(row["unitOfMeasure"] == line["unit_of_measure"] for row in matches)
            raw = Decimal("0")
            for tier in line["tiers"]:
                rate = Decimal(tier["rate"])
                assert any(
                    Decimal(str(row["retailPrice"])) == rate
                    and Decimal(str(row["tierMinimumUnits"]))
                    == Decimal(tier["tier_start_billable_units"])
                    for row in matches
                ), "Calculated tier rate differs from retrieved meter"
                cost = Decimal(tier["billable_units"]) * rate
                assert cost == Decimal(tier["unrounded_cost"])
                raw += cost
            monthly = raw.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
            assert monthly == Decimal(line["monthly_cost"])
            total += monthly
        assert total == Decimal(scenario["monthly_priced_subtotal"])
        assert total * 12 == Decimal(scenario["annual_priced_projection"])
        scenarios[name] = {
            "monthly": str(total), "annual": str(total * 12),
            "priced_lines": len(scenario["lines"]),
        }
    return {
        "native_response_id": response["id"],
        "native_response_status": response["status"],
        "api_calls": len(calls),
        "executed_code_calls": len(code_calls),
        "exact_api_pages_and_urls_match": True,
        "download_matches_emitted_native_report": True,
        "decimal_arithmetic_reconciles": True,
        "scenarios": scenarios,
        "unpriced_components": report["unpriced_components"],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("response", type=Path)
    parser.add_argument("report", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = reconcile(
        json.loads(args.response.read_text(encoding="utf-8")),
        json.loads(args.report.read_text(encoding="utf-8")),
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
