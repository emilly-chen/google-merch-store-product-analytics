-- =====================================================================
-- 06_activation.sql
-- Question: Which first-week behaviors are associated with new users
--           returning in weeks 1-3?
-- Grain: one row per (behavior, did_behavior)
-- Activation candidate: first-week purchase. Leading indicators:
--   add_to_cart, search (view_search_results), 3+ item views.
-- Cohorts: Nov 30 - Jan 4 only (add_to_cart tracked reliably; every user
--   has 3 full follow-up weeks inside the data window).
-- Associational only: users who buy may already be more interested.
-- =====================================================================

WITH events AS (
  SELECT
    user_pseudo_id,
    event_name,
    DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS event_week
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),

-- One row per user: the week of their first event
first_week AS (
  SELECT
    user_pseudo_id,
    MIN(event_week) AS cohort_week
  FROM events
  GROUP BY user_pseudo_id
),

-- One row per user: what they did in their first week only
user_flags AS (
  SELECT
    f.user_pseudo_id,
    f.cohort_week,
    MAX(IF(e.event_name = 'purchase',            1, 0)) AS purchased,
    MAX(IF(e.event_name = 'add_to_cart',         1, 0)) AS added_to_cart,
    MAX(IF(e.event_name = 'view_search_results', 1, 0)) AS searched,
    IF(COUNTIF(e.event_name = 'view_item') >= 3, 1, 0)  AS viewed_3plus_items
  FROM first_week AS f
  JOIN events AS e
    ON  e.user_pseudo_id = f.user_pseudo_id
    AND e.event_week     = f.cohort_week          -- first-week events only (no look-ahead)
  WHERE f.cohort_week BETWEEN DATE '2020-11-30' AND DATE '2021-01-04'
  GROUP BY f.user_pseudo_id, f.cohort_week
),

-- One row per user who came back in weeks 1-3 after their cohort week
returned AS (
  SELECT DISTINCT f.user_pseudo_id
  FROM first_week AS f
  JOIN events AS e
    ON e.user_pseudo_id = f.user_pseudo_id
  WHERE DATE_DIFF(e.event_week, f.cohort_week, WEEK(MONDAY)) BETWEEN 1 AND 3
),

-- One row per user: first-week flags + returned (0/1)
users AS (
  SELECT
    u.*,
    IF(r.user_pseudo_id IS NULL, 0, 1) AS returned
  FROM user_flags AS u
  LEFT JOIN returned AS r                          -- keep users who never returned
    USING (user_pseudo_id)
)

-- Return rate for users who did vs did not do each behavior
SELECT
  behavior,
  did_behavior,
  COUNT(*)                                       AS users,
  SUM(returned)                                  AS returned_users,
  ROUND(SAFE_DIVIDE(SUM(returned), COUNT(*)), 4) AS return_rate
FROM users
UNPIVOT (did_behavior FOR behavior IN
         (purchased, added_to_cart, searched, viewed_3plus_items))
GROUP BY behavior, did_behavior
ORDER BY behavior, did_behavior DESC;
