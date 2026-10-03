-- 04_time_to_close.sql
-- How long do won deals take, and does it differ by channel?
-- (Only won leads have a close date, so this describes wins, not all leads.)

-- Overall distribution
SELECT
    COUNT(*)                          AS won_deals,
    MIN(days_to_close)                AS min_days,
    quantile_cont(days_to_close, 0.25) AS p25,
    MEDIAN(days_to_close)             AS median_days,
    quantile_cont(days_to_close, 0.75) AS p75,
    quantile_cont(days_to_close, 0.90) AS p90
FROM funnel WHERE won = 1 AND days_to_close >= 0;

-- By channel: share of wins closed within 7 / 30 / 90 days
SELECT
    origin,
    COUNT(*) AS won_deals,
    MEDIAN(days_to_close) AS median_days,
    ROUND(100.0 * AVG((days_to_close <= 7)::INT), 1)  AS pct_within_7d,
    ROUND(100.0 * AVG((days_to_close <= 30)::INT), 1) AS pct_within_30d,
    ROUND(100.0 * AVG((days_to_close <= 90)::INT), 1) AS pct_within_90d
FROM funnel
WHERE won = 1 AND days_to_close >= 0
GROUP BY origin
HAVING COUNT(*) >= 20      -- ignore tiny groups
ORDER BY median_days;
