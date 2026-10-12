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
