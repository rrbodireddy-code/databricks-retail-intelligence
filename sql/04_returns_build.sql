-- Databricks notebook source
CREATE OR REPLACE TABLE workspace.retail.silver_all_returns AS
SELECT d.d_date AS returned_date, 'store' AS channel,
  CAST(r.sr_ticket_number AS STRING) AS order_id,
  r.sr_item_sk AS item_sk, r.sr_return_quantity AS return_quantity, r.sr_return_amt AS return_amt
FROM samples.tpcds_sf1000.store_returns r
JOIN samples.tpcds_sf1000.date_dim d ON r.sr_returned_date_sk = d.d_date_sk
WHERE d.d_date BETWEEN DATE '2002-01-01' AND DATE '2002-01-14'
UNION ALL
SELECT d.d_date, 'catalog', CAST(r.cr_order_number AS STRING),
  r.cr_item_sk, r.cr_return_quantity, r.cr_return_amount
FROM samples.tpcds_sf1000.catalog_returns r
JOIN samples.tpcds_sf1000.date_dim d ON r.cr_returned_date_sk = d.d_date_sk
WHERE d.d_date BETWEEN DATE '2002-01-01' AND DATE '2002-01-14'
UNION ALL
SELECT d.d_date, 'web', CAST(r.wr_order_number AS STRING),
  r.wr_item_sk, r.wr_return_quantity, r.wr_return_amt
FROM samples.tpcds_sf1000.web_returns r
JOIN samples.tpcds_sf1000.date_dim d ON r.wr_returned_date_sk = d.d_date_sk
WHERE d.d_date BETWEEN DATE '2002-01-01' AND DATE '2002-01-14';


-- COMMAND ----------

SELECT channel, COUNT(*) AS rows_in_silver, SUM(return_amt) AS returns_total
FROM workspace.retail.silver_all_returns
GROUP BY channel ORDER BY channel;


-- COMMAND ----------

CREATE OR REPLACE TABLE workspace.retail.gold_daily_returns AS
SELECT returned_date, channel,
  COUNT(DISTINCT order_id) AS return_orders,
  SUM(return_quantity) AS units_returned,
  SUM(return_amt) AS returns_amt
FROM workspace.retail.silver_all_returns
GROUP BY returned_date, channel;


-- COMMAND ----------

CREATE OR REPLACE TABLE workspace.retail.gold_daily_net_sales AS
SELECT s.sold_date, s.channel, s.orders, s.items_sold, s.gross_sales,
  COALESCE(r.returns_amt, 0) AS returns_amt,
  s.gross_sales - COALESCE(r.returns_amt, 0) AS net_sales,
  ROUND(100.0 * COALESCE(r.returns_amt, 0) / s.gross_sales, 2) AS return_rate_pct
FROM workspace.retail.gold_daily_channel_sales s
LEFT JOIN workspace.retail.gold_daily_returns r
  ON s.sold_date = r.returned_date AND s.channel = r.channel;


-- COMMAND ----------

SELECT SUM(net_sales) AS total_net FROM workspace.retail.gold_daily_net_sales;
-- expect 54892741614.60
