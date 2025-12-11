
-- Order Statuses (ensure these are loaded before orders)
INSERT INTO order_statuses (status_name) VALUES
('Pending'),
('Processing'),
('Shipped'),
('Delivered'),
('Cancelled');


-- Customers (20)
INSERT INTO customers (first_name, last_name, email, phone_number) VALUES
('Kwame','Mensah','kwame.mensah.1@gmail.com','0241234567'),
('Ama','Owusu','ama.owusu.2@yahoo.com','0552345678'),
('Kofi','Boateng','kofi.boateng.3@outlook.com','233209876543'),
('Akosua','Appiah','akosua.appiah.4@gmail.com','0209988776'),
('Yaw','Osei','yaw.osei.5@gmx.com','0261112223'),
('Afua','Agyeman','afua.agyeman.6@yahoo.com','0503334445'),
('Kojo','Tetteh','kojo.tetteh.7@outlook.com','0275556667'),
('Yaa','Quaye','yaa.quaye.8@gmail.com','0547778889'),
('Kwaku','Adjei','kwaku.adjei.9@gmail.com','0591112233'),
('Adwoa','Acquah','adwoa.acquah.10@yahoo.com','0244445566'),
('Nana','Darko','nana.darko.11@outlook.com','233552345678'),
('Esi','Donkor','esi.donkor.12@gmail.com','0269990001'),
('Manaf','Mohammed','manaf.mohammed.13@gmail.com','0502223344'),
('Joseph','Sarpong','joseph.sarpong.14@outlook.com','0248889990'),
('Gifty','Amoah','gifty.amoah.15@yahoo.com','0546655443'),
('Ibrahim','Seidu','ibrahim.seidu.16@gmail.com','233559998877'),
('Deborah','Aryee','deborah.aryee.17@gmx.com','0267776655'),
('Samuel','Addo','samuel.addo.18@outlook.com','0203332211'),
('Mercy','Nkrumah','mercy.nkrumah.19@gmail.com','0279090909'),
('Emmanuel','Baah','emmanuel.baah.20@yahoo.com','0550102030');


-- Shipping Addresses (customer_id refers to the inserted customers above: 1..20)
INSERT INTO shipping_addresses (region, district, city, street_address, house_address, customer_id) VALUES
('Ashanti','Asokwa','Kumasi','Kejetia Rd','House No. A12',1),
('Ashanti','Bantama','Kumasi','Santasi Rd','Plot B21',1),
('Greater Accra','Ayawaso','Accra','Oxford St','Flat C05',2),
('Greater Accra','Ablekuma','Accra','Spintex Rd','Block D14',2),
('Greater Accra','Madina','Accra','Atomic Rd','House No. A22',3),
('Greater Accra','Adenta','Accra','Ring Rd','Plot B11',4),
('Western','Sekondi-Takoradi','Takoradi','Harper Rd','Flat C10',5),
('Central','Cape Coast','Cape Coast','Stadium Rd','Block D03',6),
('Eastern','New Juaben','Koforidua','Abeka Rd','House No. A31',7),
('Volta','Ho Municipal','Ho','Oxford St','Plot B18',8),
('Bono','Sunyani Municipal','Sunyani','Amakom St','Flat C08',9),
('Bono East','Techiman Municipal','Techiman','Tanoso Rd','Block D20',10),
('Northern','Tamale Metro','Tamale','Ring Rd','House No. A45',11),
('Upper East','Bolgatanga','Bolgatanga','Kejetia Rd','Plot B05',12),
('Upper West','Wa Municipal','Wa','Lapaz Rd','Flat C02',13),
('Ahafo','Wiawso','Sefwi Wiawso','Stadium Rd','Block D07',14),
('Savannah','Krachi East','Dambai','Spintex Rd','House No. A09',15),
('Central','Awutu Senya East','Kasoa','Oxford St','Plot B30',16),
('Ashanti','Obuasi Municipal','Obuasi','Harper Rd','Flat C11',17),
('Greater Accra','Osu','Accra','Oxford St','House No. A07',18),
('Greater Accra','Madina','Accra','Atomic Rd','Plot B25',19),
('Ashanti','Tafo','Kumasi','Kejetia Rd','Flat C04',20);


-- Product Categories (IDs will be 1..8 in this order)
INSERT INTO product_categories (category_name) VALUES
('Groceries'),
('Food & Beverages'),
('Electronics'),
('Home & Kitchen'),
('Traditional Wear'),
('Footwear'),
('Stationery'),
('Personal Care');


