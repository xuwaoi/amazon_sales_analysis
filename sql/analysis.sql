-- Проверка качества данных 
SELECT COUNT(*) AS total_rows,
SUM(amount IS NULL) AS null_amounts,
SUM(date IS NULL) AS null_dates FROM orders;

-- Проверка дубликатов заказов 
SELECT order_id, COUNT(*) AS count_orders FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY count_orders DESC;

-- Динамика выручки по месяцам 
SELECT DATE_FORMAT(date, '%Y-%m') AS month,
SUM(amount) AS monthly_revenue,
SUM(SUM(amount)) OVER (ORDER BY DATE_FORMAT(date, '%Y-%m')) AS cumulative_revenue FROM orders
GROUP BY month
ORDER BY month;
-- Анализ показал ярко выраженную сезонность продаж. Более 65% выручки было сделано с апреля по июнь 2022 года.
-- В апреле был зафиксирован аномальный рост выручки, что требует дополнительного анализа.

-- Что именно дало апрельский рост?
SELECT category, SUM(amount) AS revenue FROM orders
WHERE MONTH(date) = 4
GROUP BY category;
-- Анализ структуры выручки показал высокую концентрацию продаж: категории Set и Kurta формируют основную часть дохода,
-- в то время как остальные категории имеют значительно меньший вклад.

-- Доля каждой категории: 
SELECT category, SUM(amount) AS revenue,
ROUND(SUM(amount)/SUM(SUM(amount)) OVER () * 100, 2
) AS revenue_share_percent FROM orders
GROUP BY category 
ORDER BY revenue DESC;

-- Категории по времени
SELECT DATE_FORMAT(date, '%Y-%m') AS month, category, SUM(amount) AS revenue FROM orders
GROUP BY month, category
ORDER BY month, revenue DESC;
-- Выявлен ярко выраженный сезонный пик в период апрель–июнь 2022 года, затронувший все ключевые категории. Категории Set и Kurta стабильно формируют
-- основную часть выручки, в то время как остальные категории образуют длинный хвост с низким, но устойчивым вкладом.

-- Зависимость категорий от b2b
SELECT category, b2b, SUM(amount) AS revenue FROM orders
GROUP BY category, b2b 
ORDER BY revenue DESC;
SELECT b2b, COUNT(order_id) AS counter FROM orders
GROUP BY b2b;
-- Анализ сегментации клиентов показал, что подавляющее большинство заказов относится к B2C-сегменту. B2B-заказы составляют незначительную долю
-- как по количеству заказов, так и по общей выручке. Это указывает на сильную ориентацию бизнеса на розничных клиентов и наличие потенциала
-- для развития B2B-направления, особенно в категориях с высокой выручкой.

-- Доля топ-2 категорий в общей выручке
WITH category_revenue AS (
SELECT category, SUM(amount) AS revenue FROM orders
GROUP BY category
)
SELECT SUM(CASE WHEN category in ('Set', 'kurta') THEN revenue ELSE 0 END) AS top2_revenue, 
SUM(revenue) AS total_revenue, ROUND(SUM(CASE WHEN category in ('Set', 'kurta') THEN revenue ELSE 0 END)/SUM(revenue) * 100, 2) AS top2_share_percent
FROM category_revenue;

-- Доля SKU внутри категории
WITH sku_revenue AS (
SELECT category, sku, SUM(amount) AS revenue FROM orders
GROUP BY category, sku
)
SELECT category, sku, revenue, ROUND(revenue / SUM(revenue) OVER (PARTITION BY category) * 100,2) AS share_in_category_percent
FROM sku_revenue
ORDER BY category, revenue DESC;

-- Топ 3 товара в каждой категории
WITH sku_revenue AS (
SELECT category, sku, SUM(amount) AS revenue FROM orders
GROUP BY category, sku
),
ranked_sku AS (
SELECT category, sku, revenue, DENSE_RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS rnk
FROM sku_revenue
)
SELECT * FROM ranked_sku
WHERE rnk <= 3
ORDER BY category, revenue DESC;

