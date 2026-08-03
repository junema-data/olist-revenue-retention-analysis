-- Revenue and customers by city / state
--
-- Aggregates payment value at the order grain first, then rolls up to city
-- and state. Customers are counted on customer_unique_id, NOT customer_id:
-- Olist issues a fresh customer_id for every order, so counting customer_id
-- would silently turn "customers" into "orders".
--
-- Feeds the Excel PivotTable in city_revenue_analysis.csv (4,119 cities).

WITH order_revenue AS (
    SELECT o.order_id,
           c.customer_unique_id,
           c.customer_city,
           c.customer_state,
           SUM(p.payment_value) AS order_value
    FROM orders o
    JOIN order_payments p ON p.order_id = o.order_id
    JOIN customers       c ON c.customer_id = o.customer_id
    GROUP BY o.order_id, c.customer_unique_id, c.customer_city, c.customer_state
)
SELECT customer_state,
       customer_city,
       COUNT(DISTINCT customer_unique_id) AS customers,
       SUM(order_value)                   AS total_revenue,
       ROUND(SUM(order_value) / COUNT(DISTINCT customer_unique_id), 2) AS revenue_per_customer
FROM order_revenue
GROUP BY customer_state, customer_city
ORDER BY total_revenue DESC;
