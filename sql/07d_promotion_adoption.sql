-- =====================================================================
-- 07d_promotion_adoption.sql
-- Question: How many sessions see a promotion, how often does seeing one
--           lead to a click, and do sessions that click buy more?
-- Grain: one row (overall metrics); unit of analysis = session
-- Adoption: session has view_promotion (saw a promotion)
-- Success:  a select_promotion happened after the session's first
--           view_promotion (last click timestamp > first view timestamp)
-- Outcome:  session purchase rate by group
-- Window: full Nov 1 - Jan 31 (does not depend on add_to_cart).
-- Limitations: session-level; promotion names/creatives not analyzed;
--   associational only (clickers may already intend to buy).
-- =====================================================================

WITH events AS (
  SELECT
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params)
      WHERE key = 'ga_session_id') AS ga_session_id,
    event_name,
    event_timestamp
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),

-- One row per session: promotion flags, key timestamps, purchase flag
sessions AS (
  SELECT
    CONCAT(user_pseudo_id, '-', CAST(ga_session_id AS STRING)) AS session_key,
    MAX(IF(event_name = 'view_promotion',   1, 0))                    AS saw_promo,
    MAX(IF(event_name = 'select_promotion', 1, 0))                    AS clicked_promo_any,
    MIN(IF(event_name = 'view_promotion',   event_timestamp, NULL))   AS first_promo_view_ts,
    MAX(IF(event_name = 'select_promotion', event_timestamp, NULL))   AS last_promo_click_ts,
    MAX(IF(event_name = 'purchase', 1, 0))                            AS purchased
  FROM events
  WHERE ga_session_id IS NOT NULL
  GROUP BY session_key
),

-- Add the success flag: clicked a promotion after first seeing one
flagged AS (
  SELECT
    *,
    IF(saw_promo = 1 AND last_promo_click_ts > first_promo_view_ts, 1, 0) AS promo_click
  FROM sessions
)

SELECT
  -- Adoption
  COUNT(*)                                                    AS sessions,
  COUNTIF(saw_promo = 1)                                      AS promo_view_sessions,
  ROUND(SAFE_DIVIDE(COUNTIF(saw_promo = 1), COUNT(*)), 4)     AS promo_view_rate,

  -- Success (click-through)
  COUNTIF(promo_click = 1)                                    AS promo_click_sessions,
  ROUND(SAFE_DIVIDE(COUNTIF(promo_click = 1),
                    COUNTIF(saw_promo = 1)), 4)               AS promo_click_rate,

  -- Outcome: purchase rate by group
  ROUND(SAFE_DIVIDE(COUNTIF(saw_promo = 0 AND purchased = 1),
                    COUNTIF(saw_promo = 0)), 4)               AS purchase_rate_no_promo_view,
  ROUND(SAFE_DIVIDE(COUNTIF(saw_promo = 1 AND purchased = 1),
                    COUNTIF(saw_promo = 1)), 4)               AS purchase_rate_promo_view,
  ROUND(SAFE_DIVIDE(COUNTIF(promo_click = 1 AND purchased = 1),
                    COUNTIF(promo_click = 1)), 4)             AS purchase_rate_promo_click,
  ROUND(SAFE_DIVIDE(COUNTIF(saw_promo = 1 AND promo_click = 0 AND purchased = 1),
                    COUNTIF(saw_promo = 1 AND promo_click = 0)), 4)
                                                              AS purchase_rate_promo_no_click,

  -- Data quality: clicks with no tracked promotion view in the session
  COUNTIF(clicked_promo_any = 1 AND saw_promo = 0)            AS dq_click_without_view
FROM flagged;
