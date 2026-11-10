# Decision log

| Date | Decision | Reason | Alternative considered |
|------|----------|--------|------------------------|
| 2026-11-10 | Funnel steps are `session_start` → `view_item` → `add_to_cart` → `begin_checkout` → `add_payment_info` → `purchase`. | `add_shipping_info` has almost exactly the same users as `begin_checkout` (9,714 vs 9,715), so it adds no information. | Keep `add_shipping_info` as a separate step between `begin_checkout` and `add_payment_info`. |
| 2026-11-10 | Exclude `view_item_list` and `select_item`. | The tracking is inconsistent (71 vs 31,007 events). | Include them as list-browsing steps before `view_item`. |
| 2026-11-10 | The primary experiment KPI is checkout conversion = users who purchase / users who begin checkout. | It matches the business question. The rough baseline is about 45.5% (not yet order-checked). | |
