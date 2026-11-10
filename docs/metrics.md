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

**Not yet checked:**
- The numerator is not restricted to users who also began checkout, and step order (`begin_checkout` before `purchase`) has not been enforced.
- Duplicate purchase events and NULL `user_pseudo_id` have not been checked.
