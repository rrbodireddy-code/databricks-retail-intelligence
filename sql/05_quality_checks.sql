-- Databricks notebook source
SELECT 'silver_has_all_channels' AS check_name,
  CASE WHEN COUNT(DISTINCT channel) = 3 THEN 'PASS' ELSE 'FAIL' END AS status
FROM workspace.retail.silver_all_sales
UNION ALL
SELECT 'gold_daily_ties_to_silver',
  CASE WHEN ABS((SELECT SUM(gross_sales) FROM workspace.retail.gold_daily_channel_sales)
              - (SELECT SUM(ext_sales_price) FROM workspace.retail.silver_all_sales)) < 0.01
       THEN 'PASS' ELSE 'FAIL' END
UNION ALL
SELECT 'net_equals_gross_minus_returns',
  CASE WHEN ABS((SELECT SUM(net_sales) FROM workspace.retail.gold_daily_net_sales)
              - ((SELECT SUM(gross_sales) FROM workspace.retail.gold_daily_net_sales)
               - (SELECT SUM(returns_amt) FROM workspace.retail.gold_daily_net_sales))) < 0.01
       THEN 'PASS' ELSE 'FAIL' END
UNION ALL
SELECT 'no_null_dates_in_silver',
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM workspace.retail.silver_all_sales
WHERE sold_date IS NULL;


-- COMMAND ----------

-- Pipeline gate: this cell ERRORS if any critical check fails
SELECT assert_true(
  ABS((SELECT SUM(gross_sales) FROM workspace.retail.gold_daily_channel_sales)
    - (SELECT SUM(ext_sales_price) FROM workspace.retail.silver_all_sales)) < 0.01,
  'GATE FAILED: gold_daily does not tie to silver'
) AS gate_1_gold_ties_silver;

SELECT assert_true(
  (SELECT COUNT(DISTINCT channel) FROM workspace.retail.silver_all_sales) = 3,
  'GATE FAILED: silver is missing a channel'
) AS gate_2_all_channels;
