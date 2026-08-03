-- Late delivery vs. review score
--
-- Splits delivered orders on whether they arrived after the date the customer
-- was promised (order_estimated_delivery_date), rather than on raw transit
-- time. The promise date is what the customer actually judges against —
-- which is why protecting the estimate matters more than shaving transit days.
--
-- Result: on-time 4.29 stars, late 2.57 stars.

SELECT CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN 'late' ELSE 'on_time' END AS delivery_status,
       COUNT(*)                       AS orders,
       ROUND(AVG(r.review_score), 2)  AS avg_review_score
FROM orders o
JOIN order_reviews r ON r.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY 1;
