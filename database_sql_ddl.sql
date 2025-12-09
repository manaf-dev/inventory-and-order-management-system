CREATE TABLE customers (
    customer_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name      VARCHAR(50) NOT NULL,
    last_name       VARCHAR(50) NOT NULL,
    email           VARCHAR(50) NOT NULL UNIQUE,
    phone_number    VARCHAR(15)
);


CREATE TABLE shipping_addresses (
    address_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    region           VARCHAR(20) NOT NULL,
    district         VARCHAR(20),
    city             VARCHAR(20) NOT NULL,
    street_address    VARCHAR(20) NOT NULL,
    house_address     VARCHAR(20),
    customer_id      INT NOT NULL,

    CONSTRAINT fk_customer_address
        FOREIGN KEY (customer_id)
        REFERENCES customers (customer_id)
        ON UPDATE CASCADE 
		ON DELETE CASCADE
);


CREATE TABLE product_categories (
    category_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_name   VARCHAR(50) NOT NULL
);


CREATE TABLE products (
    product_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_name    VARCHAR(50) NOT NULL,
    price           NUMERIC(12,2) NOT NULL CHECK (price > 0),
    category_id     INT NOT NULL,

    CONSTRAINT fk_product_category
        FOREIGN KEY (category_id)
        REFERENCES product_categories (category_id)
        ON UPDATE CASCADE 
		ON DELETE RESTRICT
);


CREATE TABLE inventories (
    inventory_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    stock_quantity      INT NOT NULL DEFAULT 0,
    restock_level       INT NOT NULL DEFAULT 0,
    last_restock_date  TIMESTAMP,
    product_id         INT UNIQUE NOT NULL,

    CONSTRAINT fk_product_inventory
        FOREIGN KEY (product_id)
        REFERENCES products (product_id)
        ON UPDATE CASCADE 
		ON DELETE CASCADE
);


CREATE TABLE order_statuses (
    status_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    status_name     VARCHAR(20) NOT NULL
);


CREATE TABLE orders (
    order_id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    total_amount     NUMERIC(12,2) NOT NULL,
    order_date            TIMESTAMP NOT NULL DEFAULT NOW(),
    status_id        INT NOT NULL,
    customer_id     INT NOT NULL,

    CONSTRAINT fk_order_status
        FOREIGN KEY (status_id)
        REFERENCES order_statuses (status_id)
        ON UPDATE CASCADE 
		ON DELETE RESTRICT,

    CONSTRAINT fk_order_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers (customer_id)
        ON UPDATE CASCADE 
		ON DELETE CASCADE
);


CREATE TABLE order_items (
    product_id      INT NOT NULL,
    order_id        INT NOT NULL,
    quantity        INT NOT NULL CHECK (quantity > 0),
    price           NUMERIC(12,2) NOT NULL CHECK (price > 0),

    CONSTRAINT pk_order_item PRIMARY KEY (product_id, order_id),

    CONSTRAINT fk_order_product
        FOREIGN KEY (product_id)
        REFERENCES products (product_id)
        ON UPDATE CASCADE 
		ON DELETE RESTRICT,

    CONSTRAINT fk_item_order
        FOREIGN KEY (order_id)
        REFERENCES orders (order_id)
        ON UPDATE CASCADE 
		ON DELETE CASCADE
);