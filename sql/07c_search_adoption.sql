-- =====================================================================
-- 07c_search_adoption.sql
-- Question: How many sessions use search, how often does search lead to
--           an item view, and do search sessions purchase more?
-- Grain: one row (overall metrics); unit of analysis = session
-- Adoption: session has view_search_results
-- Success:  a view_item happened after the session's first search
--           (last view_item timestamp > first search timestamp)
-- Outcome:  session purchase rate by search / success group
-- Window: full Nov 1 - Jan 31 (does not depend on add_to_cart).
-- Limitation: session-level success; a later failed search in a session
--   that already succeeded is not counted as a failure. Associational only.
-- =====================================================================

WITH events AS (
  SELECT
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params)
      WHERE key = 'ga_session_id') AS ga_session_id,
    event_name,
    event_timestamp                                   -- microseconds since 1970
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),

-- One row per session: search flag, key timestamps, purchase flag
sessions AS (
  SELECT
    CONCAT(user_pseudo_id, '-', CAST(ga_session_id AS STRING)) AS session_key,
    MAX(IF(event_name = 'view_search_results', 1, 0))               AS searched,
    MIN(IF(event_name = 'view_search_results', event_timestamp, NULL)) AS first_search_ts,
    MAX(IF(event_name = 'view_item',           event_timestamp, NULL)) AS last_view_item_ts,
    MAX(IF(event_name = 'purchase', 1, 0))                          AS purchased
  FROM events
  WHERE ga_session_id IS NOT NULL
  GROUP BY session_key
),

-- Add the success flag
flagged AS (
  SELECT
    *,
    IF(searched = 1 AND last_view_item_ts > first_search_ts, 1, 0) AS search_success
  FROM sessions
)

SELECT
  -- Adoption
  COUNT(*)                                                    AS sessions,
  COUNTIF(searched = 1)                                       AS search_sessions,
  ROUND(SAFE_DIVIDE(COUNTIF(searched = 1), COUNT(*)), 4)      AS search_adoption_rate,

  -- Success
  COUNTIF(search_success = 1)                                 AS successful_search_sessions,
  ROUND(SAFE_DIVIDE(COUNTIF(search_success = 1),
                    COUNTIF(searched = 1)), 4)                AS search_success_rate,

  -- Outcome: purchase rate by group
  ROUND(SAFE_DIVIDE(COUNTIF(searched = 0 AND purchased = 1),
                    COUNTIF(searched = 0)), 4)                AS purchase_rate_no_search,
  ROUND(SAFE_DIVIDE(COUNTIF(searched = 1 AND purchased = 1),
                    COUNTIF(searched = 1)), 4)                AS purchase_rate_search,
  ROUND(SAFE_DIVIDE(COUNTIF(search_success = 1 AND purchased = 1),
                    COUNTIF(search_success = 1)), 4)          AS purchase_rate_search_success,
  ROUND(SAFE_DIVIDE(COUNTIF(searched = 1 AND search_success = 0 AND purchased = 1),
                    COUNTIF(searched = 1 AND search_success = 0)), 4)
                                                              AS purchase_rate_search_fail
FROM flagged;
