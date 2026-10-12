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
