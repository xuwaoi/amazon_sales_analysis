create database amazon_sales;
use amazon_sales ;
CREATE TABLE orders (
    `index` BIGINT,
    order_id VARCHAR(100),
    `date` DATE,
    status VARCHAR(50),
    fulfilment VARCHAR(50),
    sales_channel VARCHAR(50),
    ship_service_level VARCHAR(50),
    style VARCHAR(100),
    sku VARCHAR(100),
    category VARCHAR(50),
    size VARCHAR(20),
    asin VARCHAR(20),
    courier_status VARCHAR(50),
    qty boolean,
    currency VARCHAR(10),
    amount DECIMAL(10,2),
    ship_city VARCHAR(100),
    ship_state VARCHAR(100),
    ship_postal_code VARCHAR(20),
    ship_country VARCHAR(50),
    promotion_ids TEXT,
    b2b BOOLEAN,
    fulfilled_by VARCHAR(50)
);
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 9.5/Uploads/Amazon_sales.csv'
INTO TABLE orders
FIELDS TERMINATED BY ';'
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
  `index`,
  order_id,
  @date,
  status,
  fulfilment,
  sales_channel,
  ship_service_level,
  style,
  sku,
  category,
  size,
  asin,
  courier_status,
  @qty,
  currency,
  @amount,
  ship_city,
  ship_state,
  ship_postal_code,
  ship_country,
  promotion_ids,
  @b2b,
  fulfilled_by
)
SET
  `date` = CASE
             WHEN @date LIKE '__-__-__' THEN STR_TO_DATE(@date, '%m-%d-%y')
             WHEN @date LIKE '__.__.____' THEN STR_TO_DATE(@date, '%d.%m.%Y')
           END,
  qty = IF(@qty='ИСТИНА',1,0),
  b2b = IF(@b2b='ИСТИНА',1,0),
  amount = NULLIF(TRIM(@amount), '');
  select * from orders;
  

