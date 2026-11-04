-- Q1: Cedvelin profili
SELECT COUNT(*) AS row_count,
       COUNT(DISTINCT customer_id) AS distinct_customers,
       COUNT(DISTINCT product_id)  AS distinct_products,
       MIN(order_date) AS min_order_date,
       MAX(order_date) AS max_order_date
FROM orders;

-- Q2: Her sutun uzre NULL sayi
SELECT
  SUM(CASE WHEN row_id        IS NULL THEN 1 ELSE 0 END) AS row_id_nulls,
  SUM(CASE WHEN order_id      IS NULL THEN 1 ELSE 0 END) AS order_id_nulls,
  SUM(CASE WHEN order_date    IS NULL THEN 1 ELSE 0 END) AS order_date_nulls,
  SUM(CASE WHEN ship_date     IS NULL THEN 1 ELSE 0 END) AS ship_date_nulls,
  SUM(CASE WHEN ship_mode     IS NULL THEN 1 ELSE 0 END) AS ship_mode_nulls,
  SUM(CASE WHEN customer_id   IS NULL THEN 1 ELSE 0 END) AS customer_id_nulls,
  SUM(CASE WHEN customer_name IS NULL THEN 1 ELSE 0 END) AS customer_name_nulls,
  SUM(CASE WHEN segment       IS NULL THEN 1 ELSE 0 END) AS segment_nulls,
  SUM(CASE WHEN country       IS NULL THEN 1 ELSE 0 END) AS country_nulls,
  SUM(CASE WHEN city          IS NULL THEN 1 ELSE 0 END) AS city_nulls,
  SUM(CASE WHEN state         IS NULL THEN 1 ELSE 0 END) AS state_nulls,
  SUM(CASE WHEN postal_code   IS NULL THEN 1 ELSE 0 END) AS postal_code_nulls,
  SUM(CASE WHEN region        IS NULL THEN 1 ELSE 0 END) AS region_nulls,
  SUM(CASE WHEN product_id    IS NULL THEN 1 ELSE 0 END) AS product_id_nulls,
  SUM(CASE WHEN category      IS NULL THEN 1 ELSE 0 END) AS category_nulls,
  SUM(CASE WHEN sub_category  IS NULL THEN 1 ELSE 0 END) AS sub_category_nulls,
  SUM(CASE WHEN product_name  IS NULL THEN 1 ELSE 0 END) AS product_name_nulls,
  SUM(CASE WHEN sales         IS NULL THEN 1 ELSE 0 END) AS sales_nulls,
  SUM(CASE WHEN quantity      IS NULL THEN 1 ELSE 0 END) AS quantity_nulls,
  SUM(CASE WHEN discount      IS NULL THEN 1 ELSE 0 END) AS discount_nulls,
  SUM(CASE WHEN profit        IS NULL THEN 1 ELSE 0 END) AS profit_nulls
FROM orders;

-- Q3: Dublikat order line (order_id + product_id)
SELECT order_id, product_id, COUNT(*) AS cnt
FROM orders
GROUP BY order_id, product_id
HAVING COUNT(*) > 1;

-- Q4: Ship Mode uzre orta catdirilma muddeti (gun)
SELECT ship_mode,
       ROUND(AVG(julianday(ship_date) - julianday(order_date)), 2) AS avg_days_to_ship
FROM orders
GROUP BY ship_mode
ORDER BY avg_days_to_ship;

-- Q5: Region, Category, Sub-Category uzre satis, profit, marja
SELECT region, category, sub_category,
       ROUND(SUM(sales), 2)  AS total_sales,
       ROUND(SUM(profit), 2) AS total_profit,
       ROUND(SUM(profit) / SUM(sales), 4) AS profit_margin
FROM orders
GROUP BY region, category, sub_category
ORDER BY total_profit ASC;

-- Q6: En yaxsi 5 ve en pis 5 sub-category (profit uzre)
WITH sub AS (
  SELECT sub_category, SUM(profit) AS total_profit
  FROM orders
  GROUP BY sub_category
),
ranked AS (
  SELECT sub_category,
         total_profit,
         RANK() OVER (ORDER BY total_profit DESC) AS rank_top,
         RANK() OVER (ORDER BY total_profit ASC)  AS rank_bottom
  FROM sub
)
SELECT sub_category,
       ROUND(total_profit, 2) AS total_profit,
       CASE WHEN rank_top <= 5 THEN 'Top 5' ELSE 'Bottom 5' END AS group_label
FROM ranked
WHERE rank_top <= 5 OR rank_bottom <= 5
ORDER BY total_profit DESC;

-- Q6b: Butun sub-category-ler uzre profit (qrafik 1 ucun)
SELECT sub_category, ROUND(SUM(profit), 2) AS total_profit
FROM orders
GROUP BY sub_category
ORDER BY total_profit;

-- Q7: Endirim bantlari
SELECT CASE
         WHEN discount = 0     THEN '0%'
         WHEN discount <= 0.20 THEN '1-20%'
         WHEN discount <= 0.40 THEN '21-40%'
         ELSE '41%+'
       END AS discount_band,
       COUNT(DISTINCT order_id) AS order_count,
       ROUND(AVG(profit), 2)    AS avg_profit,
       ROUND(SUM(profit), 2)    AS total_profit
FROM orders
GROUP BY discount_band
ORDER BY MIN(discount);

