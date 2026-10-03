-- 03_channel_conversion.sql
-- Which acquisition channels turn leads into closed deals?
--
-- COHORT WINDOW: Jan-Apr 2018 contacts only. closed_deals has no wins before
-- 2017-12-05, so earlier cohorts are undercounted (left-truncation). April is the
-- last month with >6 months left to close before the data ends (2018-11-14).

WITH base AS (
    SELECT origin, COUNT(*) AS leads, SUM(won) AS won
    FROM funnel
    WHERE first_contact_date BETWEEN DATE '2018-01-01' AND DATE '2018-04-30'
    GROUP BY origin
),
wilson AS (   -- 95% Wilson score interval, computed by hand in SQL
    SELECT *,
        won * 1.0 / leads AS p,
        1.96 AS z
    FROM base
)
SELECT
    origin,
    leads,
    won,
    ROUND(100 * p, 2) AS conv_pct,
    ROUND(100 * ((p + z*z/(2*leads)) - z*SQRT(p*(1-p)/leads + z*z/(4*leads*leads)))
          / (1 + z*z/leads), 2) AS ci_low_pct,
    ROUND(100 * ((p + z*z/(2*leads)) + z*SQRT(p*(1-p)/leads + z*z/(4*leads*leads)))
          / (1 + z*z/leads), 2) AS ci_high_pct,
    RANK() OVER (ORDER BY p DESC) AS conv_rank
FROM wilson
ORDER BY leads DESC;