-- Сколько денег теряем на отменах? 
SELECT DISTINCT status, COUNT(*) AS count_lines, SUM(amount) as revenue FROM orders 
GROUP BY status 
ORDER BY revenue DESC

-- В процентах нагляднее: 
SELECT status, SUM(amount) AS revenue, ROUND(SUM(amount)/ SUM(SUM(amount)) OVER() * 100, 2) AS revenue_share_percent FROM orders 
GROUP BY status 
ORDER BY revenue_share_percent DESC

-- Сколько реально заработано денег?
SELECT CASE WHEN status IN ('Shipped', 'Shipped - Delivered to Buyer') THEN 'Delivered / Revenue'
WHEN status IN ('Cancelled', 'Shipped - Returned to Seller', 'Shipped - Returning to Seller', 'Shipped - Rejected by Buyer', 'Shipped - Lost in Transit',
'Shipped - Damaged')
THEN 'Lost Revenue' ELSE 'In Progress' END AS status_group,
SUM(amount) AS revenue, ROUND(SUM(amount) / SUM(SUM(amount)) OVER () * 100, 2) AS revenue_share_percent FROM orders
GROUP BY status_group
ORDER BY revenue DESC;
-- Основной денежный поток бизнеса качественный: большая часть заказов успешно доставляется.
-- Потери не критические, но достаточно велики, чтобы оправдать отдельный анализ причин отмен и возвратов.
-- Статусы заказов можно успешно агрегировать в бизнес-группы для управленческой аналитики и дашбордов.

-- Топ 10 городов по выручке: 
SELECT
ship_city, SUM(amount) AS revenue FROM orders
GROUP BY ship_city
ORDER BY revenue DESC
LIMIT 10;
-- Географический анализ показал, что основные продажи сосредоточены в крупных городах, таких как Bengaluru, Hyderabad и Mumbai.

-- Накопительная выручка по дням 
WITH daily_revenue AS (
SELECT date, SUM(amount) AS revenue FROM orders
GROUP BY date
)
SELECT date, revenue, SUM(revenue) OVER (ORDER BY date) AS cumulative_revenue
FROM daily_revenue
ORDER BY date 
-- Накопительная выручка позволяет увидеть динамику роста бизнеса и скорость накопления дохода во времени.
-- Резкие изменения наклона кривой могут указывать на сезонные пики продаж.

-- ABC анализ SKU по выручке
WITH sku_revenue AS (
SELECT sku, SUM(amount) AS revenue FROM orders
GROUP BY sku
),
ranked_sku AS (
SELECT sku, revenue, SUM(revenue) OVER (ORDER BY revenue DESC) AS cumulative_revenue,
SUM(revenue) OVER () AS total_revenue FROM sku_revenue
),
abc_classification AS (
SELECT sku, revenue, cumulative_revenue, total_revenue,
cumulative_revenue / total_revenue AS cumulative_share FROM ranked_sku
)
SELECT sku, revenue, ROUND(cumulative_share * 100,2) AS cumulative_percent,
CASE WHEN cumulative_share <= 0.8 THEN 'A' WHEN cumulative_share <= 0.95 THEN 'B' ELSE 'C' END AS abc_group
FROM abc_classification
ORDER BY revenue DESC;
-- ABC анализ показал, что небольшая доля SKU формирует основную часть выручки. Это соответствует принципу Pareto,
-- характерному для e-commerce.

-- Количество товаров в группах ABC
WITH abc AS (
SELECT sku, SUM(amount) AS revenue FROM orders
GROUP BY sku
),
ranked AS (
SELECT sku, revenue, SUM(revenue) OVER (ORDER BY revenue DESC) / SUM(revenue) OVER () AS cumulative_share
FROM abc
)
SELECT CASE WHEN cumulative_share <= 0.8 THEN 'A' WHEN cumulative_share <= 0.95 THEN 'B' ELSE 'C'
END AS abc_group, COUNT(*) AS sku_count FROM ranked
GROUP BY abc_group
ORDER BY abc_group;

