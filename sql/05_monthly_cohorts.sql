-- 05_monthly_cohorts.sql
-- Monthly conversion by first-contact month, with a cumulative view of how
-- fast each cohort converts. Use it to SEE the truncation/censoring problems.

SELECT
    date_trunc('month', first_contact_date)::DATE AS cohort_month,
    COUNT(*)                                       AS leads,
    SUM(won)                                       AS won,
    ROUND(100.0 * AVG(won), 2)                     AS conv_pct,
    ROUND(100.0 * AVG((won = 1 AND days_to_close <= 30)::INT), 2) AS conv_30d_pct,
    ROUND(100.0 * AVG((won = 1 AND days_to_close <= 90)::INT), 2) AS conv_90d_pct
FROM funnel
GROUP BY 1
ORDER BY 1;

-- Landing pages with enough volume to compare (>= 100 leads)
SELECT
    LEFT(landing_page_id, 8) AS landing_page,
    COUNT(*) AS leads, SUM(won) AS won,
    ROUND(100.0 * AVG(won), 1) AS conv_pct
FROM funnel
WHERE first_contact_date BETWEEN DATE '2018-01-01' AND DATE '2018-04-30'
GROUP BY landing_page_id
HAVING COUNT(*) >= 100
ORDER BY conv_pct DESC;
