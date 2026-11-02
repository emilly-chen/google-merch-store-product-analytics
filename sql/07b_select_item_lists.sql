-- 07b_select_item_lists.sql
-- Question: When users click an item in a list, does the data record which list
--           (e.g. search results) and the item's position? Decides whether we can
--           measure "clicked one of the top 3 search results".
SELECT
  it.item_list_name,
  it.item_list_index,
  COUNT(*) AS clicks
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
  UNNEST(items) AS it
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  AND event_name = 'select_item'
GROUP BY it.item_list_name, it.item_list_index
ORDER BY clicks DESC
LIMIT 50;
