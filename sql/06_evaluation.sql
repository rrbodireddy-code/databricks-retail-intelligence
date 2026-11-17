-- Ground-truth queries for the Genie benchmark.
-- Run by hand BEFORE evaluating the agent, so expected answers come from
-- verified SQL, not from the agent. (Databricks notebook: 06_evaluation)

-- total orders and items sold
SELECT SUM(orders) AS total_orders, SUM(items_sold) AS total_items
FROM workspace.retail.gold_daily_channel_sales;
-- result: 2,598,807 orders; 1,402,592,870 items

-- best day by net sales
SELECT sold_date, SUM(net_sales) AS daily_net
FROM workspace.retail.gold_daily_net_sales
GROUP BY sold_date
ORDER BY daily_net DESC
LIMIT 3;
-- result: 2002-01-02 = 10,595,422,126.45; 2002-01-01 = 8,421,053,683.98

-- web net sales on Jan 6
SELECT net_sales
FROM workspace.retail.gold_daily_net_sales
WHERE channel = 'web' AND sold_date = '2002-01-06';
-- result: 534,821,677.60

-- units returned and return orders by channel
SELECT channel, SUM(units_returned) AS units_returned, SUM(return_orders) AS return_orders
FROM workspace.retail.gold_daily_returns
GROUP BY channel;
-- result: store 77,574,820; catalog 31,089,323; web 12,198,373

-- top 5 products
SELECT product_name, gross_sales
FROM workspace.retail.gold_top_products
ORDER BY gross_sales DESC
LIMIT 5;
-- result: 614,998.15; 612,099.09; 611,790.10; 604,566.28; 599,087.30

-- average daily net sales, store channel
SELECT AVG(net_sales) AS avg_daily_net_store
FROM workspace.retail.gold_daily_net_sales
WHERE channel = 'store';
-- result: 2,100,515,050.06
