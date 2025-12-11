
-- 1) BUSINESS KPIs

-- Total Revenue: total revenue from 'Shipped' or 'Delivered' orders
SELECT SUM(o.total_amount) AS total_revenue
FROM orders AS o
JOIN order_statuses AS os ON os.status_id = o.status_id
WHERE os.status_name IN ('Shipped', 'Delivered');

-- Top 10 Customers: by their spending showing name and total amount
SELECT
  c.customer_id,
  CONCAT(c.first_name, ' ', c.last_name) AS `Customer name`,
  SUM(o.total_amount) AS total_amount
FROM customers AS c
JOIN orders AS o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_amount DESC
LIMIT 10;

-- Best-Selling Products: top 5 by quantity sold (only shipped/delivered)
SELECT p.product_id, p.product_name, SUM(oi.quantity) AS quantity_sold
FROM products AS p
JOIN order_items AS oi ON oi.product_id = p.product_id
JOIN orders AS o ON o.order_id = oi.order_id
JOIN order_statuses AS os ON os.status_id = o.status_id
WHERE os.status_name IN ('Shipped', 'Delivered')
GROUP BY p.product_id, p.product_name
ORDER BY quantity_sold DESC
LIMIT 5;

-- Monthly Sales Trend: total sales for each month
SELECT
  DATE_FORMAT(order_date, '%M') AS sales_month,
  DATE_FORMAT(order_date, '%Y') AS sales_year,
  SUM(total_amount) AS total_sales
FROM orders
GROUP BY sales_month, sales_year
ORDER BY total_sales DESC;


-- -------------------
-- 2) Analytical Queries (Window Functions)

-- Sales Rank by Category: per category, rank products by revenue
WITH products_total_sales AS (
  SELECT
    p.category_id,
    p.product_id,
    p.product_name,
    SUM(oi.quantity * oi.price) AS total_sales
  FROM products AS p
  JOIN order_items AS oi ON oi.product_id = p.product_id
  JOIN orders AS o ON o.order_id = oi.order_id
  JOIN order_statuses AS os ON os.status_id = o.status_id
  WHERE os.status_name IN ('Shipped', 'Delivered')
  GROUP BY p.category_id, p.product_id, p.product_name
)
SELECT
  category_id,
  product_id,
  product_name,
  total_sales,
  DENSE_RANK() OVER (
    PARTITION BY category_id ORDER BY total_sales DESC
  ) AS sales_rank
FROM products_total_sales
ORDER BY category_id, sales_rank;

-- Customer order frequency: previous/current order dates
SELECT
  c.customer_id,
  CONCAT(c.first_name, ' ', c.last_name) AS `Cusomer name`,
  o.order_date AS current_order_date,
  LAG(o.order_date) OVER (
    PARTITION BY c.customer_id ORDER BY o.order_date
  ) AS previous_order_date
FROM customers AS c
JOIN orders AS o ON o.customer_id = c.customer_id
ORDER BY c.customer_id;


-- -------------------
-- Performance Optimization (View & Procedure)


-- View: total amount spent by each customer
DROP VIEW IF EXISTS CustomerSalesSummary;
CREATE VIEW CustomerSalesSummary AS
  SELECT c.customer_id, c.first_name, c.last_name, SUM(o.total_amount) AS total_amount_spent
  FROM customers AS c
  JOIN orders AS o ON o.customer_id = c.customer_id
  GROUP BY c.customer_id, c.first_name, c.last_name;

-- Query the view
SELECT * FROM CustomerSalesSummary ORDER BY total_amount_spent DESC;


-- Stored Procedure: ProcessNewOrder(p_customer_id, p_product_id, p_quantity)
DELIMITER //

