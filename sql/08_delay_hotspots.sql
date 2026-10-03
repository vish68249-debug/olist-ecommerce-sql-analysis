-- 08_delay_hotspots.sql
-- Where and when do late deliveries happen, and how much of the bad-review
-- problem do they explain? Requires 06 and 07 (views delivered_orders, latest_review).

-- Q1. How much of the 1-2 star problem comes from late orders?
SELECT
    COUNT(*) FILTER (WHERE r.review_score <= 2)                                   AS bad_reviews_total,
    COUNT(*) FILTER (WHERE r.review_score <= 2
                     AND d.delivery_bucket <> '1. On time or early')              AS bad_reviews_from_late_orders,
    ROUND(100.0 * COUNT(*) FILTER (WHERE r.review_score <= 2
                     AND d.delivery_bucket <> '1. On time or early')
          / COUNT(*) FILTER (WHERE r.review_score <= 2), 1)                       AS pct_of_bad_reviews_from_late,
    ROUND(100.0 * AVG((d.delivery_bucket <> '1. On time or early')::INT), 1)      AS pct_of_orders_that_are_late
FROM delivered_orders d
JOIN latest_review r USING (order_id);

-- Q2. Late-delivery share by purchase month (2017 onwards)
SELECT
    strftime(order_purchase_timestamp, '%Y-%m') AS purchase_month,
    COUNT(*)                                    AS orders,
    ROUND(100.0 * AVG((delivery_bucket <> '1. On time or early')::INT), 1) AS pct_late
FROM delivered_orders
WHERE order_purchase_timestamp >= DATE '2017-01-01'
GROUP BY 1
ORDER BY 1;

-- Q3. Late-delivery share by customer state (states with 500+ orders)
SELECT
    c.customer_state,
    COUNT(*) AS orders,
    ROUND(100.0 * AVG((d.delivery_bucket <> '1. On time or early')::INT), 1) AS pct_late,
    MEDIAN(date_diff('day', o.order_purchase_timestamp::DATE,
                            o.order_delivered_customer_date::DATE))          AS median_days_to_deliver
FROM delivered_orders d
JOIN orders o    USING (order_id)
JOIN customers c ON c.customer_id = o.customer_id
GROUP BY c.customer_state
HAVING COUNT(*) >= 500
ORDER BY pct_late DESC;

-- Q4. Scale check: average order value (to size what repeat purchases are worth)
SELECT ROUND(SUM(v)) AS total_payments_brl, ROUND(AVG(v), 2) AS avg_order_value_brl, COUNT(*) AS orders
FROM (SELECT order_id, SUM(payment_value) AS v FROM order_payments GROUP BY order_id);
