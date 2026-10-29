-- 02_dq_check.sql
-- Question: How many purchase sessions are missing an earlier funnel step?
WITH events AS (
  SELECT
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params)
      WHERE key = 'ga_session_id') AS ga_session_id,
    event_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
sessions AS (
  SELECT
    CONCAT(user_pseudo_id, '-', CAST(ga_session_id AS STRING)) AS session_key,
    MAX(IF(event_name = 'view_item',        1, 0)) AS viewed_item,
    MAX(IF(event_name = 'add_to_cart',      1, 0)) AS added_to_cart,
    MAX(IF(event_name = 'begin_checkout',   1, 0)) AS began_checkout,
    MAX(IF(event_name = 'add_payment_info', 1, 0)) AS added_payment,
    MAX(IF(event_name = 'purchase',         1, 0)) AS purchased
  FROM events
  WHERE ga_session_id IS NOT NULL
  GROUP BY session_key
)
SELECT
  COUNTIF(purchased = 1)                       AS purchase_sessions,
  COUNTIF(purchased = 1 AND viewed_item = 0)   AS missing_view_item,
  COUNTIF(purchased = 1 AND added_to_cart = 0) AS missing_add_to_cart,
  COUNTIF(purchased = 1 AND began_checkout = 0) AS missing_begin_checkout,
  COUNTIF(purchased = 1 AND added_payment = 0) AS missing_add_payment
FROM sessions;
