

USE ecommerce_sales;
CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    signup_date DATE,
    state VARCHAR(10),
    acquisition_channel VARCHAR(50)
);
CREATE TABLE products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(150),
    category VARCHAR(50),
    list_price DECIMAL(10,2),
    unit_cost DECIMAL(10,2)
);
CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    customer_id INT,
    order_date DATETIME,
    discount_code VARCHAR(50),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);
CREATE TABLE order_items (
    order_id INT,
    product_id INT,
    quantity INT,
    unit_price DECIMAL(10,2),
    discount_amount DECIMAL(10,2),
    PRIMARY KEY (order_id, product_id),
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);
show tables;
DESCRIBE customers;
SELECT COUNT(*) FROM ecommerce_sales.orders;
DESCRIBE orders;
USE ecommerce_sales;

ALTER TABLE orders
ADD COLUMN status VARCHAR(30),
ADD COLUMN payment_method VARCHAR(50),
ADD COLUMN shipping_fee DECIMAL(10,2);


#sales performance analysis
#total revenue
SELECT SUM((quantity*unit_price)-discount_amount) from order_items AS total_revenue;
#TOTAL ORDERS
SELECT COUNT(DISTINCT order_id) AS total_orders FROM order_items; 
#Total Quantity Sold
SELECT SUM(quantity) AS Total_quantity_sold FROM order_items;
#AVERAGE ORDER VALUE
SELECT SUM((quantity*unit_price)-discount_amount)/COUNT(DISTINCT order_id) AS Average_order_value FROM order_items;
#TOTAL REVENUE PER YEAR
SELECT YEAR(o.order_date) AS sales_year,SUM((oi.quantity*oi.unit_price)-oi.discount_amount) AS Total_revenue FROM orders o JOIN order_items oi ON o.order_id=oi.order_id group by sales_year;
#Total Revenue Per month
SELECT YEAR(o.order_date) AS sales_year,MONTH(o.order_date) AS sales_month,SUM((oi.quantity*oi.unit_price)-oi.discount_amount) AS Total_revenue FROM orders o JOIN order_items oi ON o.order_id=oi.order_id group by sales_year,sales_month order by sales_year,sales_month ;
#Highest revenue month
SELECT YEAR(o.order_date) AS sales_year,MONTH(o.order_date) AS sales_month,SUM((oi.quantity*oi.unit_price)-oi.discount_amount) AS Total_revenue FROM orders o JOIN order_items oi ON o.order_id=oi.order_id group by sales_year,sales_month order by Total_revenue DESC LIMIT 1;
#products with highest sales
SELECT p.product_id,p.product_name,SUM(oi.quantity) AS total_quantity FROM products p join order_items oi on p.product_id=oi.product_id group by p.product_id,p.product_name order by total_quantity DESC;
#products with lowest sales
SELECT p.product_id,p.product_name,SUM(oi.quantity) AS total_quantity FROM products p join order_items oi on p.product_id=oi.product_id group by p.product_id,p.product_name order by total_quantity;
# products that give high profit
SELECT p.product_id,p.product_name,SUM((oi.quantity*oi.unit_price)-oi.discount_amount-p.unit_cost) AS profit FROM products p join order_items oi on p.product_id=oi.product_id group by p.product_id,p.product_name order by profit DESC;
#product category with high revenue
SELECT p.category,SUM((oi.quantity*oi.unit_price)-oi.discount_amount) AS revenue FROM products p join order_items oi on p.product_id=oi.product_id group by p.category order by revenue DESC;
#Highest category sales
SELECT p.category,SUM(oi.quantity) AS total_sold FROM products p join order_items oi on p.product_id=oi.product_id group by p.category order by total_sold DESC;
#category revenue %
SELECT p.category,SUM((oi.quantity*oi.unit_price)-oi.discount_amount) AS category_revenue,ROUND((SUM((oi.quantity*oi.unit_price)-oi.discount_amount)*100)/(SELECT SUM((quantity*unit_price)-discount_amount) FROM order_items),2)  AS percentage from products p join order_items oi on p.product_id=oi.product_id group by p.category order by percentage DESC;
#Top 10 customers spending
SELECT customers.customer_id,SUM((oi.quantity*oi.unit_price)-oi.discount_amount) AS total_spending FROM customers  join orders on customers.customer_id=orders.customer_id join order_items oi on orders.order_id= oi.order_id group by customers.customer_id order by total_spending DESC LIMIT 10;
#TOP 10 CUSTOMERS WITH HIGHEST ORDERS
SELECT c.customer_id,SUM(DISTINCT o.order_id) Total_orders FROM customers c join orders o on c.customer_id=o.customer_id group by c.customer_id order by Total_orders DESC LIMIT 10;
#AVERAGE REVENUE PER CUSTOMER
SELECT SUM((oi.quantity*oi.unit_price)-oi.discount_amount)/COUNT(DISTINCT c.customer_id) AS avg_revenue_per_customer from customers c join orders o on c.customer_id=o.customer_id join order_items oi on o.order_id=oi.order_id;
#Repeat_purchasers
SELECT COUNT(*) AS repeat_purchasers FROM (SELECT customer_id,COUNT(DISTINCT order_id) AS total_orders from orders GROUP BY customer_id HAVING COUNT(DISTINCT order_id)>1 )AS customers_orders; 
# one time purchasers
SELECT COUNT(*) AS one_time_purchasers FROM(SELECT customer_id,COUNT(DISTINCT order_id) AS total_orders FROM orders GROUP by customer_id HAVING COUNT(DISTINCT order_id)=1) AS customers_orders;
#states with high revenue
SELECT c.state,SUM((oi.quantity*oi.unit_price)-oi.discount_amount) as High_revenue FROM customers c join orders o on c.customer_id=o.customer_id join order_items oi on o.order_id=oi.order_id group by c.state order by High_revenue DESC;
#states with high customers
SELECT state,COUNT(DISTINCT customer_id) AS customers_of_state FROM customers group by state order by customers_of_state DESC;
#MOST USED DISCOUNT_CODE
SELECT discount_code,COUNT(discount_code) AS usage_count from orders where discount_code<>'No discount' group by discount_code order by usage_count DESC;
#Total discount amount
SELECT SUM(discount_amount) AS total_discount_amount FROM order_items;
#Most used payment method
SELECT payment_method,COUNT(DISTINCT order_id) AS payment_method_used FROM orders group by payment_method order by payment_method_used desc;
#TOTAL PROFIT
SELECT SUM((oi.quantity*oi.unit_price)-oi.discount_amount-(oi.quantity*p.unit_cost)) AS total_profit FROM products p join order_items oi on p.product_id=oi.product_id;
#order status distribution
SELECT status,COUNT(DISTINCT order_id) as total_orders from orders group by status order by total_orders DESC;
#AQUISITION CHANNEL WITH HIGH CUSTOMERS
 SELECT acquisition_channel,COUNT(DISTINCT customer_id) as total_customers from customers group by acquisition_channel order by total_customers DESC;
 
