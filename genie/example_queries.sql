-- Curated example queries configured in the Genie agent.
-- Each pair teaches the agent a query pattern for a common question shape.

-- Q: What were total net sales by channel?
SELECT channel, SUM(net_sales) AS total_net_sales
FROM workspace.retail.gold_daily_net_sales
GROUP BY channel
ORDER BY total_net_sales DESC;

-- Q: What was the return rate by channel?
SELECT channel, SUM(returns_amt) / SUM(gross_sales) * 100 AS return_rate_pct
FROM workspace.retail.gold_daily_net_sales
GROUP BY channel
ORDER BY return_rate_pct DESC;

-- Q: What are the top 5 products by gross sales?
SELECT product_name, category, brand, gross_sales
FROM workspace.retail.gold_top_products
ORDER BY gross_sales DESC
LIMIT 5;

-- Q: Show daily net sales for the store channel
SELECT sold_date, net_sales
FROM workspace.retail.gold_daily_net_sales
WHERE channel = 'store'
ORDER BY sold_date;
