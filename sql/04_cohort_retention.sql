-- =====================================================================
-- 04_cohort_retention.sql
-- Question: What share of new users come back in later weeks, and do
--           cohorts acquired during Black Friday / holidays retain differently?
-- Grain: one row per (cohort_week, week_number)
-- Cohort: week of a user's first event in the data (weeks start Monday)
-- Retention: user has any event in week N after their cohort week
-- Limitations: user_pseudo_id is a browser/device ID, so cross-device
--   users look like separate users (retention understated). Data starts
--   2020-11-01, so early-November cohorts include returning users from
--   before the window (left-censoring). Later cohorts have fewer
--   observable weeks (right-censoring).
-- =====================================================================

WITH events AS (                                              -- (1)
  SELECT
    user_pseudo_id,
    DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS event_week
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),

first_week AS (                                               -- (2)
  SELECT
    user_pseudo_id,
    MIN(event_week) AS cohort_week
  FROM events
  GROUP BY user_pseudo_id
),

weekly_activity AS (                                          -- (3)
  SELECT DISTINCT
    user_pseudo_id,
    event_week AS activity_week
  FROM events
),

cohort_activity AS (                                          -- (4)
  SELECT
    f.cohort_week,
    DATE_DIFF(w.activity_week, f.cohort_week, WEEK(MONDAY)) AS week_number,
    COUNT(DISTINCT w.user_pseudo_id)                        AS active_users
  FROM first_week AS f
  JOIN weekly_activity AS w
    ON f.user_pseudo_id = w.user_pseudo_id
  GROUP BY cohort_week, week_number
),

cohort_size AS (                                              -- (5)
  SELECT
    cohort_week,
    COUNT(*) AS cohort_users
  FROM first_week
  GROUP BY cohort_week
)

SELECT                                                        -- (6)
  a.cohort_week,
  s.cohort_users,
  a.week_number,
  a.active_users,
  ROUND(SAFE_DIVIDE(a.active_users, s.cohort_users), 4) AS retention_rate
FROM cohort_activity AS a
JOIN cohort_size AS s
  ON a.cohort_week = s.cohort_week
ORDER BY a.cohort_week, a.week_number;
