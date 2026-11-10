# Decision log

| Date | Decision | Reason | Alternative considered |
|------|----------|--------|------------------------|
| 2026-11-10 | Funnel steps are `session_start` → `view_item` → `add_to_cart` → `begin_checkout` → `add_payment_info` → `purchase`. | `add_shipping_info` has almost exactly the same users as `begin_checkout` (9,714 vs 9,715), so it adds no information. | Keep `add_shipping_info` as a separate step between `begin_checkout` and `add_payment_info`. |
| 2026-11-10 | Exclude `view_item_list` and `select_item`. | The tracking is inconsistent (71 vs 31,007 events). | Include them as list-browsing steps before `view_item`. |
| 2026-11-10 | The primary experiment KPI is checkout conversion = users who purchase / users who begin checkout. | It matches the business question. The rough baseline is about 45.5% (not yet order-checked). | |
| 2026-11-10 | `stg_ga4__events` keeps every raw event row (no deduplication) and defines `session_key = user_pseudo_id-ga_session_id`. | Staging should mirror the source at event grain. Duplicates are measured first and handled downstream if needed. | Deduplicate in staging on (user_pseudo_id, event_ts, event_name). |
| 2026-11-10 | Warn (not fail) when more than 1% of `stg_ga4__events` rows have a NULL `session_key`. | Events without `ga_session_id` cannot be assigned to a session. 1% is an initial assumption to revisit once the actual share is known. | Fail on any NULL `session_key`. |
| 2026-11-10 | `traffic_medium` and `traffic_source` come from the `traffic_source` record. | It is the only traffic attribution in the export. It describes the user's first acquisition, not the session's source. | Session-level source from event params (`source`/`medium`). These are not used yet. |