-- Products (category_id matches the order above)
INSERT INTO products (product_name, price, category_id) VALUES
('Banku Flour 1kg',18.50,1),
('Kenkey (Ga) Pack',25.00,1),
('Shito Sauce 300ml',35.00,2),
('Royal Aroma Rice 5kg',95.00,1),
('Infinix Hot 12',1450.00,3),
('Tecno Spark 10',1299.00,3),
('Coalpot (Charcoal Stove)',120.00,4),
('Electric Kettle 1.7L',155.00,4),
('Kente Cloth - Adwinasa',450.00,5),
('Kente Slippers',60.00,6),
('School Exercise Book',3.50,7),
('Nivea Body Lotion',32.00,8);


-- Inventories (product_id will be 1..12)
INSERT INTO inventories (stock_quantity, restock_level, last_restock_date, product_id) VALUES
(80,20,'2025-10-15 10:00:00',1),
(60,15,'2025-10-20 11:00:00',2),
(50,10,'2025-11-01 09:30:00',3),
(100,25,'2025-11-10 08:45:00',4),
(25,8,'2025-11-18 12:00:00',5),
(30,10,'2025-11-18 12:10:00',6),
(40,10,'2025-10-28 16:00:00',7),
(35,10,'2025-11-05 14:25:00',8),
(12,4,'2025-11-20 13:00:00',9),
(55,12,'2025-10-30 15:40:00',10),
(200,50,'2025-11-02 10:15:00',11),
(90,20,'2025-11-12 09:05:00',12);


-- Orders (10) with fixed timestamps

INSERT INTO orders (total_amount, order_date, status_id, customer_id) VALUES
(153.50,'2025-11-01 10:15:00',4,1),
(85.00,'2025-11-02 12:45:00',3,2),
(450.00,'2025-11-03 09:05:00',4,3),
(1299.00,'2025-11-04 16:20:00',3,4),
(155.00,'2025-11-05 08:30:00',2,5),
(42.00,'2025-11-06 11:10:00',4,6),
(18.50,'2025-11-07 14:00:00',1,7),
(120.00,'2025-11-08 09:55:00',3,8),
(1450.00,'2025-11-09 19:40:00',4,9),
(95.00,'2025-11-10 07:25:00',4,10);



-- Order Items
-- Order 1 (total 153.50): Rice 95 + Shito 35 + Exercise Book (3.50 x 7) = 24.5
INSERT INTO order_items (product_id, order_id, quantity, price) VALUES
(4,1,1,95.00),
(3,1,1,35.00),
(11,1,7,3.50);

-- Order 2 (total 85.00): Kente Slippers 60 + Shito 25 (we’ll use Kenkey 25 instead for variety)
INSERT INTO order_items (product_id, order_id, quantity, price) VALUES
(10,2,1,60.00),
(2,2,1,25.00);

-- Order 3 (total 450.00): Kente Cloth 1 x 450
INSERT INTO order_items (product_id, order_id, quantity, price) VALUES
(9,3,1,450.00);

-- Order 4 (total 1299.00): Tecno Spark 10 1 x 1299
INSERT INTO order_items (product_id, order_id, quantity, price) VALUES
(6,4,1,1299.00);

-- Order 5 (total 155.00): Electric Kettle 1 x 155
INSERT INTO order_items (product_id, order_id, quantity, price) VALUES
(8,5,1,155.00);

-- order_items 6 (total 42.00): Banku Flour 1 x 42
INSERT INTO order_items (product_id, order_id, quantity, price) VALUES
(3,6,1,35.00),
(11,6,2,3.50);

-- Order 7 (total 18.50): Banku Flour 1 x 18.50
INSERT INTO order_items (product_id, order_id, quantity, price) VALUES
(1,7,1,18.50);

-- Order 8 (total 120.00): Coalpot 1 x 120
INSERT INTO order_items (product_id, order_id, quantity, price) VALUES
(7,8,1,120.00);

-- Order 9 (total 1450.00): Infinix Hot 12 1 x 1450
INSERT INTO order_items (product_id, order_id, quantity, price) VALUES
(5,9,1,1450.00);

-- Order 10 (total 95.00): Rice 5kg 1 x 95
INSERT INTO order_items (product_id, order_id, quantity, price) VALUES
(4,10,1,95.00);
