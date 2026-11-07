
-- ============================================================
-- 02_SALES_ANALYSIS
-- Sales analysis
-- Table: orders_anonymized
-- ============================================================


-- ------------------------------------------------------------
-- 02_01. Monthly sales volume
-- ------------------------------------------------------------

SELECT
    DATE_TRUNC('month', CAST("Date" AS DATE)) AS month,
    COUNT(*) AS delivered_orders,
    SUM("Количество воды") AS total_bottles,
    ROUND(AVG("Количество воды"), 2) AS avg_bottles_per_order
FROM orders_anonymized
WHERE "Status" = 'Доставлено'
GROUP BY month
ORDER BY month;


-- ------------------------------------------------------------
-- 02_02. Month-over-month sales change
-- ------------------------------------------------------------

WITH monthly_sales AS (
    SELECT
        DATE_TRUNC('month', CAST("Date" AS DATE)) AS month,
        COUNT(*) AS delivered_orders,
        SUM("Количество воды") AS total_bottles
    FROM orders_anonymized
    WHERE "Status" = 'Доставлено'
    GROUP BY month
),

sales_with_previous_month AS (
    SELECT
        month,
        delivered_orders,
        total_bottles,
        LAG(total_bottles) OVER (ORDER BY month) AS previous_month_bottles
    FROM monthly_sales
)

SELECT
    month,
    delivered_orders,
    total_bottles,
    previous_month_bottles,
    total_bottles - previous_month_bottles AS bottles_change,
    ROUND(
        100.0 * (total_bottles - previous_month_bottles)
        / NULLIF(previous_month_bottles, 0),
        2
    ) AS bottles_change_pct
FROM sales_with_previous_month
ORDER BY month;


-- ------------------------------------------------------------
-- 02_03. Order size analysis
-- ------------------------------------------------------------

SELECT
    ROUND(AVG("Количество воды"), 2) AS avg_bottles_per_order,
    MIN("Количество воды") AS min_bottles_per_order,
    MAX("Количество воды") AS max_bottles_per_order,
    MEDIAN("Количество воды") AS median_bottles_per_order
FROM orders_anonymized
WHERE "Status" = 'Доставлено'
  AND "Количество воды" IS NOT NULL;


-- ------------------------------------------------------------
-- 02_04. Sales by weekday
-- ------------------------------------------------------------

SELECT
    DAYNAME(CAST("Date" AS DATE)) AS weekday,
    DAYOFWEEK(CAST("Date" AS DATE)) AS weekday_number,
    COUNT(*) AS delivered_orders,
    SUM("Количество воды") AS total_bottles,
    ROUND(AVG("Количество воды"), 2) AS avg_bottles_per_order
FROM orders_anonymized
WHERE "Status" = 'Доставлено'
GROUP BY weekday, weekday_number
ORDER BY weekday_number;


-- ------------------------------------------------------------
-- 02_05. Order size distribution
-- ------------------------------------------------------------

WITH order_sizes AS (
    SELECT
        CASE
            WHEN "Количество воды" = 1 THEN '1 bottle'
            WHEN "Количество воды" = 2 THEN '2 bottles'
            WHEN "Количество воды" = 3 THEN '3 bottles'
            WHEN "Количество воды" BETWEEN 4 AND 5 THEN '4-5 bottles'
            WHEN "Количество воды" BETWEEN 6 AND 10 THEN '6-10 bottles'
            WHEN "Количество воды" > 10 THEN 'More than 10 bottles'
            ELSE 'Other'
        END AS order_size_group,
        CASE
            WHEN "Количество воды" = 1 THEN 1
            WHEN "Количество воды" = 2 THEN 2
            WHEN "Количество воды" = 3 THEN 3
            WHEN "Количество воды" BETWEEN 4 AND 5 THEN 4
            WHEN "Количество воды" BETWEEN 6 AND 10 THEN 5
            WHEN "Количество воды" > 10 THEN 6
            ELSE 7
        END AS sort_order,
        "Количество воды"
    FROM orders_anonymized
    WHERE "Status" = 'Доставлено'
      AND "Количество воды" IS NOT NULL
)

SELECT
    order_size_group,
    COUNT(*) AS delivered_orders,
    SUM("Количество воды") AS total_bottles,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS order_share_pct,
    ROUND(
        100.0 * SUM("Количество воды")
        / SUM(SUM("Количество воды")) OVER (),
        2
    ) AS bottle_share_pct
FROM order_sizes
GROUP BY order_size_group, sort_order
ORDER BY sort_order;


-- ------------------------------------------------------------
-- 02_06. Recorded payment amount analysis
-- Clean period: July 2025 - January 2026
-- Positive recorded totals only.
-- This is not a complete accounting revenue calculation.
-- ------------------------------------------------------------

SELECT
    DATE_TRUNC('month', CAST("Date" AS DATE)) AS month,
    COUNT(*) AS orders_with_positive_total,
    SUM("ИТОГО") AS recorded_total_amount,
    ROUND(AVG("ИТОГО"), 2) AS avg_recorded_order_amount,
    MEDIAN("ИТОГО") AS median_recorded_order_amount
FROM orders_anonymized
WHERE "Status" = 'Доставлено'
  AND CAST("Date" AS DATE) BETWEEN DATE '2025-07-29'
                               AND DATE '2026-01-31'
  AND "ИТОГО" > 0
GROUP BY month
ORDER BY month;
