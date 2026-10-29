-- =====================================================================
-- 05_north_star_weekly.sql
-- Question: How many customers buy each week (North Star), and is
--           growth coming from more buyers or from bigger orders?
-- Grain: one row per week (weeks start Monday)
-- North Star: weekly purchasing users = COUNT(DISTINCT user_pseudo_id)
-- Guardrails: average order value (AOV), revenue per purchaser
-- Window: full Nov 1 - Jan 31 (purchase events were tracked throughout;
--         see 02_dq_check). The 2020-10-26 week contains only Nov 1.
-- =====================================================================

WITH purchases AS (                                           -- (1)
  SELECT
    user_pseudo_id,
    DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS purchase_week,
    ecommerce.transaction_id                                  AS transaction_id,  -- (2)
    ecommerce.purchase_revenue_in_usd                         AS revenue_usd
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'                                                  -- (3)
)

SELECT
  purchase_week,

  -- North Star
  COUNT(DISTINCT user_pseudo_id)                              AS purchasing_users,

  -- Building blocks
  COUNT(*)                                                    AS purchase_events,
  COUNT(DISTINCT IF(transaction_id != '(not set)',
                    transaction_id, NULL))                    AS orders,          -- (4)
  ROUND(SUM(revenue_usd), 2)                                  AS revenue_usd,     -- (5)

  -- Guardrails
  ROUND(SAFE_DIVIDE(SUM(revenue_usd),
        COUNT(DISTINCT IF(transaction_id != '(not set)',
                          transaction_id, NULL))), 2)         AS aov_usd,
  ROUND(SAFE_DIVIDE(SUM(revenue_usd),
        COUNT(DISTINCT user_pseudo_id)), 2)                   AS revenue_per_purchaser_usd,

  -- Data-quality checks
  COUNTIF(transaction_id IS NULL
          OR transaction_id = '(not set)')                    AS events_missing_txn_id,  -- (6)
  COUNTIF(revenue_usd IS NULL)                                AS events_missing_revenue
FROM purchases
GROUP BY purchase_week
ORDER BY purchase_week;
