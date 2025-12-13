
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
  RANK() OVER (
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
DROP PROCEDURE IF EXISTS ProcessNewOrder;

DELIMITER //

CREATE PROCEDURE ProcessNewOrder(
  IN p_customer_id INT,
  IN p_items_json JSON
)
BEGIN
    DECLARE v_status_id INT;
    DECLARE v_new_order_id INT;
    DECLARE v_total_amount DECIMAL(14,2) DEFAULT 0;
    DECLARE v_item_count INT;
    DECLARE v_index INT DEFAULT 0;

    DECLARE v_product_id INT;
    DECLARE v_quantity INT;
    DECLARE v_price DECIMAL(12,2);
    DECLARE v_stock INT;
    DECLARE v_restock_level INT;

    -- Temporary table for restock notices
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_restock_notices (
        product_id INT,
        current_stock INT,
        restock_level INT
    );

    TRUNCATE TABLE tmp_restock_notices;

    -- Validate JSON
    IF p_items_json IS NULL OR JSON_LENGTH(p_items_json) = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Order must contain at least one product';
    END IF;

  START TRANSACTION;

  -- Get Processing status
  SELECT status_id
  INTO v_status_id
  FROM order_statuses
  WHERE status_name = 'Processing';

  -- Create order record (total amount will be calculated by trg_order_items_ai trigger )
  INSERT INTO orders (total_amount, status_id, customer_id)
  VALUES (0, v_status_id, p_customer_id);

  SET v_new_order_id = LAST_INSERT_ID();

  SET v_item_count = JSON_LENGTH(p_items_json);

  WHILE v_index < v_item_count DO

        SET v_product_id = JSON_EXTRACT(p_items_json, CONCAT('$[', v_index, '].product_id'));
        SET v_quantity   = JSON_EXTRACT(p_items_json, CONCAT('$[', v_index, '].quantity'));

        IF v_quantity IS NULL OR v_quantity <= 0 THEN
            ROLLBACK;
            SET @messate_text = CONCAT('Invalid quantity for product ', v_product_id);
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = @messate_text;
        END IF;

        -- Lock inventory
        SELECT p.price, i.stock_quantity, i.restock_level
        INTO v_price, v_stock, v_restock_level
        FROM products p
        JOIN inventories i ON i.product_id = p.product_id
        WHERE p.product_id = v_product_id
        FOR UPDATE;

        IF v_price IS NULL THEN
            ROLLBACK;
            SET @messate_text = CONCAT('Product ', v_product_id, ' not found');
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = @messate_text;
        END IF;

        IF v_stock < v_quantity THEN
            ROLLBACK;
            SET @messate_text = CONCAT(
                'Insufficient stock for product ', v_product_id,
                ' (available ', v_stock, ', requested ', v_quantity, ')'
            );
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = @messate_text;
        END IF;

        -- Insert item
        INSERT INTO order_items (product_id, order_id, quantity, price)
        VALUES (v_product_id, v_new_order_id, v_quantity, v_price);

        -- Update inventory
        UPDATE inventories
        SET stock_quantity = stock_quantity - v_quantity
        WHERE product_id = v_product_id;

        -- Re-read stock after update
        SELECT stock_quantity
        INTO v_stock
        FROM inventories
        WHERE product_id = v_product_id;

        -- Collect restock notice
        IF v_stock <= v_restock_level THEN
            INSERT INTO tmp_restock_notices
            VALUES (v_product_id, v_stock, v_restock_level);
        END IF;

        SET v_total_amount = v_total_amount + (v_price * v_quantity);
        SET v_index = v_index + 1;
    END WHILE;

  COMMIT;

  -- Return restock notices (if any)
  IF EXISTS (SELECT * FROM tmp_restock_notices) THEN
    SELECT CONCAT('Product ', p.product_id, ' needs restock (current: ', v_stock,
                  ', restock level: ', v_restock_level, ')') AS restock_notice;
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

-- 2) Place the order with multiple products
CALL ProcessNewOrder(
  3,
  '[
     {"product_id": 1, "quantity": 2},
     {"product_id": 4, "quantity": 1},
     {"product_id": 7, "quantity": 3}
   ]'
);

-- 3) Verify: last created order (with order_id and date/time)
SELECT *
FROM orders
ORDER BY order_id DESC;

-- 4) Check inventory after (stock should drop by 2)
SELECT i.product_id, p.product_name, i.stock_quantity, i.restock_level
FROM inventories i
JOIN products p ON p.product_id = i.product_id
WHERE i.product_id = 3;

-- Handling exceptions (these will SIGNAL errors)
-- quantity <= 0
CALL ProcessNewOrder(2, '[{"product_id": 10, "quantity": 0}]');

-- nonexistent product/inventory
CALL ProcessNewOrder(2, '[{"product_id": 999, "quantity": 1}]');

-- insufficient stock
CALL ProcessNewOrder(2, '[{"product_id": 5, "quantity": 9999}]');
