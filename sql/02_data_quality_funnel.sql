-- 02_data_quality_funnel.sql
-- Check the data BEFORE analysing it. Each query answers one question.

-- Q1. Key integrity: duplicates and orphans
SELECT 'mql rows' AS check_name, COUNT(*) AS n, COUNT(DISTINCT mql_id) AS distinct_ids FROM mql
UNION ALL
SELECT 'closed_deals rows', COUNT(*), COUNT(DISTINCT mql_id) FROM closed_deals
UNION ALL
SELECT 'deals with no matching MQL (orphans)', COUNT(*), NULL
FROM closed_deals WHERE mql_id NOT IN (SELECT mql_id FROM mql);

-- Q2. Date coverage (watch for truncation!)
SELECT
    (SELECT MIN(first_contact_date) FROM mql)  AS first_contact_min,
    (SELECT MAX(first_contact_date) FROM mql)  AS first_contact_max,
    (SELECT MIN(won_date)::DATE FROM closed_deals) AS won_min,
    (SELECT MAX(won_date)::DATE FROM closed_deals) AS won_max;

-- Q3. Impossible values: deal won BEFORE first contact
SELECT mql_id, first_contact_date, won_date, days_to_close
FROM funnel WHERE days_to_close < 0;

-- Q4. Missing-value profile of the closed-deals columns
SELECT
    ROUND(100.0 * AVG((has_company IS NULL)::INT), 1)                  AS pct_null_has_company,
    ROUND(100.0 * AVG((has_gtin IS NULL)::INT), 1)                     AS pct_null_has_gtin,
    ROUND(100.0 * AVG((average_stock IS NULL)::INT), 1)                AS pct_null_average_stock,
    ROUND(100.0 * AVG((declared_product_catalog_size IS NULL)::INT), 1) AS pct_null_catalog_size,
    ROUND(100.0 * AVG((declared_monthly_revenue = 0)::INT), 1)         AS pct_revenue_is_zero,
    ROUND(100.0 * AVG((lead_behaviour_profile IS NULL)::INT), 1)       AS pct_null_behaviour
FROM closed_deals;

-- Q5. Origin labels: NULL and 'unknown' are different things
SELECT origin, COUNT(*) AS leads, ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM funnel GROUP BY origin ORDER BY leads DESC;
