-- =====================================================================
-- RETAIL SALES PERFORMANCE ANALYSIS - SQL QUERIES  (SQLite syntax; MySQL/PostgreSQL differences are noted in comments)
-- Data: Retail_04_sales_cleaned_data.csv  (8,939 order lines produced by the Excel cleaning workbook)
--
-- HOW TO LOAD (SQLite):   run PART 1 (creates stg_sales), then
--     .mode csv
--     .import --skip 1 Retail_04_sales_cleaned_data.csv stg_sales
--   then run the INSERT statements of PART 1 (normalise into customers / products / orders / order_lines),
--   then PART 2 (data-quality checks) and PART 3 (analysis queries).
--   (DB Browser for SQLite: File > Import > Table from CSV file ... into stg_sales.  MySQL: Table Data Import Wizard.)
-- Note: the CSV header names have spaces; stg_sales below uses snake_case - import without header ("--skip 1").
-- =====================================================================

-- ################ PART 1 : SCHEMA & LOAD ################
-- =====================================================================
-- PROJECT 1 : Retail Sales Performance Analysis  |  01_schema_and_load.sql
-- Dialect  : SQLite (runs as-is). MySQL / PostgreSQL notes are in comments.
-- Design   : Cleaned flat file is normalised into 4 tables (star-like)
--            customers / products / orders (header) / order_lines (fact)
-- =====================================================================
DROP TABLE IF EXISTS order_lines; DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;    DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS stg_sales;

-- Staging table: exact copy of retail_sales_clean.csv (loaded by build_sqlite_db.py)
CREATE TABLE stg_sales (
  order_id TEXT, order_date TEXT, ship_date TEXT, ship_mode TEXT, customer_id TEXT, customer_name TEXT,
  segment TEXT, region TEXT, state TEXT, city TEXT, product_id TEXT, category TEXT, sub_category TEXT,
  product_name TEXT, sales REAL, quantity INTEGER, discount REAL, profit REAL);

CREATE TABLE customers (
  customer_id TEXT PRIMARY KEY, customer_name TEXT NOT NULL, segment TEXT, region TEXT, state TEXT, city TEXT);
CREATE TABLE products (
  product_id TEXT PRIMARY KEY, product_name TEXT NOT NULL, category TEXT, sub_category TEXT);
CREATE TABLE orders (
  order_id TEXT PRIMARY KEY, order_date TEXT NOT NULL, ship_date TEXT NOT NULL, ship_mode TEXT,
  customer_id TEXT NOT NULL REFERENCES customers(customer_id));
CREATE TABLE order_lines (
  order_id TEXT NOT NULL REFERENCES orders(order_id), product_id TEXT NOT NULL REFERENCES products(product_id),
  sales REAL NOT NULL, quantity INTEGER NOT NULL CHECK (quantity > 0),
  discount REAL NOT NULL CHECK (discount BETWEEN 0 AND 1), profit REAL NOT NULL,
  PRIMARY KEY (order_id, product_id));

-- >>> LOAD THE CSV INTO stg_sales HERE (see HOW TO LOAD above), then run everything below <<<
INSERT INTO customers SELECT customer_id, MIN(customer_name), MIN(segment), MIN(region), MIN(state), MIN(city) FROM stg_sales GROUP BY customer_id;
INSERT INTO products  SELECT product_id, MIN(product_name), MIN(category), MIN(sub_category) FROM stg_sales GROUP BY product_id;
INSERT INTO orders    SELECT order_id, MIN(order_date), MIN(ship_date), MIN(ship_mode), MIN(customer_id) FROM stg_sales GROUP BY order_id;
INSERT INTO order_lines SELECT order_id, product_id, sales, quantity, discount, profit FROM stg_sales;

CREATE INDEX idx_orders_date ON orders(order_date);
CREATE INDEX idx_orders_cust ON orders(customer_id);
CREATE INDEX idx_lines_prod  ON order_lines(product_id);
-- MySQL: use DATE columns instead of TEXT;  PostgreSQL: use DATE / NUMERIC(12,2).

-- ################ PART 2 : DATA QUALITY CHECKS ################
-- =====================================================================
-- 02_data_quality_checks.sql  - run BEFORE analysis. Every check should return 0 problem rows.
-- =====================================================================
-- @DQ1 Row counts per table
SELECT 'customers' AS tbl, COUNT(*) AS n FROM customers UNION ALL SELECT 'products',COUNT(*) FROM products
UNION ALL SELECT 'orders',COUNT(*) FROM orders UNION ALL SELECT 'order_lines',COUNT(*) FROM order_lines;

