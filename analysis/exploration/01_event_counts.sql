SELECT
  event_name,
  COUNT(*)                                   AS n_events,
  COUNT(DISTINCT user_pseudo_id)             AS n_users,
  ROUND(COUNT(*) / SUM(COUNT(*)) OVER (), 4) AS share_of_events
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
GROUP BY event_name
ORDER BY n_events DESC;
