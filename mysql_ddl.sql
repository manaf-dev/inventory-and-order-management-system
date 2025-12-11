
DROP DATABASE IF EXISTS amalimart;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS order_statuses;
DROP TABLE IF EXISTS inventories;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS product_categories;
DROP TABLE IF EXISTS shipping_addresses;
DROP TABLE IF EXISTS customers;

-- creating the database
CREATE DATABASE amalimart;
USE amalimart;

-- Customers
CREATE TABLE customers (
  customer_id 	INT AUTO_INCREMENT PRIMARY KEY,
   first_name 	VARCHAR(50) NOT NULL,
    last_name  	VARCHAR(50) NOT NULL,
        email   VARCHAR(255) NOT NULL UNIQUE,
 phone_number 	VARCHAR(32)
);

-- Shipping addresses (customers may have multiple addresses)
CREATE TABLE shipping_addresses (
		address_id 	INT AUTO_INCREMENT PRIMARY KEY,
			region 	VARCHAR(100) NOT NULL,
		  district 	VARCHAR(100),
              city 	VARCHAR(100) NOT NULL,
    street_address 	VARCHAR(100) NOT NULL,
	 house_address 	VARCHAR(100),
	   customer_id 	INT NOT NULL,
					CONSTRAINT fk_customer_address
						FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
						ON DELETE CASCADE
                        ON UPDATE CASCADE
);

-- Product categories
CREATE TABLE product_categories (
	category_id INT AUTO_INCREMENT PRIMARY KEY,
  category_name VARCHAR(100) NOT NULL UNIQUE
);

-- Products
CREATE TABLE products (
	product_id 	INT AUTO_INCREMENT PRIMARY KEY,
  product_name 	VARCHAR(255) NOT NULL,
		 price 	DECIMAL(12, 2) NOT NULL,
   category_id 	INT NOT NULL,
				CONSTRAINT chk_products_price CHECK (price >= 0),
				CONSTRAINT fk_product_category
					FOREIGN KEY (category_id) REFERENCES product_categories(category_id)
					ON DELETE RESTRICT
                    ON UPDATE CASCADE
);

-- Inventories (one row per product)
CREATE TABLE inventories (
	   inventory_id  INT AUTO_INCREMENT PRIMARY KEY,
	 stock_quantity  INT NOT NULL,
					 CONSTRAINT chk_inventories_stock CHECK (stock_quantity >= 0),
	  restock_level  INT NOT NULL DEFAULT 0,
					 CONSTRAINT chk_inventories_restock CHECK (restock_level >= 0),
  last_restock_date  TIMESTAMP NULL,
		 product_id  INT NOT NULL,
					 CONSTRAINT uq_inventories_product UNIQUE (product_id),
					 CONSTRAINT fk_product_inventory
						FOREIGN KEY (product_id) REFERENCES products(product_id)
						ON DELETE CASCADE
                        ON UPDATE CASCADE
);

-- Order statuses
CREATE TABLE order_statuses (
	status_id INT AUTO_INCREMENT PRIMARY KEY,
  status_name VARCHAR(30) NOT NULL UNIQUE
);

-- Orders
CREATE TABLE orders (
		order_id 	INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
	total_amount 	DECIMAL(12, 2) NOT NULL,
					CONSTRAINT chk_orders_total CHECK (total_amount >= 0),
	  order_date 	TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	   status_id 	INT NOT NULL,
					CONSTRAINT fk_order_status
						FOREIGN KEY (status_id) REFERENCES order_statuses(status_id)
						ON DELETE RESTRICT
                        ON UPDATE CASCADE,
	 customer_id 	INT NOT NULL,
					CONSTRAINT fk_order_customer
						FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
						ON DELETE CASCADE
                        ON UPDATE CASCADE
);

-- Order items (bridge table) with composite PK (product_id, order_id)
CREATE TABLE order_items (
  product_id 	INT NOT NULL,
	order_id   	INT NOT NULL,
	quantity   	INT NOT NULL,
				CONSTRAINT chk_order_items_qty CHECK (quantity > 0),
	price      	DECIMAL(12, 2) NOT NULL,
				CONSTRAINT chk_order_items_price CHECK (price >= 0),
				
                CONSTRAINT pk_order_item PRIMARY KEY (product_id, order_id),
				CONSTRAINT fk_order_product
					FOREIGN KEY (product_id) REFERENCES products(product_id)
					ON UPDATE CASCADE
					ON DELETE RESTRICT,
				CONSTRAINT fk_item_order
					FOREIGN KEY (order_id) REFERENCES orders(order_id)
					ON DELETE CASCADE
);


-- -------------------
-- Triggers to keep orders.total_amount in sync with order_items

DELIMITER //

CREATE TRIGGER trg_order_items_ai
AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
  UPDATE orders
    SET total_amount = (
      SELECT COALESCE(SUM(price * quantity), 0)
      FROM order_items
      WHERE order_id = NEW.order_id
    )
  WHERE order_id = NEW.order_id;
END;
//

CREATE TRIGGER trg_order_items_au
AFTER UPDATE ON order_items
FOR EACH ROW
BEGIN
  -- handle both NEW and OLD in case order_id changes (unlikely here)
  UPDATE orders
    SET total_amount = (
      SELECT COALESCE(SUM(price * quantity), 0)
      FROM order_items
      WHERE order_id = NEW.order_id
    )
  WHERE order_id = NEW.order_id;

  IF OLD.order_id <> NEW.order_id THEN
    UPDATE orders
      SET total_amount = (
        SELECT COALESCE(SUM(price * quantity), 0)
        FROM order_items
        WHERE order_id = OLD.order_id
      )
    WHERE order_id = OLD.order_id;
  END IF;
END;
//

CREATE TRIGGER trg_order_items_ad
AFTER DELETE ON order_items
FOR EACH ROW
BEGIN
  UPDATE orders
    SET total_amount = (
      SELECT COALESCE(SUM(price * quantity), 0)
      FROM order_items
      WHERE order_id = OLD.order_id
    )
  WHERE order_id = OLD.order_id;
END;
//

DELIMITER ;

