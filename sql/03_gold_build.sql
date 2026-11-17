-- Databricks notebook source
CREATE OR REPLACE TABLE workspace.retail.gold_daily_channel_sales AS
SELECT
  sold_date,
  channel,
  COUNT(DISTINCT order_id) AS orders,
  SUM(quantity) AS items_sold,
  SUM(ext_sales_price) AS gross_sales,
  SUM(net_profit) AS total_profit
FROM workspace.retail.silver_all_sales
GROUP BY sold_date, channel;


-- COMMAND ----------

SELECT COUNT(*) AS gold_rows FROM workspace.retail.gold_daily_channel_sales;
-- expect 42

SELECT SUM(gross_sales) AS gold_total_gross FROM workspace.retail.gold_daily_channel_sales;
-- expect 60023366486.73 — Gold must tie back to Silver exactly


-- COMMAND ----------

SELECT column_name, data_type
FROM system.information_schema.columns
WHERE table_schema = 'tpcds_sf1000' AND table_name = 'item'
  AND (column_name LIKE '%item_sk' OR column_name LIKE '%product_name'
    OR column_name LIKE '%category' OR column_name LIKE '%brand')
ORDER BY column_name;


-- COMMAND ----------

CREATE OR REPLACE TABLE workspace.retail.gold_top_products AS
SELECT
  s.item_sk,
  i.i_product_name AS product_name,
  i.i_category AS category,
  i.i_brand AS brand,
  SUM(s.quantity) AS units_sold,
  SUM(s.ext_sales_price) AS gross_sales,
  SUM(s.net_profit) AS total_profit
FROM workspace.retail.silver_all_sales s
JOIN samples.tpcds_sf1000.item i ON s.item_sk = i.i_item_sk
GROUP BY s.item_sk, i.i_product_name, i.i_category, i.i_brand;


-- COMMAND ----------

-- 1. Top products must tie back to Silver, same as Gold daily did
SELECT SUM(gross_sales) AS top_products_total FROM workspace.retail.gold_top_products;
-- expect 60023366486.73

-- 2. Gold daily row count
SELECT COUNT(*) AS gold_daily_rows FROM workspace.retail.gold_daily_channel_sales;
-- expect 42

-- 3. Look at your actual top 10 products
SELECT product_name, category, brand, units_sold, gross_sales
FROM workspace.retail.gold_top_products
ORDER BY gross_sales DESC
LIMIT 10;


-- COMMAND ----------

SELECT
  (SELECT SUM(gross_sales) FROM workspace.retail.gold_top_products) AS top_products_total,
  (SELECT COUNT(*) FROM workspace.retail.gold_daily_channel_sales) AS gold_daily_rows;
-- expect 60023366486.73 and 42