-- Q8: Illik satis ve YoY deyisme
WITH yearly AS (
  SELECT strftime('%Y', order_date) AS year,
         SUM(sales) AS total_sales
  FROM orders
  GROUP BY strftime('%Y', order_date)
)
SELECT year,
       ROUND(total_sales, 2) AS total_sales,
       ROUND(total_sales - LAG(total_sales) OVER (ORDER BY year), 2) AS yoy_abs,
       ROUND(100.0 * (total_sales - LAG(total_sales) OVER (ORDER BY year))
             / LAG(total_sales) OVER (ORDER BY year), 2) AS yoy_pct
FROM yearly
ORDER BY year;

-- Q9: Menfi profitli sub-category-ler ve gelirdeki payi
WITH sub AS (
  SELECT sub_category,
         SUM(sales)  AS total_sales,
         SUM(profit) AS total_profit
  FROM orders
  GROUP BY sub_category
)
SELECT sub_category,
       ROUND(total_profit, 2) AS total_profit,
       ROUND(total_sales, 2)  AS total_sales,
       ROUND(100.0 * total_sales / (SELECT SUM(sales) FROM orders), 2) AS revenue_share_pct
FROM sub
WHERE total_profit < 0
ORDER BY total_profit;

-- Q10: Omurluk profite gore top 10 musteri
SELECT customer_id,
       customer_name,
       ROUND(SUM(profit), 2) AS lifetime_profit,
       COUNT(DISTINCT order_id) AS order_count,
       ROUND(SUM(sales) / COUNT(DISTINCT order_id), 2) AS avg_order_value
FROM orders
GROUP BY customer_id, customer_name
ORDER BY SUM(profit) DESC
LIMIT 10;

-- Q11a: Kohne view-u sil (yeniden islemek ucun)
DROP VIEW IF EXISTS v_region_category;

-- Q11b: Region/Category/Sub-Category yigma view-u
CREATE VIEW v_region_category AS
SELECT region, category, sub_category,
       COUNT(*)    AS line_count,
       SUM(sales)  AS total_sales,
       SUM(profit) AS total_profit,
       SUM(profit) / SUM(sales) AS profit_margin
FROM orders
GROUP BY region, category, sub_category;

-- Q11c: View-dan oxu (sorgu artiq qisadir)
SELECT region, category, sub_category,
       ROUND(total_sales, 2)   AS total_sales,
       ROUND(total_profit, 2)  AS total_profit,
       ROUND(profit_margin, 4) AS profit_margin
FROM v_region_category
ORDER BY total_profit ASC;

-- Q11d: Kohne yigma cedveli sil (SQLite-da materialized view yoxdur)
DROP TABLE IF EXISTS region_category_summary;

-- Q11e: View-un neticesini real cedvel kimi saxla (materialized view evezi)
CREATE TABLE region_category_summary AS
SELECT * FROM v_region_category;

-- Q11f: Yigma cedvel uzerinde indeks
CREATE INDEX idx_summary_region_cat ON region_category_summary(region, category);

-- Q12: Bir regionda menfeetli, digerinde zererli sub-category-ler
SELECT sub_category,
       SUM(CASE WHEN total_profit > 0 THEN 1 ELSE 0 END) AS profitable_regions,
       SUM(CASE WHEN total_profit < 0 THEN 1 ELSE 0 END) AS losing_regions,
       GROUP_CONCAT(CASE WHEN total_profit > 0 THEN region END, ', ') AS profitable_in,
       GROUP_CONCAT(CASE WHEN total_profit < 0 THEN region END, ', ') AS losing_in
FROM (
  SELECT region, sub_category, SUM(profit) AS total_profit
  FROM orders
  GROUP BY region, sub_category
)
GROUP BY sub_category
HAVING profitable_regions > 0 AND losing_regions > 0
ORDER BY sub_category;

-- Q13: Ilin icinde ay uzre yigilan (cumulative) satis
WITH monthly AS (
  SELECT strftime('%Y', order_date) AS year,
         strftime('%m', order_date) AS month,
         SUM(sales) AS monthly_sales
  FROM orders
  GROUP BY strftime('%Y', order_date), strftime('%m', order_date)
)
SELECT year, month,
       ROUND(monthly_sales, 2) AS monthly_sales,
       ROUND(SUM(monthly_sales) OVER (PARTITION BY year ORDER BY month), 2) AS cumulative_sales
FROM monthly
ORDER BY year, month;

-- Q14a: Indeksi sil (yeniden islemek ucun)
DROP INDEX IF EXISTS idx_orders_region_cat_sub;

-- Q14b: Q5 sorgusunun icra plani (indeksden evvel)
EXPLAIN QUERY PLAN
SELECT region, category, sub_category,
       ROUND(SUM(sales), 2)  AS total_sales,
       ROUND(SUM(profit), 2) AS total_profit,
       ROUND(SUM(profit) / SUM(sales), 4) AS profit_margin
FROM orders
GROUP BY region, category, sub_category
ORDER BY total_profit ASC;

-- Q14c: Q5 ucun indeks yarat (qruplama acarlari + sales + profit)
CREATE INDEX idx_orders_region_cat_sub ON orders(region, category, sub_category, sales, profit);

-- Q14d: Q5 sorgusunun icra plani (indeksden sonra)
EXPLAIN QUERY PLAN
SELECT region, category, sub_category,
       ROUND(SUM(sales), 2)  AS total_sales,
       ROUND(SUM(profit), 2) AS total_profit,
       ROUND(SUM(profit) / SUM(sales), 4) AS profit_margin
FROM orders
GROUP BY region, category, sub_category
ORDER BY total_profit ASC;
