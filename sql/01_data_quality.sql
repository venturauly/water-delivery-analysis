
-- ============================================================
-- 01_DATA_QUALITY
-- Data quality checks
-- Table: orders_anonymized
-- ============================================================


-- 01_01. Table structure

DESCRIBE orders_anonymized;


-- 01_02. Total rows and unique address IDs

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT address_id) AS unique_addresses
FROM orders_anonymized;


-- 01_03. Date range

SELECT
    MIN(CAST("Date" AS DATE)) AS first_date,
    MAX(CAST("Date" AS DATE)) AS last_date,
    COUNT(DISTINCT CAST("Date" AS DATE)) AS unique_dates
FROM orders_anonymized;


-- 01_04. Order status distribution

SELECT
    "Status" AS order_status,
    COUNT(*) AS total_rows,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage
FROM orders_anonymized
GROUP BY "Status"
ORDER BY total_rows DESC;


-- 01_05. Missing values in important columns

SELECT
    COUNT(*) FILTER (WHERE "Order" IS NULL) AS missing_order,
    COUNT(*) FILTER (WHERE "Date" IS NULL) AS missing_date,
    COUNT(*) FILTER (WHERE "Status" IS NULL) AS missing_status,
    COUNT(*) FILTER (WHERE "Количество воды" IS NULL) AS missing_quantity,
    COUNT(*) FILTER (WHERE "Цена воды" IS NULL) AS missing_water_price,
    COUNT(*) FILTER (WHERE "ИТОГО" IS NULL) AS missing_total
FROM orders_anonymized;


-- 01_06. Full duplicate rows

SELECT
    COUNT(*) AS duplicated_groups
FROM (
    SELECT
        address_id,
        "Date",
        "Status",
        "Предоплата",
        "Тип оплаты",
        "Количество воды",
        "Цена воды",
        "Дополнительные товары",
        "Цена дополнительных товаров",
        "ИТОГО"
    FROM orders_anonymized
    GROUP BY
        address_id,
        "Date",
        "Status",
        "Предоплата",
        "Тип оплаты",
        "Количество воды",
        "Цена воды",
        "Дополнительные товары",
        "Цена дополнительных товаров",
        "ИТОГО"
    HAVING COUNT(*) > 1
) AS duplicates;
