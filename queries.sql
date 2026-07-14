-- ============================================================
-- Supply Chain Performance Analysis.
-- SQL Queries: Basic → Subquery → CTE → Window Functions
-- Database: DuckDB (compatible with PostgreSQL syntax)
-- ============================================================


-- ============================================================
-- QUERY 1: Sales & Shipping Performance by Market
-- Techniques: GROUP BY, COUNT, SUM, AVG, ORDER BY
-- Business question: Which market generates the most revenue
--                    and how fast do we deliver there?
-- ============================================================

SELECT 
    Market,
    COUNT(*) AS total_orders,
    ROUND(SUM(Sales), 2) AS total_sales,
    ROUND(AVG("Days for shipping (real)"), 2) AS avg_shipping_days
FROM supply_chain
GROUP BY Market
ORDER BY total_sales DESC;


-- ============================================================
-- QUERY 2: Late Delivery Rate by Shipping Mode
-- Techniques: CASE WHEN, HAVING, conditional aggregation
-- Business question: Which shipping mode has the highest
--                    late delivery rate?
-- ============================================================

SELECT 
    "Shipping Mode",
    COUNT(*) AS total_orders,
    SUM(CASE WHEN "Late_delivery_risk" = 1 THEN 1 ELSE 0 END) AS late_orders,
    ROUND(
        SUM(CASE WHEN "Late_delivery_risk" = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
    2) AS late_rate_pct
FROM supply_chain
GROUP BY "Shipping Mode"
HAVING COUNT(*) > 1000
ORDER BY late_rate_pct DESC;


-- ============================================================
-- QUERY 3: Orders Above Global Average Sales
-- Techniques: Subquery, WHERE, LIMIT
-- Business question: Which orders significantly exceed
--                    the global average sales value?
-- ============================================================

SELECT 
    Market,
    "Order Id",
    Sales,
    ROUND((SELECT AVG(Sales) FROM supply_chain), 2) AS avg_sales_global,
    ROUND(Sales - (SELECT AVG(Sales) FROM supply_chain), 2) AS above_avg_by
FROM supply_chain
WHERE Sales > (SELECT AVG(Sales) FROM supply_chain)
ORDER BY Sales DESC
LIMIT 10;


-- ============================================================
-- QUERY 4: Regional Late Delivery Analysis
-- Techniques: CTE (Common Table Expression)
-- Business question: Which regions have the worst
--                    on-time delivery performance?
-- ============================================================

WITH regional_stats AS (
    SELECT 
        "Order Region",
        COUNT(*) AS total_orders,
        SUM(Late_delivery_risk) AS late_orders,
        ROUND(SUM(Late_delivery_risk) * 100.0 / COUNT(*), 2) AS late_rate_pct,
        ROUND(AVG("Days for shipping (real)"), 2) AS avg_shipping_days
    FROM supply_chain
    GROUP BY "Order Region"
)
SELECT *
FROM regional_stats
WHERE total_orders > 500
ORDER BY late_rate_pct DESC
LIMIT 10;


-- ============================================================
-- QUERY 5: Country Ranking Within Regions
-- Techniques: RANK() OVER (PARTITION BY), AVG() OVER,
--             nested CTEs, statistical filtering (HAVING)
-- Business question: Which country within each region
--                    has the worst late delivery rate?
-- ============================================================

WITH regional_stats AS (
    SELECT 
        "Order Region",
        "Order Country",
        COUNT(*) AS total_orders,
        ROUND(SUM(Late_delivery_risk) * 100.0 / COUNT(*), 2) AS late_rate_pct,
        ROUND(AVG(Sales), 2) AS avg_sales
    FROM supply_chain
    GROUP BY "Order Region", "Order Country"
    HAVING COUNT(*) > 200
),
ranked AS (
    SELECT *,
        RANK() OVER (
            PARTITION BY "Order Region" 
            ORDER BY late_rate_pct DESC
        ) AS rank_in_region,
        ROUND(AVG(late_rate_pct) OVER (
            PARTITION BY "Order Region"
        ), 2) AS avg_late_rate_region
    FROM regional_stats
)
SELECT *
FROM ranked
WHERE rank_in_region = 1
ORDER BY late_rate_pct DESC
LIMIT 10;


-- ============================================================
-- QUERY 6: Monthly Late Delivery Trend (Rolling Average)
-- Techniques: DATE_TRUNC, CTE, AVG() OVER,
--             ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
-- Business question: Is the late delivery problem
--                    improving or worsening over time?
-- ============================================================

WITH monthly_stats AS (
    SELECT 
        DATE_TRUNC('month', "order date (DateOrders)") AS order_month,
        COUNT(*) AS total_orders,
        ROUND(SUM(Late_delivery_risk) * 100.0 / COUNT(*), 2) AS late_rate_pct
    FROM supply_chain
    GROUP BY DATE_TRUNC('month', "order date (DateOrders)")
)
SELECT 
    order_month,
    total_orders,
    late_rate_pct,
    ROUND(AVG(late_rate_pct) OVER (
        ORDER BY order_month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_avg_3m
FROM monthly_stats
ORDER BY order_month;
