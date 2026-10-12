"""Cleans retail_sales_raw.csv -> retail_sales_clean.csv and writes a cleaning log.
Every step mirrors an Excel operation (shown in brackets) so the Excel workbook and Python give identical results."""
import pandas as pd, numpy as np, json
raw = pd.read_csv("data/retail_sales_raw.csv")
log = [("Rows in raw file", len(raw))]

# 1. Standardise text  [Excel: TRIM + PROPER]
for c in ["Region","Segment","Customer Name","City","State","Category","Sub-Category","Ship Mode"]:
    raw[c] = raw[c].astype("string").str.strip().str.replace(r"\s+"," ",regex=True).str.title()
log.append(("Text columns trimmed & converted to Proper Case", 8))

# 2. Convert text dates to real dates  [Excel: DATEVALUE / Text to Columns]
raw["Order Date"] = pd.to_datetime(raw["Order Date"], format="%d-%m-%Y")
raw["Ship Date"]  = pd.to_datetime(raw["Ship Date"],  format="%d-%m-%Y")

# 3. Discount stored as whole numbers (20 instead of 0.20)  [Excel: IF(Q2>1,Q2/100,Q2)]
n = int((raw["Discount"]>1).sum()); raw.loc[raw["Discount"]>1,"Discount"] /= 100
log.append(("Discount values rescaled (20 -> 0.20)", n))

# 4. Fill missing City from the customer's other orders  [Excel: INDEX/MATCH on Customer ID]
city_map = raw.dropna(subset=["City"]).groupby("Customer ID")["City"].agg(lambda s: s.mode().iat[0])
miss = raw["City"].isna(); raw.loc[miss,"City"] = raw.loc[miss,"Customer ID"].map(city_map)
log.append(("Missing City filled from customer's other orders", int(miss.sum())))
still = raw["City"].isna().sum(); raw["City"] = raw["City"].fillna("Unknown")
log.append(("Missing City still unresolved -> 'Unknown'", int(still)))

# 5. Remove invalid rows  [Excel: Filter + delete]
bad_ship = raw["Ship Date"] < raw["Order Date"]; bad_qty = raw["Quantity"] <= 0
log.append(("Rows removed: Ship Date before Order Date", int(bad_ship.sum())))
log.append(("Rows removed: Quantity <= 0", int(bad_qty.sum())))
raw = raw[~(bad_ship | bad_qty)]

# 6. Remove duplicates on Order ID + Product ID  [Excel: Data > Remove Duplicates]
before = len(raw); raw = raw.drop_duplicates(subset=["Order ID","Product ID"], keep="first")
log.append(("Duplicate order lines removed", before-len(raw)))

raw = raw.sort_values(["Order ID","Product ID"]).reset_index(drop=True)
log.append(("Rows in clean file", len(raw)))
raw.to_csv("data/retail_sales_clean.csv", index=False)
pd.DataFrame(log, columns=["Step","Rows affected"]).to_csv("data/cleaning_log.csv", index=False)
for k,v in log: print(f"{k:55s}{v}")
