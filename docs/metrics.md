# Metrics

Every KPI states its numerator, denominator, grain, population and time window.

## checkout_conversion_7d (primary experiment KPI)

| Field        | Definition |
|--------------|------------|
| Population   | Users (`user_pseudo_id`) with at least one `begin_checkout` event in the data range and `has_full_window = true`, i.e. first `begin_checkout` before 2021-01-25 00:00 UTC |
| Grain        | User (one row per `user_pseudo_id` in `int_ga4__user_checkout`) |
| Numerator    | Users in the population with `purchased_within_7d = true`: at least one `purchase` event with `event_ts` >= `first_begin_checkout_ts` and < `first_begin_checkout_ts` + 7 days, in any session |
| Denominator  | All users in the population |
| Time window  | Exposure: first `begin_checkout` from 2020-11-01 to 2021-01-24 (UTC). Outcome: 7 days from each user's first `begin_checkout`. Data range: `_TABLE_SUFFIX` 20201101–20210131. |

**Notes:**
- Anchored on the user's *first* `begin_checkout` in the data range. Earlier checkouts before 2020-11-01 are not visible.
- A purchase without a valid `transaction_id` still counts (see `docs/decisions.md`).
- `user_pseudo_id` identifies a device/browser, not a person.
- The earlier rough figure (about 45.5%, 4,419 / 9,715 from `01_event_counts.sql`) ignored ordering and the 7-day window. It is superseded by the baseline below.

**Baseline** (`analysis/exploration/05_checkout_baseline.sql`, run 2026-11-10): **43.83%** (4,046 / 9,232 users), 95% Wilson CI 42.82%–44.84%. Of 9,715 users with a `begin_checkout`, 483 are outside the population because their window does not fit.

| Segment | Users | Purchased | Conversion | 95% Wilson CI |
|---------|------:|----------:|-----------:|--------------:|
| desktop | 5,346 | 2,320 | 43.40% | 42.07%–44.73% |
| mobile | 3,686 | 1,643 | 44.57% | 42.98%–46.18% |
| tablet | 200 | 83 | 41.50% | 34.89%–48.43% |

By ISO week (UTC) the rate rises from 29.12% in 2020-W45 to 58.35% in 2021-W03. 2020-W44 contains only 2020-11-01 (91 users, 16.48%).

The mix of new and returning users does not explain the trend (`06_baseline_trend_diagnostic.sql`, user × ISO-week anchors). Among new users (no `begin_checkout` in an earlier week) the rate rises the same way, from 29.12% in 2020-W45 to 58.35% in 2021-W03. Returning users convert higher (65–83%), but they are only 0.4%–12.3% of each week's users, which lifts the weekly rate by 0.13–3.70 percentage points (largest in 2020-W53). The cause of the remaining trend has not been investigated.

## Session funnel step conversion

| Field        | Definition |
|--------------|------------|
| Numerator    | Sessions with `reached_<step> = true` |
| Denominator  | Sessions with `reached_<previous step> = true`. For `view_item`, all sessions. |
| Grain        | Session (`session_key` in `int_ga4__session_funnel`) |
| Population   | Sessions with a non-NULL `session_key` and at least one event in the window |
| Time window  | 2020-11-01 to 2021-01-31 (`_TABLE_SUFFIX` 20201101–20210131). Sessions that cross the window edges are truncated. |

Steps, in order: `view_item` → `add_to_cart` → `begin_checkout` → `add_payment_info` → `purchase`. A step requires every earlier step in the same session, with first timestamps in non-decreasing order.

Source query: `analysis/exploration/04_session_funnel_steps.sql`. Results on 2026-11-10:

| Step | Sessions | From previous | From all sessions |
|------|---------:|--------------:|------------------:|
| all sessions | 360,129 | | 100.00% |
| view_item | 77,020 | 21.39% | 21.39% |
| add_to_cart | 15,146 | 19.67% | 4.21% |
| begin_checkout | 5,293 | 34.95% | 1.47% |
| add_payment_info | 3,723 | 70.34% | 1.03% |
| purchase | 2,751 | 73.89% | 0.76% |

**Caveat:** this is a within-session funnel. Steps completed in an earlier session are not counted, which mainly lowers `begin_checkout` and later steps (see `docs/decisions.md`).
