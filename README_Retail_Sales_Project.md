# Retail Sales Performance & Profitability Analysis
**Excel | SQL | Power BI** - find where a growing retailer is losing profit

> **Summary:** Sales grew 25% in 2024 and 18% in 2025, but profit margin stayed flat at ~14%. This project cleans messy order data in Excel, analyses it with SQL and shows the results in Power BI. Main finding: **discounts above 20% make orders loss-making**, and two sub-categories (Tables, Machines) and one region (Central) drag margin down.

![Power BI dashboard](images/powerbi_dashboard.png)
*(add your own Power BI screenshot here after building the dashboard)*

---

## 1. Business problem
A multi-category Indian retailer (Furniture, Office Supplies, Technology) sells to Consumer, Corporate and Home Office customers across five regions. Revenue is rising, but management cannot see which products, regions, customers or discount levels create or destroy profit. Full brief: `Retail_02_Business_Problem_Statement.pdf`.

## 2. Dataset
- **Synthetic** order-line data (not from a real company), Jan 2023 - Dec 2025, currency INR.
- Raw file: **9,153 rows, 18 columns** with deliberate quality problems. Cleaned file: **8,939 rows**, 4,295 orders, 832 customers, 65 products, 20 states.

| Column group | Columns |
|---|---|
| Order | Order ID, Order Date, Ship Date, Ship Mode |
| Customer | Customer ID, Customer Name, Segment, Region, State, City |
| Product | Product ID, Category, Sub-Category, Product Name |
| Measures | Sales (net of discount), Quantity, Discount, Profit |

## 3. Files in this repository
| # | File | Purpose |
|---|---|---|
| 1 | `Retail_01_sales_raw_data.csv` | Raw data as received |
| 2 | `Retail_02_Business_Problem_Statement.pdf` | Business problem, objectives, questions, approach |
| 3 | `Retail_03_Data_Cleaning_in_Excel.xlsx` | Data cleaning with Excel formulas (sheets: Cleaning_Steps, Clean_Data, Raw_Data, Cleaning) |
| 4 | `Retail_04_sales_cleaned_data.csv` | Cleaned data exported from the Excel workbook |
| 5 | `Retail_05_sales_analysis_queries.sql` | Schema, data-quality checks and 15 analysis queries |
| 6 | `Retail_06_SQL_Queries_with_Output_Screenshots.pdf` | Every query with its output screenshot and insight |
| 7 | `Retail_07_PowerBI_Dashboard_Kit.zip` | Data model CSVs, Power BI build guide with DAX, layout reference |
| - | `retail_sales_dashboard.pbix` | **Your Power BI file** (build it with the guide and add it here) |

## 4. Tools & skills
| Tool | What I did |
|---|---|
| **Excel** | Cleaned data with `TRIM`, `PROPER`, `DATE/VALUE/LEFT/MID/RIGHT`, `IF`, `INDEX/MATCH`, `COUNTIFS` flags for duplicates and invalid rows; every cleaning step counted by formula |
| **SQL** | Normalised the data into 4 tables, wrote 7 data-quality checks and 15 queries using joins, CTEs, `CASE`, window functions (`LAG`, `RANK`, `ROW_NUMBER`, `NTILE`, moving average) and RFM segmentation |
| **Power BI** | Star schema (fact_sales + customer, product, date dimensions), DAX measures (YoY, YTD, margin, loss rate), 3 report pages |

## 5. Data cleaning (Excel)
| Problem found | Rows | Excel fix |
|---|---|---|
| Duplicate order lines (same Order ID + Product ID) | 177 | `COUNTIFS` duplicate flag, then filter |
| Region / Segment / Name casing and extra spaces | ~1,100 cells | `=PROPER(TRIM())` |
| Dates stored as text (dd-mm-yyyy) | all | `=DATE(VALUE(RIGHT()),VALUE(MID()),VALUE(LEFT()))` |
| Discount stored as 20 instead of 0.20 | 16 | `=IF(Q2>1,Q2/100,Q2)` |
| Missing City | 109 | `INDEX/MATCH` from the same customer's other orders |
| Ship Date before Order Date | 25 | flag and filter out |
| Quantity = 0 | 12 | flag and filter out |

**Result:** 9,153 raw rows -> 8,939 clean rows (214 removed). The `Cleaning_Steps` sheet shows live counts and how to repeat each step by hand.

## 6. SQL analysis
The cleaned CSV is loaded into a staging table, then split into `customers`, `products`, `orders` and `order_lines`. The 15 queries answer: KPIs, year-over-year growth, monthly trend, category and sub-category profit, region performance, discount-band impact, worst products, profit concentration (Pareto), RFM segments, delivery performance, top sub-categories per region, seasonality, segment x category margin, repeat-purchase rate and discount leakage. Outputs are in `Retail_06_SQL_Queries_with_Output_Screenshots.pdf`.

## 7. Key findings
| # | Finding |
|---|---|
| 1 | Sales INR 53.6 M, profit INR 7.4 M, margin 13.8%; 4,295 orders; average order INR 12,476 |
| 2 | Sales grew +25% (2024) and +18% (2025) but margin stayed 13.6-14.4% |
| 3 | **Margin by discount band: 27% (none) -> 19% (1-10%) -> 9% (11-20%) -> -10% (21-30%) -> -37% (above 30%)**; 79% of lines with more than 30% discount lose money |
| 4 | **Tables and Machines are loss-making**; Tables alone cause 42% of losses from deep-discount lines |
| 5 | Office Supplies earn ~24% margin; Furniture under 10% in every customer segment |
| 6 | **Central region**: lowest margin (12.0%), deepest average discount (13.2%), most loss-making lines (12.2%), slowest Standard delivery (7.0 days, 41% over 7 days) |
| 7 | Festive peak in Oct-Dec (seasonality index above 120) |
| 8 | 172 "Champion" customers generate 63% of sales; 102 valuable customers are "at risk" (about 408 days since last order); repeat rate 81% |

## 8. Recommendations
1. **Cap discounts at 20%**, with approval above that. Re-pricing the 1,284 lines discounted more than 20% to a 20% cap would raise profit by about INR 2.2 M (+30%) *assuming sales volumes do not change* - a best case to test with a pilot.
2. **Reprice or delist Tables and Machines.**
3. **Fix the Central region:** audit discount approvals and review the delivery partner.
4. **Plan for Oct-Dec:** build stock early but set discount limits in advance.
5. **Run a win-back campaign** for the 102 at-risk high-value customers.

## 9. How to reproduce
1. Open `Retail_03_Data_Cleaning_in_Excel.xlsx` and read `Cleaning_Steps`.
2. Create the database: run PART 1 of `Retail_05_sales_analysis_queries.sql` in SQLite (or MySQL/PostgreSQL), import `Retail_04_sales_cleaned_data.csv` into `stg_sales`, run the `INSERT` statements, then run PART 2 and PART 3.
3. In Power BI Desktop, follow `PowerBI_Build_Guide.md` inside the kit zip.

## 10. Limitations
- Synthetic data: findings demonstrate the method, not a real company.
- No returns, overhead or customer-acquisition cost in the data.
- The discount-cap estimate holds volume constant and ignores customer reaction to price.

## 11. Author
*Your name* | [LinkedIn] | [Email]
