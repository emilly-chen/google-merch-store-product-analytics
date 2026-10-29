-- =====================================================================
-- 05b_aov_dedup.sql
-- Question: What is average order value per week once duplicate purchase
--           events are removed and numerator/denominator use the same orders?
-- Grain: one row per week; orders deduplicated by transaction_id
-- Fixes 05: (a) duplicate purchase events double-counted revenue (mid-Nov);
--           (b) revenue included events without transaction_id while the
--           order count did not.
-- Limitation: transaction_id is missing Nov 1-8, 42% missing week of Nov 9,
--           70% missing week of Jan 25. Use AOV for Nov 16 - Jan 18 only.
-- =====================================================================

WITH purchases AS (
  SELECT
    user_pseudo_id,
    DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS purchase_week,
    ecommerce.transaction_id                                  AS transaction_id,
    ecommerce.purchase_revenue_in_usd                         AS revenue_usd
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
),

orders AS (                                   -- one row per order
  SELECT
    transaction_id,
    MIN(purchase_week)      AS order_week,
    ANY_VALUE(user_pseudo_id) AS user_pseudo_id,
    MAX(revenue_usd)        AS revenue_usd    -- duplicates carry the same amount
  FROM purchases
  WHERE transaction_id IS NOT NULL
    AND transaction_id != '(not set)'
  GROUP BY transaction_id
)

SELECT
  order_week,
  COUNT(*)                                             AS orders,
  COUNT(DISTINCT user_pseudo_id)                       AS purchasers_with_order_id,
  ROUND(SUM(revenue_usd), 2)                           AS revenue_usd,
  ROUND(SAFE_DIVIDE(SUM(revenue_usd), COUNT(*)), 2)    AS aov_usd,
  ROUND(SAFE_DIVIDE(SUM(revenue_usd),
        COUNT(DISTINCT user_pseudo_id)), 2)            AS revenue_per_purchaser_usd
FROM orders
GROUP BY order_week
ORDER BY order_week;