-- @DQ2 Staging vs fact reconciliation (totals must match exactly)
SELECT ROUND((SELECT SUM(sales) FROM stg_sales),2) AS staging_sales, ROUND((SELECT SUM(sales) FROM order_lines),2) AS fact_sales,
       ROUND((SELECT SUM(profit) FROM stg_sales),2) AS staging_profit, ROUND((SELECT SUM(profit) FROM order_lines),2) AS fact_profit;

-- @DQ3 NULL / invalid value checks
SELECT SUM(CASE WHEN sales IS NULL THEN 1 ELSE 0 END)  AS null_sales,
       SUM(CASE WHEN sales <= 0 THEN 1 ELSE 0 END)      AS non_positive_sales,
       SUM(CASE WHEN discount < 0 OR discount > 1 THEN 1 ELSE 0 END) AS bad_discount,
       SUM(CASE WHEN quantity <= 0 THEN 1 ELSE 0 END)   AS bad_quantity
FROM order_lines;

-- @DQ4 Ship date earlier than order date
SELECT COUNT(*) AS bad_ship_dates FROM orders WHERE ship_date < order_date;

-- @DQ5 Orphan check: lines without a matching order / product
SELECT COUNT(*) AS orphan_lines FROM order_lines l
LEFT JOIN orders o ON o.order_id = l.order_id LEFT JOIN products p ON p.product_id = l.product_id
WHERE o.order_id IS NULL OR p.product_id IS NULL;

-- @DQ6 Duplicate business keys in staging (should be 0)
SELECT COUNT(*) AS duplicate_keys FROM (SELECT order_id, product_id FROM stg_sales GROUP BY 1,2 HAVING COUNT(*) > 1);

-- @DQ7 Date coverage
SELECT MIN(order_date) AS first_order, MAX(order_date) AS last_order, COUNT(DISTINCT substr(order_date,1,7)) AS months_covered FROM orders;

-- ################ PART 3 : BUSINESS ANALYSIS ################
-- =====================================================================
-- PROJECT 1 : 03_business_analysis.sql
-- 15 queries that answer the business questions in the Business Problem Document.
-- Concepts: joins, CTEs, window functions (LAG, SUM OVER, RANK, ROW_NUMBER, NTILE), CASE, HAVING, subqueries
-- Dialect : SQLite. Dialect notes are given where MySQL/PostgreSQL differ.
-- =====================================================================

-- @Q1 Executive KPI summary
SELECT ROUND(SUM(l.sales),0)                         AS total_sales,
       ROUND(SUM(l.profit),0)                        AS total_profit,
       ROUND(100.0*SUM(l.profit)/SUM(l.sales),2)     AS profit_margin_pct,
       COUNT(DISTINCT l.order_id)                    AS orders,
       COUNT(DISTINCT o.customer_id)                 AS customers,
       SUM(l.quantity)                               AS units_sold,
       ROUND(SUM(l.sales)/COUNT(DISTINCT l.order_id),0) AS avg_order_value
FROM order_lines l JOIN orders o ON o.order_id = l.order_id;

-- @Q2 Year-over-year growth (LAG window function)
WITH yearly AS (
  SELECT substr(o.order_date,1,4) AS yr, SUM(l.sales) AS sales, SUM(l.profit) AS profit
  FROM order_lines l JOIN orders o ON o.order_id=l.order_id GROUP BY 1)
SELECT yr, ROUND(sales,0) AS sales, ROUND(profit,0) AS profit,
       ROUND(100.0*profit/sales,2) AS margin_pct,
       ROUND(100.0*(sales - LAG(sales) OVER (ORDER BY yr)) / LAG(sales) OVER (ORDER BY yr),2) AS sales_yoy_pct,
       ROUND(100.0*(profit - LAG(profit) OVER (ORDER BY yr)) / LAG(profit) OVER (ORDER BY yr),2) AS profit_yoy_pct
FROM yearly ORDER BY yr;

-- @Q3 Monthly sales, MoM growth and 3-month moving average (window frame)
WITH monthly AS (
  SELECT substr(o.order_date,1,7) AS ym, SUM(l.sales) AS sales
  FROM order_lines l JOIN orders o ON o.order_id=l.order_id GROUP BY 1)
