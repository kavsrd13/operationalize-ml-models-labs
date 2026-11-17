import copy
import unittest
from datetime import datetime, timedelta, timezone

from pricing_math import PricingError, calculate_report


class NativePricingTests(unittest.TestCase):
    def setUp(self):
        self.row = {
            "currencyCode": "USD", "armRegionName": "eastus",
            "meterId": "meter", "skuId": "sku", "productId": "product",
            "serviceName": "Virtual Machines", "productName": "DSv3 Series",
            "meterName": "D2s v3", "armSkuName": "Standard_D2s_v3",
            "unitOfMeasure": "1 Hour", "type": "Consumption",
            "tierMinimumUnits": 0, "retailPrice": 0.096,
            "effectiveStartDate": "2026-01-01T00:00:00Z",
        }
        self.page = {
            "url": "https://prices.azure.com/api/retail/prices?$filter=test",
            "retrieved_at": datetime.now(timezone.utc).isoformat(),
            "data": {"Items": [self.row], "NextPageLink": None, "Count": 1},
        }
        self.line = {
            "label": "VM compute", "lookup_index": 0,
            "meter_id": "meter", "sku_id": "sku", "product_id": "product",
            "region": "eastus", "arm_sku": "Standard_D2s_v3", "currency": "USD",
            "quantities": {"low": "365", "base": "730", "high": "1460"},
        }

    def report(self, pages=None, lines=None):
        return calculate_report(
            [pages or [self.page]], lines or [self.line],
            ["Explicit monthly hours"], ["Disks", "Egress"],
        )

    def test_monthly_and_annual_reconciliation(self):
        report = self.report()
        self.assertEqual(report["status"], "partial_meter_estimate")
        for name, monthly, annual in (
            ("low", "35.04", "420.48"), ("base", "70.08", "840.96"),
            ("high", "140.16", "1681.92"),
        ):
            self.assertEqual(report["scenarios"][name]["monthly_priced_subtotal"], monthly)
            self.assertEqual(report["scenarios"][name]["annual_priced_projection"], annual)

    def test_multiple_lines_sum_rounded_costs(self):
        second = dict(self.line, label="Second VM")
        self.assertEqual(
            self.report(lines=[self.line, second])["scenarios"]["base"]["monthly_priced_subtotal"],
            "140.16",
        )

    def test_identity_must_be_present_in_api_response(self):
        self.line["meter_id"] = "fabricated"
        with self.assertRaises(PricingError):
            self.report()

    def test_rejects_omitted_api_rows(self):
        self.page["data"]["Count"] = 2
        with self.assertRaisesRegex(PricingError, "All Items"):
            self.report()

    def test_rejects_different_arm_sku(self):
        self.row["armSkuName"] = "Standard_D2_v3"
        with self.assertRaisesRegex(PricingError, "ARM SKU"):
            self.report()

    def test_complete_tiers_across_pages(self):
        next_url = "https://prices.azure.com/api/retail/prices?$skip=1000"
        self.row["retailPrice"] = 1
        self.page["data"]["NextPageLink"] = next_url
        second = copy.deepcopy(self.page)
        second["url"] = next_url
        second["data"]["NextPageLink"] = None
        second["data"]["Items"][0].update(tierMinimumUnits=500, retailPrice=0.5)
        self.assertEqual(
            self.report(pages=[self.page, second])["scenarios"]["base"]["monthly_priced_subtotal"],
            "615.00",
        )

    def test_rejects_incomplete_stale_or_untrusted_evidence(self):
        for mutation in ("next", "stale", "host", "cycle"):
            with self.subTest(mutation=mutation):
                page = copy.deepcopy(self.page)
                pages = [page]
                if mutation == "next":
                    page["data"]["NextPageLink"] = page["url"] + "&$skip=1000"
                elif mutation == "stale":
                    page["retrieved_at"] = (
                        datetime.now(timezone.utc) - timedelta(minutes=11)
                    ).isoformat()
                elif mutation == "host":
                    page["url"] = "https://example.com/api/retail/prices"
                else:
                    page["data"]["NextPageLink"] = page["url"]
                    pages.append(copy.deepcopy(page))
                with self.assertRaises(PricingError):
                    self.report(pages=pages)

    def test_unsupported_compound_units_are_not_priced(self):
        self.row["unitOfMeasure"] = "1 GB/Month"
        with self.assertRaisesRegex(PricingError, "Unsupported"):
            self.report()

    def test_key_vault_standard_operation_blocks(self):
        self.row.update(
            serviceName="Key Vault", productName="Key Vault", skuName="Standard",
            meterName="Operations", armSkuName="", unitOfMeasure="10K", retailPrice=0.03,
        )
        self.line.update(
            arm_sku=None, quantities={"low": 100000, "base": 1000000, "high": 10000000},
        )
        report = self.report()
        for name, monthly in (("low", "0.30"), ("base", "3.00"), ("high", "30.00")):
            line = report["scenarios"][name]["lines"][0]
            self.assertEqual(line["monthly_cost"], monthly)
            self.assertEqual(line["quantity_unit"], "Operations")
            self.assertEqual(line["unit_of_measure"], "10K")
        for field, value in (
            ("serviceName", "Another service"), ("skuName", "Premium"),
            ("meterName", "Advanced Operations"), ("productName", "Managed HSM"),
        ):
            with self.subTest(field=field):
                previous = self.row[field]
                self.row[field] = value
                with self.assertRaisesRegex(PricingError, "Unsupported"):
                    self.report()
                self.row[field] = previous

    def test_commitment_conflicts_and_invalid_quantities_rejected(self):
        for mutation in ("reservation", "conflict", "nan", "order", "currency"):
            with self.subTest(mutation=mutation):
                page = copy.deepcopy(self.page)
                line = copy.deepcopy(self.line)
                if mutation == "reservation":
                    page["data"]["Items"][0]["type"] = "Reservation"
                elif mutation in ("conflict", "currency"):
                    other = copy.deepcopy(page["data"]["Items"][0])
                    other["retailPrice" if mutation == "conflict" else "currencyCode"] = (
                        0.15 if mutation == "conflict" else "EUR"
                    )
                    page["data"]["Items"].append(other)
                    page["data"]["Count"] = 2
                elif mutation == "nan":
                    line["quantities"]["base"] = "NaN"
                else:
                    line["quantities"]["low"] = "800"
                with self.assertRaises(PricingError):
                    self.report(pages=[page], lines=[line])


if __name__ == "__main__":
    unittest.main()