CREATE PROCEDURE ProcessNewOrder(
  IN p_customer_id INT,
  IN p_product_id  INT,
  IN p_quantity    INT
)
BEGIN
  DECLARE v_current_stock INT;
  DECLARE v_product_price DECIMAL(12,2);
  DECLARE v_new_order_id INT;
  DECLARE v_restock_level INT;
  DECLARE v_rowcount INT;
  DECLARE v_status_id INT;

  -- Basic validation
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
	SET @message_text = CONCAT('Quantity must be a positive integer (got ', COALESCE(p_quantity, 'NULL'), ')');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @message_text;
  END IF;

  START TRANSACTION;

  -- Get price and inventory (lock the row)
  SET v_product_price = NULL;
  SELECT p.price, i.stock_quantity, i.restock_level
    INTO v_product_price, v_current_stock, v_restock_level
  FROM products AS p
  JOIN inventories AS i ON i.product_id = p.product_id
  WHERE p.product_id = p_product_id
  FOR UPDATE;

  IF v_product_price IS NULL THEN
    ROLLBACK;
    SET @message_text = CONCAT('Product ', p_product_id, ' not found or no inventory row exists');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @message_text;
  END IF;

  -- Check available stock
  IF v_current_stock < p_quantity THEN
    ROLLBACK;
    SET @message_text = CONCAT('Insufficient stock for product ', p_product_id, ': available ', v_current_stock, ', requested ', p_quantity);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @message_text;
      
  END IF;

  -- Get 'Processing' status id
  SET v_status_id = NULL;
  SELECT status_id INTO v_status_id
  FROM order_statuses
  WHERE status_name = 'Processing';

  IF v_status_id IS NULL THEN
    ROLLBACK;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Status ''Processing'' not found in order_statuses';
  END IF;

  -- Insert new order (order_date defaults to CURRENT_TIMESTAMP)
  INSERT INTO orders (total_amount, status_id, customer_id)
  VALUES (v_product_price * p_quantity, v_status_id, p_customer_id);
  SET v_new_order_id = LAST_INSERT_ID();

  -- Insert order item
  INSERT INTO order_items (product_id, order_id, quantity, price)
  VALUES (p_product_id, v_new_order_id, p_quantity, v_product_price);

  -- Decrement stock; WHERE guard prevents oversell under concurrency
  UPDATE inventories
     SET stock_quantity = stock_quantity - p_quantity
   WHERE product_id = p_product_id
     AND stock_quantity >= p_quantity;

  SET v_rowcount = ROW_COUNT();
  IF v_rowcount = 0 THEN
    ROLLBACK;
    SET @message_text = CONCAT('Insufficient stock for product ', p_product_id, ' during update (concurrent change?)');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @message_text;
  END IF;

  -- Refresh current stock for optional notice
  SELECT stock_quantity, restock_level
    INTO v_current_stock, v_restock_level
  FROM inventories
  WHERE product_id = p_product_id;

  COMMIT;

  -- return a message row when restock is needed
  IF v_current_stock <= v_restock_level THEN
    SELECT CONCAT('Product ', p_product_id, ' needs restock (current: ', v_current_stock,
                  ', restock level: ', v_restock_level, ')') AS message;
  END IF;
END//
DELIMITER ;


-- -------------------
-- Testing the stored procedure

-- 1) Check inventory before
SELECT i.product_id, p.product_name, i.stock_quantity, i.restock_level
FROM inventories i
JOIN products p ON p.product_id = i.product_id
WHERE i.product_id = 3;

-- 2) Place the order
CALL ProcessNewOrder(3, 3, 2);

-- 3) Verify: last created order (with date/time)
SELECT o.order_id, o.customer_id, o.total_amount, o.status_id, o.order_date
FROM orders o
ORDER BY o.order_id DESC
LIMIT 1;

-- 4) Check inventory after (stock should drop by 2)
SELECT i.product_id, p.product_name, i.stock_quantity, i.restock_level
FROM inventories i
JOIN products p ON p.product_id = i.product_id
WHERE i.product_id = 3;

-- Handling exceptions (these will SIGNAL errors)
CALL ProcessNewOrder(2, 10, 0);      -- quantity <= 0
CALL ProcessNewOrder(2, 999, 1);     -- nonexistent product/inventory
CALL ProcessNewOrder(4, 5, 9999);    -- insufficient stock