SELECT ym, ROUND(sales,0) AS sales,
       ROUND(100.0*(sales-LAG(sales) OVER (ORDER BY ym))/LAG(sales) OVER (ORDER BY ym),1) AS mom_pct,
       ROUND(AVG(sales) OVER (ORDER BY ym ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),0) AS moving_avg_3m
FROM monthly ORDER BY ym LIMIT 12;

-- @Q4 Category -> sub-category profitability with ranking and loss flag
SELECT p.category, p.sub_category, ROUND(SUM(l.sales),0) AS sales, ROUND(SUM(l.profit),0) AS profit,
       ROUND(100.0*SUM(l.profit)/SUM(l.sales),2) AS margin_pct,
       ROUND(AVG(l.discount)*100,1) AS avg_discount_pct,
       RANK() OVER (ORDER BY SUM(l.profit) DESC) AS profit_rank,
       CASE WHEN SUM(l.profit) < 0 THEN 'LOSS-MAKING' ELSE 'profitable' END AS status
FROM order_lines l JOIN products p ON p.product_id=l.product_id
GROUP BY p.category, p.sub_category ORDER BY profit DESC;

-- @Q5 Region performance (sales, margin, discount behaviour)
SELECT c.region, ROUND(SUM(l.sales),0) AS sales, ROUND(SUM(l.profit),0) AS profit,
       ROUND(100.0*SUM(l.profit)/SUM(l.sales),2) AS margin_pct,
       ROUND(100.0*AVG(l.discount),1) AS avg_discount_pct,
       ROUND(100.0*SUM(CASE WHEN l.profit<0 THEN 1 ELSE 0 END)/COUNT(*),1) AS pct_lines_loss_making
FROM order_lines l JOIN orders o ON o.order_id=l.order_id JOIN customers c ON c.customer_id=o.customer_id
GROUP BY c.region ORDER BY margin_pct DESC;

-- @Q6 Discount band analysis - the core "why are we losing money" query
SELECT CASE WHEN discount=0 THEN '0. No discount' WHEN discount<=0.10 THEN '1. 1-10%'
            WHEN discount<=0.20 THEN '2. 11-20%'  WHEN discount<=0.30 THEN '3. 21-30%' ELSE '4. Above 30%' END AS discount_band,
       COUNT(*) AS order_lines, ROUND(SUM(sales),0) AS sales, ROUND(SUM(profit),0) AS profit,
       ROUND(100.0*SUM(profit)/SUM(sales),2) AS margin_pct,
       ROUND(100.0*SUM(CASE WHEN profit<0 THEN 1 ELSE 0 END)/COUNT(*),1) AS pct_lines_loss
FROM order_lines GROUP BY 1 ORDER BY 1;

-- @Q7 Ten worst products by profit (candidates for re-pricing or delisting)
SELECT p.product_id, p.product_name, p.sub_category, SUM(l.quantity) AS units,
       ROUND(SUM(l.sales),0) AS sales, ROUND(SUM(l.profit),0) AS profit,
       ROUND(100.0*AVG(l.discount),1) AS avg_discount_pct
FROM order_lines l JOIN products p ON p.product_id=l.product_id
GROUP BY p.product_id, p.product_name, p.sub_category ORDER BY profit ASC LIMIT 10;

-- @Q8 Pareto: how concentrated is profit? Top 10 customers + cumulative share
WITH cust AS (
  SELECT o.customer_id, SUM(l.profit) AS profit
  FROM order_lines l JOIN orders o ON o.order_id=l.order_id GROUP BY 1),
ranked AS (SELECT customer_id, profit, SUM(profit) OVER () AS total FROM cust)
SELECT customer_id, ROUND(profit,0) AS profit,
       ROUND(100.0*SUM(profit) OVER (ORDER BY profit DESC)/total,1) AS cumulative_profit_pct
FROM ranked ORDER BY profit DESC LIMIT 10;

-- @Q9 RFM customer segmentation (NTILE) - who to retain / win back
WITH base AS (
  SELECT o.customer_id, MAX(o.order_date) AS last_order, COUNT(DISTINCT o.order_id) AS frequency, SUM(l.sales) AS monetary
  FROM orders o JOIN order_lines l ON l.order_id=o.order_id GROUP BY 1),
scored AS (
  SELECT customer_id, frequency, monetary,
         CAST(julianday((SELECT MAX(order_date) FROM orders)) - julianday(last_order) AS INT) AS recency_days,
         NTILE(5) OVER (ORDER BY last_order)  AS r,   -- 5 = most recent
         NTILE(5) OVER (ORDER BY frequency)   AS f,
         NTILE(5) OVER (ORDER BY monetary)    AS m
  FROM base)
