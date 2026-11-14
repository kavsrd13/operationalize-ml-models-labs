"""Create a small, relational Olist teaching sample from the course ZIP."""
import csv
import io
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT.parent / "datasets" / "olist" / "Ecommerce Dataset.zip"
OUTPUT = ROOT / "data"


def read_table(archive, name):
    with archive.open(f"Ecommerce Dataset/olist_{name}_dataset.csv") as source:
        return list(csv.DictReader(io.TextIOWrapper(source, encoding="utf-8")))


def write_table(name, rows, columns):
    OUTPUT.mkdir(exist_ok=True)
    with (OUTPUT / f"{name}.csv").open("w", newline="", encoding="utf-8") as target:
        writer = csv.DictWriter(target, fieldnames=columns)
        writer.writeheader()
        writer.writerows({column: row[column] for column in columns} for row in rows)


with zipfile.ZipFile(SOURCE) as archive:
    orders = read_table(archive, "orders")[:300]
    order_ids = {row["order_id"] for row in orders}
    items = [row for row in read_table(archive, "order_items") if row["order_id"] in order_ids]
    customer_ids = {row["customer_id"] for row in orders}
    customers = [row for row in read_table(archive, "customers") if row["customer_id"] in customer_ids]
    seller_ids = {row["seller_id"] for row in items}
    sellers = [row for row in read_table(archive, "sellers") if row["seller_id"] in seller_ids]

write_table("orders", orders, ["order_id", "customer_id", "order_status", "order_purchase_timestamp"])
write_table("order_items", items, ["order_id", "order_item_id", "product_id", "seller_id", "price", "freight_value"])
write_table("customers", customers, ["customer_id", "customer_city", "customer_state"])
write_table("sellers", sellers, ["seller_id", "seller_city", "seller_state"])
print({"orders": len(orders), "items": len(items), "customers": len(customers), "sellers": len(sellers)})
