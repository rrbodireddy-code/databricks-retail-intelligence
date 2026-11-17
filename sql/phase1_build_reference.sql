-- ONE TASK Phase 1 (v2, updated 16 Nov 2026 after discovery): Retail Channel Sales Intelligence — Data Foundation
-- DEV SLICE DECISION: source facts total ~5.04B rows (store 2,879,966,589 / catalog 1,439,976,202 / web 719,959,864).
-- Production pattern: develop on a date slice, ship the same code. Slice = 2002-01-01 to 2002-01-14 (~38M rows est).
-- To run full data later, remove the WHERE date filters. Nothing else changes.
-- Run in notebook 01_discovery_profiling (new cells) or a new notebook 02_phase1_build, one cell per step.

-- STEP 0 (open finding from discovery): how many store rows do NOT match date_dim?
-- Year counts joined to date_dim summed to 2,750,380,056 vs 2,879,966,589 total = 129,586,533 unmatched (4.5%). Verify why:
SELECT
  COUNT(*) AS total_rows,
  SUM(CASE WHEN s.ss_sold_date_sk IS NULL THEN 1 ELSE 0 END) AS null_date_key,
  COUNT(d.d_date_sk) AS matched_rows,
  COUNT(*) - COUNT(d.d_date_sk) AS unmatched_rows
FROM samples.tpcds_sf1000.store_sales s
LEFT JOIN samples.tpcds_sf1000.date_dim d ON s.ss_sold_date_sk = d.d_date_sk;

-- STEP 1.1 See before you code (still required for web + catalog)
DESCRIBE samples.tpcds_sf1000.web_sales;
DESCRIBE samples.tpcds_sf1000.catalog_sales;
DESCRIBE samples.tpcds_sf1000.date_dim;

-- STEP 1.2 Project home
CREATE SCHEMA IF NOT EXISTS workspace.retail;

-- STEP 1.3 SILVER (dev slice): unified sales, all 3 channels, 2002-01-01..2002-01-14
-- Inner JOIN to date_dim is correct HERE: the slice is defined by date, and rows with no matching
-- date cannot belong to any date slice (we quantified them in Step 0 instead of hiding them).
CREATE OR REPLACE TABLE workspace.retail.silver_all_sales AS
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
WHERE d.d_date BETWEEN DATE '2002-01-01' AND DATE '2002-01-14'
UNION ALL
SELECT
  d.d_date, 'catalog', CAST(c.cs_order_number AS STRING),
  c.cs_item_sk, c.cs_customer_sk, c.cs_warehouse_sk,
  c.cs_quantity, c.cs_ext_sales_price, c.cs_net_profit
FROM samples.tpcds_sf1000.catalog_sales c
JOIN samples.tpcds_sf1000.date_dim d ON c.cs_sold_date_sk = d.d_date_sk
WHERE d.d_date BETWEEN DATE '2002-01-01' AND DATE '2002-01-14'
UNION ALL
SELECT
  d.d_date, 'web', CAST(w.ws_order_number AS STRING),
  w.ws_item_sk, w.ws_customer_sk, w.ws_web_site_sk,
  w.ws_quantity, w.ws_ext_sales_price, w.ws_net_profit
FROM samples.tpcds_sf1000.web_sales w
JOIN samples.tpcds_sf1000.date_dim d ON w.ws_sold_date_sk = d.d_date_sk
WHERE d.d_date BETWEEN DATE '2002-01-01' AND DATE '2002-01-14';

-- STEP 1.4 GOLD: daily sales by channel (from the Silver slice)
CREATE OR REPLACE TABLE workspace.retail.gold_daily_channel_sales AS
SELECT
  sold_date, channel,
  COUNT(*) AS line_items,
  COUNT(DISTINCT order_id) AS orders,
  SUM(quantity) AS total_quantity,
  SUM(ext_sales_price) AS gross_sales,
  SUM(net_profit) AS total_profit
FROM workspace.retail.silver_all_sales
GROUP BY sold_date, channel
ORDER BY sold_date, channel;

-- STEP 1.5 GOLD: top products (from the Silver slice)
CREATE OR REPLACE TABLE workspace.retail.gold_top_products AS
SELECT
  s.item_sk,
  i.i_product_name AS product_name,
  i.i_category AS category,
  SUM(s.quantity) AS total_quantity,
  SUM(s.ext_sales_price) AS gross_sales
FROM workspace.retail.silver_all_sales s
LEFT JOIN samples.tpcds_sf1000.item i ON s.item_sk = i.i_item_sk
GROUP BY s.item_sk, i.i_product_name, i.i_category
ORDER BY gross_sales DESC;

-- STEP 1.6 CHECKS — paste these outputs back for review
-- Check A: Silver by channel (rows + money)
SELECT channel, COUNT(*) AS silver_rows, SUM(ext_sales_price) AS silver_gross
FROM workspace.retail.silver_all_sales GROUP BY channel;

-- Check A2: Source filtered to the SAME slice (must match Check A exactly, per channel)
SELECT 'store' AS channel, COUNT(*) AS src_rows, SUM(s.ss_ext_sales_price) AS src_gross
FROM samples.tpcds_sf1000.store_sales s
JOIN samples.tpcds_sf1000.date_dim d ON s.ss_sold_date_sk = d.d_date_sk
WHERE d.d_date BETWEEN DATE '2002-01-01' AND DATE '2002-01-14'
UNION ALL
SELECT 'catalog', COUNT(*), SUM(c.cs_ext_sales_price)
FROM samples.tpcds_sf1000.catalog_sales c
JOIN samples.tpcds_sf1000.date_dim d ON c.cs_sold_date_sk = d.d_date_sk
WHERE d.d_date BETWEEN DATE '2002-01-01' AND DATE '2002-01-14'
UNION ALL
SELECT 'web', COUNT(*), SUM(w.ws_ext_sales_price)
FROM samples.tpcds_sf1000.web_sales w
JOIN samples.tpcds_sf1000.date_dim d ON w.ws_sold_date_sk = d.d_date_sk
WHERE d.d_date BETWEEN DATE '2002-01-01' AND DATE '2002-01-14';

-- Check B: Gold rolls up to Silver (must match exactly)
SELECT SUM(gross_sales) AS gold_total FROM workspace.retail.gold_daily_channel_sales;
SELECT SUM(ext_sales_price) AS silver_total FROM workspace.retail.silver_all_sales;

-- Check C: no null dates inside a date-defined slice (must be 0)
SELECT COUNT(*) AS rows_with_null_date FROM workspace.retail.silver_all_sales WHERE sold_date IS NULL;

-- Look at your Gold
SELECT * FROM workspace.retail.gold_daily_channel_sales ORDER BY sold_date, channel;
SELECT * FROM workspace.retail.gold_top_products LIMIT 10;
