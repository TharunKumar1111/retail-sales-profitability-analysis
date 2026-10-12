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

-- (run after stg_sales is loaded)
INSERT INTO customers SELECT customer_id, MIN(customer_name), MIN(segment), MIN(region), MIN(state), MIN(city) FROM stg_sales GROUP BY customer_id;
INSERT INTO products  SELECT product_id, MIN(product_name), MIN(category), MIN(sub_category) FROM stg_sales GROUP BY product_id;
INSERT INTO orders    SELECT order_id, MIN(order_date), MIN(ship_date), MIN(ship_mode), MIN(customer_id) FROM stg_sales GROUP BY order_id;
INSERT INTO order_lines SELECT order_id, product_id, sales, quantity, discount, profit FROM stg_sales;

CREATE INDEX idx_orders_date ON orders(order_date);
CREATE INDEX idx_orders_cust ON orders(customer_id);
CREATE INDEX idx_lines_prod  ON order_lines(product_id);
-- MySQL: use DATE columns instead of TEXT;  PostgreSQL: use DATE / NUMERIC(12,2).
