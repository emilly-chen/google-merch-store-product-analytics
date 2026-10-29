-- =====================================================================
-- 03_dq_missing_cart_by_date.sql
-- Question: Are purchase sessions missing add_to_cart concentrated on
--           certain dates (tracking outage) or spread evenly?
-- Grain: one row per date (session start date)
-- =====================================================================

WITH events AS (
  SELECT
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params)
      WHERE key = 'ga_session_id')            AS ga_session_id,
    PARSE_DATE('%Y%m%d', event_date)          AS event_date,   -- (1)
    event_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),

sessions AS (
  SELECT
    CONCAT(user_pseudo_id, '-', CAST(ga_session_id AS STRING)) AS session_key,
    MIN(event_date)                                AS session_date,   -- (2)
    MAX(IF(event_name = 'add_to_cart', 1, 0))      AS added_to_cart,
    MAX(IF(event_name = 'purchase',    1, 0))      AS purchased
  FROM events
  WHERE ga_session_id IS NOT NULL
  GROUP BY session_key
)

SELECT
  session_date,
  COUNT(*)                                         AS purchase_sessions,   -- (3)
  COUNTIF(added_to_cart = 0)                       AS missing_add_to_cart,
  ROUND(SAFE_DIVIDE(COUNTIF(added_to_cart = 0), COUNT(*)), 4)
                                                   AS share_missing_cart
FROM sessions
WHERE purchased = 1                                                        -- (4)
GROUP BY session_date
ORDER BY session_date;
