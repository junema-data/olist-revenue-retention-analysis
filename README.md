# Where Does the Revenue Come From — and Why Do Customers Leave?

**A SQL + Excel analysis of 99,441 Brazilian e-commerce orders (Olist, 2016–2018)**

Author: June · Tools: PostgreSQL, Excel (PivotTables), Python (validation)

---

## Summary

I analysed a public dataset of ~100,000 orders from Olist, a Brazilian online marketplace, to answer a question any retailer cares about: **where is the money coming from, and what is quietly costing us customers?**

Three findings stood out:

- **Revenue is heavily concentrated.** São Paulo state alone drives **37.5%** of revenue, and the top three states account for **62.6%** — across a long tail of 4,119 cities.
- **Late delivery is the biggest destroyer of ratings.** On-time orders average **4.29 stars**; late orders average **2.57** — a 1.7-star drop. **38%** of all 1-star reviews were late deliveries.
- **Retention is the real weakness.** Only **3.1%** of customers ever place a second order. The business runs almost entirely on one-time buyers.

The headline recommendation: this marketplace doesn't have an acquisition problem, it has a **delivery-reliability and retention** problem — and both are measurable, fixable levers.

---

## Business question

Olist's leadership wants to know how to grow. Two cheap-to-pull but high-value questions:

1. **Concentration** — which regions and cities actually generate revenue, so marketing and logistics spend can be focused?
2. **Leakage** — what operational factors correlate with bad reviews and lost repeat business?

## Dataset

[Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) — a real, anonymised marketplace dataset spanning **Sept 2016 – Oct 2018**, split across 9 related tables (orders, order items, payments, reviews, customers, products, sellers, geolocation, category translations).

| Metric | Value |
|---|---|
| Orders | 99,441 |
| Unique customers | 96,096 |
| Total payment value | R$ 16.0M |
| Cities represented | 4,119 |
| Date range | 2016-09 → 2018-10 |

## Method

I worked across the full table relationships rather than a single flat file:

1. **PostgreSQL** — joined orders → payments → customers and aggregated revenue by customer, city, and state using CTEs and `GROUP BY`.
2. **Excel PivotTables** — exported the city-level aggregate (`city_revenue_analysis.csv`, 4,119 cities) and pivoted revenue by state and city for fast slicing.
3. **Python (pandas)** — used purely to **validate** every figure in this report against the raw tables before publishing.

### Core SQL

Revenue and average spend per city/state, the aggregate behind the Excel pivot:

```sql
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
```

Late-delivery vs. review score, the operational question:

```sql
SELECT CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN 'late' ELSE 'on_time' END AS delivery_status,
       COUNT(*)                       AS orders,
       ROUND(AVG(r.review_score), 2)  AS avg_review_score
FROM orders o
JOIN order_reviews r ON r.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY 1;
```

---

## Findings

### 1. Revenue is concentrated in the Southeast

| State | Revenue | Share |
|---|---|---|
| São Paulo (SP) | R$ 6.0M | 37.5% |
| Rio de Janeiro (RJ) | R$ 2.1M | 13.4% |
| Minas Gerais (MG) | R$ 1.9M | 11.7% |
| **Top 3 combined** | **R$ 10.0M** | **62.6%** |

São Paulo *city* alone is 13.8% of national revenue. The remaining ~4,100 cities form a very long, thin tail. **Implication:** marketing efficiency and logistics investment should be prioritised in the Southeast, while the long tail is better served by reliable shipping than by local spend.

### 2. Late delivery is the single biggest driver of bad reviews

Review score falls almost monotonically as delivery time grows:

| Delivery time | Avg. review score |
|---|---|
| 0–3 days | 4.48 |
| 4–7 days | 4.40 |
| 8–14 days | 4.31 |
| 15–21 days | 4.14 |
| 22+ days | 3.12 |

Splitting by the promise date is even sharper: **on-time = 4.29 stars, late = 2.57 stars.** Only 8% of orders arrive late, but they account for **38% of all 1-star reviews.** **Implication:** delivery reliability is a direct, controllable lever on customer satisfaction — protecting the estimated-delivery promise matters more than shaving average transit time.

### 3. The business is almost entirely one-time customers

Only **3.1%** of customers (2,997 of 96,096) ever place a second order. Average order value is **R$ 161 mean / R$ 105 median** (right-skewed). **Implication:** with acquisition clearly working, the largest untapped growth lever is **repeat purchase** — post-purchase CRM, lifecycle email, and loyalty — not more top-of-funnel spend.

### 4. Customers depend on credit installments

74% of payments are by credit card, and **67% of card orders are split into installments** (average 3.5). Boleto (a Brazilian cash voucher) is another 19%. **Implication:** installment support and boleto are not optional in this market; checkout, pricing and cash-flow planning all have to assume them.

---

## A data-modelling subtlety I caught

My first pass computed "average revenue per customer" as **R$ 160.99** — and so did the original query. On inspection, that figure is actually **average order value**, not average *customer* value, because Olist assigns a fresh `customer_id` to every order; the true person-level key is `customer_unique_id`. Re-aggregating on `customer_unique_id` is exactly what surfaced the 3.1% repeat rate in Finding 3. The lesson — always confirm what one row of your grain represents before trusting an average — is the kind of check I now run by default.

## What I'd do next

- Build a small dashboard (delivery SLA breaches and review score by state, refreshed weekly).
- Cohort the 3.1% repeat buyers to see which categories and delivery experiences drive a second order.
- Layer seller and freight data to model *why* some routes run late.

## Repository

```
project4/
├── README.md                      ← this analysis
├── SQL/                           ← queries + raw Olist tables
└── EXCEL/
    ├── city_revenue_analysis.csv  ← city-level revenue aggregate (4,119 cities)
    └── city_revenue_analysis.xlsx ← PivotTables by state and city
```

*All figures independently validated in pandas against the raw tables. Dataset: Olist (CC BY-NC-SA 4.0), via Kaggle.*
