-- 1. BUSINESS KPIs (Using standard SELECT queries)

-- Total Revenue: total revenue from 'shippped' or 'deliverd orders'
SELECT SUM(o.total_amount) AS total_revenue_for_shipped_or_delivered_orders
FROM orders AS o
JOIN order_statuses AS os
	ON os.status_id = o.status_id
WHERE os.status_name IN ('Shipped', 'Delivered')
-- GROUP BY os.status_name;

-- Top 10 Customers: by their spending showing name and total amount
SELECT CONCAT(c.first_name, ' ', c.last_name) AS customer_name, SUM(o.total_amount) AS total_amount
FROM customers AS c
JOIN orders AS o
	ON o.customer_id = c.customer_id
GROUP BY c.customer_id
ORDER BY total_amount DESC
LIMIT 10;

-- Best-Selling Products: top 5 by quantity sold
SELECT p.product_name, SUM(oi.quantity) AS quantity_sold
FROM products AS p
JOIN order_items AS oi
	ON oi.product_id = p.product_id
GROUP by p.product_id, p.product_name
ORDER BY quantity_sold DESC
LIMIT 5;

-- Monthly Sales Trend: total sales for each month
SELECT 
	TO_CHAR(order_date, 'Month') AS sales_month,
	TO_CHAR(order_date, 'YYYY') AS sales_year,
	SUM(total_amount) AS total_sales
FROM orders
GROUP BY sales_month, sales_year
ORDER BY total_sales DESC;



-- 2. Analytical Queries (Using Window Functions)

-- Sales Rank by Category: for ech category, rank the products by their total sales revenue
WITH products_total_sales AS (
	SELECT p.category_id, p.product_id, p.product_name, SUM(o.total_amount) AS total_sales
	FROM products AS p
	JOIN order_items AS oi ON oi.product_id = p.product_id
	JOIN orders AS o ON o.order_id = oi.order_id
	JOIN order_statuses AS os ON os.status_id = o.status_id
	WHERE os.status_name IN ('Shipped', 'Delivered')
	GROUP BY p.product_id, p.product_name
	ORDER BY total_sales
)

SELECT 
	category_id, 
	product_name,
	total_sales,
	DENSE_RANK() OVER (
		PARTITION BY category_id ORDER BY total_sales DESC
	) AS sales_rank
FROM products_total_sales
ORDER BY category_id;

-- Customer order frequency: list of customers and the date of their previous and current order
SELECT 
	c.customer_id,
	CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
	o.order_date as current_order_date,
	LAG(o.order_date) OVER (
		PARTITION BY c.customer_id
	) AS previous_order_date
FROM customers AS c
JOIN orders AS o ON o.customer_id = c.customer_id
ORDER BY c.customer_id;

-- PROCEDURES, FUNCTIONS, 

-- Performance Optimization (Create Views & Stored Procedures):

-- Create a CustomerSalesSummary View: a view that pre-calculates the total amount spent by each customer. This view will make it easier to query for customer analytics.
DROP VIEW IF EXISTS CustomerSalesSummary;
CREATE VIEW CustomerSalesSummary AS
	SELECT c.first_name, c.last_name, SUM(o.total_amount) AS total_amount_spent
	FROM customers AS c
	JOIN orders AS o ON o.customer_id = c.customer_id
	GROUP BY c.customer_id
	ORDER BY total_amount_spent;


SELECT c.first_name, c.last_name
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.customer_id IS NULL

SELECT first_name, last_name
FROM customers
WHERE customer_id NOT IN (
	SELECT customer_id FROM orders
)

SELECT customer_id FROM customers
EXCEPT
SELECT customer_id FROM orders


-- Create a ProcessNewOrder Stored Procedure: to process new orders
-- args: p_product_id, p_customer_id, p_quantity


CREATE OR REPLACE PROCEDURE process_new_order(
    p_customer_id INT,
    p_product_id  INT,
    p_quantity    INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_stock    INT;
    v_product_price    NUMERIC(12,2);
    v_new_order_id     INT;
    v_restock_level    INT;
    v_rowcount         INT;
BEGIN
    -- Basic validation
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RAISE EXCEPTION 'Quantity must be a positive integer (got %)', p_quantity;
    END IF;

    -- Get price and inventory, lock the row to prevent concurrent modifications
    SELECT p.price, i.stock_quantity, i.restock_level
      INTO STRICT v_product_price, v_current_stock, v_restock_level
      FROM products AS p
      JOIN inventories AS i
        ON i.product_id = p.product_id
     WHERE p.product_id = p_product_id
     FOR UPDATE;

    -- Check available stock before proceeding (optional redundancy, see UPDATE below)
    IF v_current_stock < p_quantity THEN
        RAISE EXCEPTION 'Insufficient stock for product %: available %, requested %',
                        p_product_id, v_current_stock, p_quantity;
    END IF;

    -- Insert new order and get its id
    INSERT INTO orders (total_amount, status_id, customer_id)
    VALUES (v_product_price * p_quantity, 2, p_customer_id)
    RETURNING order_id INTO v_new_order_id;

    -- Insert order item line
    INSERT INTO orderitems (product_id, order_id, quantity, price)
    VALUES (p_product_id, v_new_order_id, p_quantity, v_product_price);

    -- Decrement stock safely; conditional WHERE prevents oversell in concurrent scenarios
    UPDATE inventories
       SET stock_quantity = stock_quantity - p_quantity
     WHERE product_id = p_product_id
       AND stock_quantity >= p_quantity
    RETURNING stock_quantity, restock_level
      INTO v_current_stock, v_restock_level;

    -- Verify the update actually happened
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount = 0 THEN
        RAISE EXCEPTION 'Insufficient stock for product % during update (concurrent change?)', p_product_id;
    END IF;

    -- Restock notice
    IF v_current_stock <= v_restock_level THEN
        RAISE NOTICE 'Product % needs restock (current: %, restock level: %)',
                     p_product_id, v_current_stock, v_restock_level;
    END IF;

EXCEPTION
    WHEN no_data_found THEN
        RAISE EXCEPTION 'Product % not found or no inventory row exists', p_product_id;

    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'Foreign key violation: check customer_id % and product_id %',
                        p_customer_id, p_product_id;

    WHEN OTHERS THEN
        RAISE;
END;
$$;
