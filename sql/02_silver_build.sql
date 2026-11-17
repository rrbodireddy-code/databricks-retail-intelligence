-- Databricks notebook source
CREATE SCHEMA IF NOT EXISTS workspace.retail;


-- COMMAND ----------

CREATE OR REPLACE TABLE workspace.retail.silver_store_sales AS
SELECT
  d.d_date AS sold_date,
  'store' AS channel,
  CAST(s.ss_ticket_number AS STRING) AS order_id,
  s.ss_item_sk AS item_sk,
  s.ss_customer_sk AS customer_sk,
  s.ss_store_sk AS location_sk,
  s.ss_quantity AS quantity,
  s.ss_ext_sales_price AS ext_sales_price,
  s.ss_net_profit AS net_profit
FROM samples.tpcds_sf1000.store_sales s
JOIN samples.tpcds_sf1000.date_dim d ON s.ss_sold_date_sk = d.d_date_sk
WHERE d.d_date BETWEEN DATE '2002-01-01' AND DATE '2002-01-14';


-- COMMAND ----------

SELECT COUNT(*) AS rows_built, MIN(sold_date) AS first_date, MAX(sold_date) AS last_date,
       SUM(ext_sales_price) AS gross_sales
FROM workspace.retail.silver_store_sales;


-- COMMAND ----------

SELECT COUNT(*) AS src_rows, SUM(s.ss_ext_sales_price) AS src_gross
FROM samples.tpcds_sf1000.store_sales s
JOIN samples.tpcds_sf1000.date_dim d ON s.ss_sold_date_sk = d.d_date_sk
WHERE d.d_date BETWEEN DATE '2002-01-01' AND DATE '2002-01-14';


-- COMMAND ----------

SELECT table_name, column_name, data_type
FROM system.information_schema.columns
WHERE table_schema = 'tpcds_sf1000'
  AND table_name IN ('web_sales', 'catalog_sales')
  AND (column_name LIKE '%sold_date_sk'
    OR column_name LIKE '%order_number'
    OR column_name LIKE '%item_sk'
    OR column_name LIKE '%customer_sk'
    OR column_name LIKE '%warehouse_sk'
    OR column_name LIKE '%web_site_sk'
    OR column_name LIKE '%quantity'
    OR column_name LIKE '%ext_sales_price'
    OR column_name LIKE '%net_profit')
ORDER BY table_name, column_name;


-- COMMAND ----------

CREATE OR REPLACE TABLE workspace.retail.silver_all_sales AS
SELECT * FROM workspace.retail.silver_store_sales

UNION ALL

SELECT
  d.d_date AS sold_date,
  'catalog' AS channel,
  CAST(c.cs_order_number AS STRING) AS order_id,
  c.cs_item_sk AS item_sk,
  c.cs_bill_customer_sk AS customer_sk,
  c.cs_warehouse_sk AS location_sk,
  c.cs_quantity AS quantity,
  c.cs_ext_sales_price AS ext_sales_price,
  c.cs_net_profit AS net_profit
FROM samples.tpcds_sf1000.catalog_sales c
JOIN samples.tpcds_sf1000.date_dim d ON c.cs_sold_date_sk = d.d_date_sk
WHERE d.d_date BETWEEN DATE '2002-01-01' AND DATE '2002-01-14'

UNION ALL

SELECT
  d.d_date AS sold_date,
  'web' AS channel,
  CAST(w.ws_order_number AS STRING) AS order_id,
  w.ws_item_sk AS item_sk,
  w.ws_bill_customer_sk AS customer_sk,
  w.ws_warehouse_sk AS location_sk,
  w.ws_quantity AS quantity,
  w.ws_ext_sales_price AS ext_sales_price,
  w.ws_net_profit AS net_profit
FROM samples.tpcds_sf1000.web_sales w
JOIN samples.tpcds_sf1000.date_dim d ON w.ws_sold_date_sk = d.d_date_sk
WHERE d.d_date BETWEEN DATE '2002-01-01' AND DATE '2002-01-14';


-- COMMAND ----------

SELECT channel, COUNT(*) AS rows_in_silver, SUM(ext_sales_price) AS gross
FROM workspace.retail.silver_all_sales
GROUP BY channel
ORDER BY channel;


-- COMMAND ----------

SELECT 'catalog' AS channel, COUNT(*) AS src_rows, SUM(c.cs_ext_sales_price) AS src_gross
FROM samples.tpcds_sf1000.catalog_sales c
JOIN samples.tpcds_sf1000.date_dim d ON c.cs_sold_date_sk = d.d_date_sk
WHERE d.d_date BETWEEN DATE '2002-01-01' AND DATE '2002-01-14'
UNION ALL
SELECT 'web', COUNT(*), SUM(w.ws_ext_sales_price)
FROM samples.tpcds_sf1000.web_sales w
JOIN samples.tpcds_sf1000.date_dim d ON w.ws_sold_date_sk = d.d_date_sk
WHERE d.d_date BETWEEN DATE '2002-01-01' AND DATE '2002-01-14';
