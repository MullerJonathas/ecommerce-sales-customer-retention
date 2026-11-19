import sqlite3
from pathlib import Path
import pandas as pd

BASE_DIR = Path(__file__).resolve().parent.parent
DB_PATH = BASE_DIR / "olist.db"
RAW_DIR = BASE_DIR / "data" / "raw"
SCHEMA_PATH = BASE_DIR / "sql" / "01_schema.sql"

CSV_TO_TABLE = {
    "olist_customers_dataset.csv": "customers",
    "olist_products_dataset.csv": "products",
    "product_category_name_translation.csv": "category_translation",
    "olist_orders_dataset.csv": "orders",
    "olist_order_items_dataset.csv": "order_items",
    "olist_order_payments_dataset.csv": "order_payments",
}

conn = sqlite3.connect(DB_PATH)
conn.execute("PRAGMA foreign_keys = ON;")

with open(SCHEMA_PATH, "r", encoding="utf-8") as f:
    conn.executescript(f.read())

for csv_name, table_name in CSV_TO_TABLE.items():
    csv_file = RAW_DIR / csv_name
    if not csv_file.exists():
        print(f"Aviso: {csv_file} não encontrado, pulando.")
        continue

    df = pd.read_csv(csv_file)

    if table_name == "category_translation":
        df = df.dropna(subset=["product_category_name"])

    df.to_sql(table_name, conn, if_exists="append", index=False)
    print(f"Carregada tabela '{table_name}' com {len(df)} linhas.")

conn.commit()
conn.close()
print("Banco SQLite atualizado com sucesso.")