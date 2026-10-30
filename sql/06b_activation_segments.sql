-- =====================================================================
-- 06b_activation_segments.sql
-- Question: After excluding first-week purchasers, are users who viewed
--           3+ items in their first week still more likely to return?
-- Grain: one row per segment
-- Segments (mutually exclusive, checked in this order):
--   purchased            = first-week purchase
--   browsed_no_purchase  = 3+ item views, no purchase
--   neither              = everyone else
-- Cohorts: Nov 30 - Jan 4 only (same as 06). Associational only.
-- =====================================================================

WITH events AS (
  SELECT
    user_pseudo_id,
    event_name,
    DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS event_week
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),

first_week AS (
  SELECT
    user_pseudo_id,
    MIN(event_week) AS cohort_week
  FROM events
  GROUP BY user_pseudo_id
),

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
    AND e.event_week     = f.cohort_week
  WHERE f.cohort_week BETWEEN DATE '2020-11-30' AND DATE '2021-01-04'
  GROUP BY f.user_pseudo_id, f.cohort_week
),

returned AS (
  SELECT DISTINCT f.user_pseudo_id
  FROM first_week AS f
  JOIN events AS e
    ON e.user_pseudo_id = f.user_pseudo_id
  WHERE DATE_DIFF(e.event_week, f.cohort_week, WEEK(MONDAY)) BETWEEN 1 AND 3
),

users AS (
  SELECT
    u.*,
    IF(r.user_pseudo_id IS NULL, 0, 1) AS returned
  FROM user_flags AS u
  LEFT JOIN returned AS r
    USING (user_pseudo_id)
),

-- NEW: put every user into exactly one segment
segmented AS (
  SELECT
    *,
    CASE
      WHEN purchased = 1          THEN '1_purchased'
      WHEN viewed_3plus_items = 1 THEN '2_browsed_no_purchase'
      ELSE                             '3_neither'
    END AS segment
  FROM users
)

SELECT
  segment,
  COUNT(*)                                             AS users,
  ROUND(COUNT(*) / SUM(COUNT(*)) OVER (), 4)           AS share_of_users,
  SUM(returned)                                        AS returned_users,
  ROUND(SAFE_DIVIDE(SUM(returned), COUNT(*)), 4)       AS return_rate
FROM segmented
GROUP BY segment
ORDER BY segment;
