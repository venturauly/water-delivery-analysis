
-- ============================================================
-- 04_OPERATIONAL_ANALYSIS
-- Operational analysis
-- Table: orders_anonymized
-- ============================================================


-- ------------------------------------------------------------
-- 04_01. Order status distribution
-- ------------------------------------------------------------

SELECT
    "Status" AS order_status,
    COUNT(*) AS total_orders,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage_of_orders
FROM orders_anonymized
GROUP BY "Status"
ORDER BY total_orders DESC;


-- ------------------------------------------------------------
-- 04_02. Daily delivery workload
-- ------------------------------------------------------------

SELECT
    CAST("Date" AS DATE) AS delivery_date,
    COUNT(*) AS delivered_orders,
    SUM("Количество воды") AS total_bottles,
    ROUND(
        AVG("Количество воды"),
        2
    ) AS avg_bottles_per_order
FROM orders_anonymized
WHERE "Status" = 'Доставлено'
GROUP BY CAST("Date" AS DATE)
ORDER BY delivery_date;


-- ------------------------------------------------------------
-- 04_03. Daily workload summary
-- ------------------------------------------------------------

WITH daily_workload AS (
    SELECT
        CAST("Date" AS DATE) AS delivery_date,
        COUNT(*) AS delivered_orders,
        SUM("Количество воды") AS total_bottles
    FROM orders_anonymized
    WHERE "Status" = 'Доставлено'
    GROUP BY CAST("Date" AS DATE)
)

SELECT
    COUNT(*) AS days_with_deliveries,
    ROUND(AVG(delivered_orders), 2) AS avg_orders_per_day,
    MEDIAN(delivered_orders) AS median_orders_per_day,
    MAX(delivered_orders) AS max_orders_per_day,
    ROUND(AVG(total_bottles), 2) AS avg_bottles_per_day,
    MEDIAN(total_bottles) AS median_bottles_per_day,
    MAX(total_bottles) AS max_bottles_per_day
FROM daily_workload;


-- ------------------------------------------------------------
-- 04_04. Busiest delivery days
-- ------------------------------------------------------------

SELECT
    CAST("Date" AS DATE) AS delivery_date,
    COUNT(*) AS delivered_orders,
    SUM("Количество воды") AS total_bottles
FROM orders_anonymized
WHERE "Status" = 'Доставлено'
GROUP BY CAST("Date" AS DATE)
ORDER BY delivered_orders DESC, total_bottles DESC
LIMIT 15;
