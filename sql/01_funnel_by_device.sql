-- =====================================================================
-- 01_funnel_by_device.sql
-- Question: Where do sessions drop off in the purchase journey,
--           and does the drop-off differ by device?
-- Grain: session (user_pseudo_id + ga_session_id)
-- Funnel: closed funnel by presence; event order not enforced yet
-- =====================================================================

WITH events AS (
  SELECT
    user_pseudo_id,
    (SELECT value.int_value
       FROM UNNEST(event_params)
      WHERE key = 'ga_session_id') AS ga_session_id,
    event_name,
    device.category AS device
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),

sessions AS (
  SELECT
    CONCAT(user_pseudo_id, '-', CAST(ga_session_id AS STRING)) AS session_key,
    ANY_VALUE(device)                              AS device,
    MAX(IF(event_name = 'view_item',        1, 0)) AS viewed_item,
    MAX(IF(event_name = 'add_to_cart',      1, 0)) AS added_to_cart,
    MAX(IF(event_name = 'begin_checkout',   1, 0)) AS began_checkout,
    MAX(IF(event_name = 'add_payment_info', 1, 0)) AS added_payment,
    MAX(IF(event_name = 'purchase',         1, 0)) AS purchased
  FROM events
  WHERE ga_session_id IS NOT NULL
  GROUP BY session_key
),

funnel AS (
  SELECT
        CASE WHEN GROUPING(device) = 1 THEN 'All devices'
         ELSE COALESCE(device, '(null)') END              AS device_group,
    COUNT(*)                                              AS s0_sessions,
    COUNTIF(viewed_item = 1)                              AS s1_view_item,
    COUNTIF(viewed_item = 1 AND added_to_cart = 1)        AS s2_add_to_cart,
    COUNTIF(viewed_item = 1 AND added_to_cart = 1
            AND began_checkout = 1)                       AS s3_begin_checkout,
    COUNTIF(viewed_item = 1 AND added_to_cart = 1
            AND began_checkout = 1 AND added_payment = 1) AS s4_add_payment,
    COUNTIF(viewed_item = 1 AND added_to_cart = 1
            AND began_checkout = 1 AND added_payment = 1
            AND purchased = 1)                            AS s5_purchase
  FROM sessions
  GROUP BY ROLLUP(device)
)

SELECT
  device_group,
  s0_sessions,
  s1_view_item,
  s2_add_to_cart,
  s3_begin_checkout,
  s4_add_payment,
  s5_purchase,
  ROUND(SAFE_DIVIDE(s1_view_item,      s0_sessions),       4) AS cr_session_to_view,
  ROUND(SAFE_DIVIDE(s2_add_to_cart,    s1_view_item),      4) AS cr_view_to_cart,
  ROUND(SAFE_DIVIDE(s3_begin_checkout, s2_add_to_cart),    4) AS cr_cart_to_checkout,
  ROUND(SAFE_DIVIDE(s4_add_payment,    s3_begin_checkout), 4) AS cr_checkout_to_payment,
  ROUND(SAFE_DIVIDE(s5_purchase,       s4_add_payment),    4) AS cr_payment_to_purchase,
  ROUND(SAFE_DIVIDE(s5_purchase,       s0_sessions),       4) AS cr_overall
FROM funnel
ORDER BY s0_sessions DESC;
