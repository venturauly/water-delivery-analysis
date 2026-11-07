
-- ============================================================
-- 03_CUSTOMER_ANALYSIS
-- Customer analysis using anonymized address IDs
--
-- Table: orders_anonymized
-- address_id = anonymized address identifier
-- One row = one order/request
-- ============================================================


-- ------------------------------------------------------------
-- 03_01. Order frequency by address
-- ------------------------------------------------------------

SELECT
    address_id,
    COUNT(*) AS delivered_orders,
    SUM("Количество воды") AS total_bottles,
    MIN(CAST("Date" AS DATE)) AS first_order_date,
    MAX(CAST("Date" AS DATE)) AS last_order_date
FROM orders_anonymized
WHERE "Status" = 'Доставлено'
GROUP BY address_id
ORDER BY delivered_orders DESC;


-- ------------------------------------------------------------
-- 03_02. Customer frequency segmentation
-- ------------------------------------------------------------

WITH address_orders AS (
    SELECT
        address_id,
        COUNT(*) AS delivered_orders,
        SUM("Количество воды") AS total_bottles
    FROM orders_anonymized
    WHERE "Status" = 'Доставлено'
    GROUP BY address_id
),

segmented_addresses AS (
    SELECT
        address_id,
        delivered_orders,
        total_bottles,
        CASE
            WHEN delivered_orders = 1 THEN 'One-time'
            WHEN delivered_orders BETWEEN 2 AND 3 THEN 'Occasional'
            WHEN delivered_orders BETWEEN 4 AND 6 THEN 'Regular'
            WHEN delivered_orders BETWEEN 7 AND 12 THEN 'Frequent'
            ELSE 'High frequency (13+)'
        END AS customer_segment
    FROM address_orders
)

SELECT
    customer_segment,
    COUNT(*) AS addresses,
    SUM(delivered_orders) AS delivered_orders,
    SUM(total_bottles) AS total_bottles,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS address_share_pct,
    ROUND(
        100.0 * SUM(total_bottles)
        / SUM(SUM(total_bottles)) OVER (),
        2
    ) AS bottle_share_pct
FROM segmented_addresses
GROUP BY customer_segment
ORDER BY
    CASE customer_segment
        WHEN 'One-time' THEN 1
        WHEN 'Occasional' THEN 2
        WHEN 'Regular' THEN 3
        WHEN 'Frequent' THEN 4
        ELSE 5
    END;


-- ------------------------------------------------------------
-- 03_03. Customer activity status
-- Reference date: 2026-10-29
-- ------------------------------------------------------------

WITH address_activity AS (
    SELECT
        address_id,
        COUNT(*) AS delivered_orders,
        SUM("Количество воды") AS total_bottles,
        MAX(CAST("Date" AS DATE)) AS last_order_date
    FROM orders_anonymized
    WHERE "Status" = 'Доставлено'
    GROUP BY address_id
),

activity_segments AS (
    SELECT
        address_id,
        delivered_orders,
        total_bottles,
        last_order_date,
        DATE_DIFF(
            'day',
            last_order_date,
            DATE '2026-10-29'
        ) AS days_since_last_order,
        CASE
            WHEN DATE_DIFF(
                'day', last_order_date, DATE '2026-10-29'
            ) <= 30 THEN 'Active: 0-30 days'
            WHEN DATE_DIFF(
                'day', last_order_date, DATE '2026-10-29'
            ) <= 60 THEN 'At risk: 31-60 days'
            ELSE 'Inactive: 60+ days'
        END AS activity_status
    FROM address_activity
)

SELECT
    activity_status,
    COUNT(*) AS addresses,
    SUM(delivered_orders) AS delivered_orders,
    SUM(total_bottles) AS total_bottles
FROM activity_segments
GROUP BY activity_status
ORDER BY
    CASE activity_status
        WHEN 'Active: 0-30 days' THEN 1
        WHEN 'At risk: 31-60 days' THEN 2
        ELSE 3
    END;


-- ------------------------------------------------------------
-- 03_04. Time between repeat orders
-- ------------------------------------------------------------

WITH ordered_deliveries AS (
    SELECT
        address_id,
        CAST("Date" AS DATE) AS order_date,
        LAG(CAST("Date" AS DATE)) OVER (
            PARTITION BY address_id
            ORDER BY CAST("Date" AS DATE)
        ) AS previous_order_date
    FROM orders_anonymized
    WHERE "Status" = 'Доставлено'
),

repeat_intervals AS (
    SELECT
        address_id,
        DATE_DIFF(
            'day',
            previous_order_date,
            order_date
        ) AS days_between_orders
    FROM ordered_deliveries
    WHERE previous_order_date IS NOT NULL
)

SELECT
    CASE
        WHEN days_between_orders <= 7 THEN '0-7 days'
        WHEN days_between_orders <= 14 THEN '8-14 days'
        WHEN days_between_orders <= 30 THEN '15-30 days'
        WHEN days_between_orders <= 60 THEN '31-60 days'
        ELSE '60+ days'
    END AS interval_group,
    COUNT(*) AS repeat_intervals,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS interval_share_pct
FROM repeat_intervals
GROUP BY interval_group
ORDER BY
    CASE interval_group
        WHEN '0-7 days' THEN 1
        WHEN '8-14 days' THEN 2
        WHEN '15-30 days' THEN 3
        WHEN '31-60 days' THEN 4
        ELSE 5
    END;


-- ------------------------------------------------------------
-- 03_05. Customer cohort retention
-- Cohort = first observed delivery month.
-- Active = at least one delivery in a calendar month.
-- ------------------------------------------------------------

WITH first_order AS (
    SELECT
        address_id,
        DATE_TRUNC(
            'month',
            MIN(CAST("Date" AS DATE))
        ) AS cohort_month
    FROM orders_anonymized
    WHERE "Status" = 'Доставлено'
    GROUP BY address_id
),

monthly_activity AS (
    SELECT DISTINCT
        address_id,
        DATE_TRUNC(
            'month',
            CAST("Date" AS DATE)
        ) AS activity_month
    FROM orders_anonymized
    WHERE "Status" = 'Доставлено'
),

cohort_activity AS (
    SELECT
        f.cohort_month,
        m.activity_month,
        DATE_DIFF(
            'month',
            f.cohort_month,
            m.activity_month
        ) AS months_since_first_order,
        COUNT(DISTINCT f.address_id) AS active_addresses
    FROM first_order f
    JOIN monthly_activity m
        ON f.address_id = m.address_id
    GROUP BY
        f.cohort_month,
        m.activity_month
),

cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(*) AS cohort_size
    FROM first_order
    GROUP BY cohort_month
)

SELECT
    a.cohort_month,
    a.activity_month,
    a.months_since_first_order,
    s.cohort_size,
    a.active_addresses,
    ROUND(
        100.0 * a.active_addresses / s.cohort_size,
        2
    ) AS retention_pct
FROM cohort_activity a
JOIN cohort_sizes s
    ON a.cohort_month = s.cohort_month
ORDER BY
    a.cohort_month,
    a.activity_month;