SELECT CASE WHEN r>=4 AND f>=4 AND m>=4 THEN 'Champions'
            WHEN r>=3 AND f>=3 THEN 'Loyal'
            WHEN r<=2 AND (f>=4 OR m>=4) THEN 'At risk - win back'
            WHEN r<=2 THEN 'Lost / low value' ELSE 'Potential' END AS rfm_segment,
       COUNT(*) AS customers, ROUND(AVG(recency_days),0) AS avg_recency_days,
       ROUND(AVG(frequency),1) AS avg_orders, ROUND(SUM(monetary),0) AS total_sales
FROM scored GROUP BY 1 ORDER BY total_sales DESC;

-- @Q10 Delivery performance by region and ship mode
SELECT c.region, o.ship_mode, COUNT(*) AS orders,
       ROUND(AVG(julianday(o.ship_date)-julianday(o.order_date)),2) AS avg_delivery_days,
       ROUND(100.0*SUM(CASE WHEN julianday(o.ship_date)-julianday(o.order_date) > 7 THEN 1 ELSE 0 END)/COUNT(*),1) AS pct_over_7_days
FROM orders o JOIN customers c ON c.customer_id=o.customer_id
GROUP BY c.region, o.ship_mode HAVING o.ship_mode='Standard Class' ORDER BY avg_delivery_days DESC;
-- MySQL: DATEDIFF(ship_date, order_date)   PostgreSQL: (ship_date - order_date)

-- @Q11 Top 3 sub-categories by profit in each region (ROW_NUMBER inside a partition)
WITH x AS (
  SELECT c.region, p.sub_category, SUM(l.profit) AS profit,
         ROW_NUMBER() OVER (PARTITION BY c.region ORDER BY SUM(l.profit) DESC) AS rn
  FROM order_lines l JOIN orders o ON o.order_id=l.order_id JOIN customers c ON c.customer_id=o.customer_id
  JOIN products p ON p.product_id=l.product_id GROUP BY c.region, p.sub_category)
SELECT region, rn AS rank, sub_category, ROUND(profit,0) AS profit FROM x WHERE rn<=3 ORDER BY region, rn;

-- @Q12 Seasonality index: each month vs the average month (100 = average)
WITH m AS (
  SELECT CAST(substr(o.order_date,6,2) AS INT) AS month_no, SUM(l.sales) AS sales
  FROM order_lines l JOIN orders o ON o.order_id=l.order_id GROUP BY 1)
SELECT month_no, ROUND(sales,0) AS sales, ROUND(100.0*sales/AVG(sales) OVER (),0) AS seasonality_index FROM m ORDER BY month_no;

-- @Q13 Segment x category margin matrix
SELECT c.segment, p.category, ROUND(SUM(l.sales),0) AS sales, ROUND(100.0*SUM(l.profit)/SUM(l.sales),2) AS margin_pct
FROM order_lines l JOIN orders o ON o.order_id=l.order_id JOIN customers c ON c.customer_id=o.customer_id
JOIN products p ON p.product_id=l.product_id GROUP BY c.segment, p.category ORDER BY c.segment, margin_pct DESC;

-- @Q14 Repeat-purchase rate
WITH n AS (SELECT customer_id, COUNT(*) AS orders FROM orders GROUP BY 1)
SELECT COUNT(*) AS customers, SUM(CASE WHEN orders>1 THEN 1 ELSE 0 END) AS repeat_customers,
       ROUND(100.0*SUM(CASE WHEN orders>1 THEN 1 ELSE 0 END)/COUNT(*),1) AS repeat_rate_pct, ROUND(AVG(orders),2) AS avg_orders_per_customer FROM n;

-- @Q15 Discount leakage: profit destroyed by deep-discount (>20%) lines, by sub-category
SELECT p.sub_category, COUNT(*) AS deep_discount_lines, ROUND(SUM(l.profit),0) AS profit_on_those_lines,
       ROUND(100.0*SUM(l.profit)/(SELECT SUM(profit) FROM order_lines WHERE profit<0),1) AS share_of_total_losses_pct
FROM order_lines l JOIN products p ON p.product_id=l.product_id
WHERE l.discount > 0.20 AND l.profit < 0 GROUP BY p.sub_category ORDER BY profit_on_those_lines ASC LIMIT 6;
