-- 07_delivery_vs_reviews.sql
-- Business question: does late delivery drive bad reviews and lost repeat purchases?
-- Requires the core tables (06_load_core_tables.sql).
--
-- Traps handled:
--   * Some orders have more than one review -> keep the latest per order.
--   * customer_id is per-ORDER; customer_unique_id identifies the real person.
--   * Only delivered orders with a delivery date can be judged on-time/late.

CREATE OR REPLACE VIEW delivered_orders AS
SELECT
    o.order_id,
    c.customer_unique_id,
    o.order_purchase_timestamp,
    date_diff('day', o.order_estimated_delivery_date::DATE,
                     o.order_delivered_customer_date::DATE) AS days_late,   -- <=0 means on time/early
    CASE
        WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN '1. On time or early'
        WHEN date_diff('day', o.order_estimated_delivery_date::DATE, o.order_delivered_customer_date::DATE) <= 3 THEN '2. Late 1-3 days'
        WHEN date_diff('day', o.order_estimated_delivery_date::DATE, o.order_delivered_customer_date::DATE) <= 7 THEN '3. Late 4-7 days'
        ELSE '4. Late 8+ days'
    END AS delivery_bucket
FROM orders o
JOIN customers c USING (customer_id)
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL;

CREATE OR REPLACE VIEW latest_review AS
SELECT order_id, review_score
FROM order_reviews
QUALIFY ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY review_answer_timestamp DESC) = 1;

-- Q1. Review score by delivery performance
SELECT
    d.delivery_bucket,
    COUNT(*)                                       AS orders,
    ROUND(AVG(r.review_score), 2)                  AS avg_review,
    ROUND(100.0 * AVG((r.review_score <= 2)::INT), 1) AS pct_1_2_stars
FROM delivered_orders d
JOIN latest_review r USING (order_id)
GROUP BY d.delivery_bucket
ORDER BY d.delivery_bucket;

-- Q2. Repeat purchase rate by the experience of a customer's FIRST order
WITH first_order AS (
    SELECT customer_unique_id, order_id, delivery_bucket
    FROM delivered_orders
    QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_unique_id
                               ORDER BY order_purchase_timestamp) = 1
),
order_counts AS (
    SELECT customer_unique_id, COUNT(*) AS n_orders
    FROM delivered_orders GROUP BY customer_unique_id
)
SELECT
    f.delivery_bucket,
    COUNT(*)                                          AS customers,
    SUM((oc.n_orders > 1)::INT)                       AS repeat_customers,
    ROUND(100.0 * AVG((oc.n_orders > 1)::INT), 2)     AS repeat_rate_pct
FROM first_order f
JOIN order_counts oc USING (customer_unique_id)
GROUP BY f.delivery_bucket
ORDER BY f.delivery_bucket;
