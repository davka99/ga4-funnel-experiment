# Metrics

Every KPI states its numerator, denominator, grain, population and time window.

## Checkout conversion (primary experiment KPI) — draft

| Field        | Definition |
|--------------|------------|
| Numerator    | Distinct users (`user_pseudo_id`) with at least one `purchase` event |
| Denominator  | Distinct users (`user_pseudo_id`) with at least one `begin_checkout` event |
| Grain        | User |
| Population   | Users with at least one `begin_checkout` event in the window |
| Time window  | 2020-11-01 to 2021-01-31 (`_TABLE_SUFFIX` 20201101–20210131) |

**Rough baseline:** about 45.5% (4,419 purchasing users / 9,715 users who began checkout), from the raw event counts in `analysis/exploration/01_event_counts.sql`.

**Not yet checked (checkout conversion):**
- The numerator is not restricted to users who also began checkout, and step order (`begin_checkout` before `purchase`) has not been enforced.
- Duplicate purchase events and NULL `user_pseudo_id` have not been checked.

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
