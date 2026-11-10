-- SYNTHETIC/SIMULATED DATA. The dataset contains no real experiment.
-- Scenario S2 (docs/experiment_plan.md §6): S1 with broken assignment. About 3% of
-- treatment users are dropped (deterministic hash with salt 's2-drop:'), so the SRM
-- check should flag this scenario.

{{ config(materialized='table') }}

select
    user_pseudo_id,
    variant,
    pre_sessions_14d,
    purchased_7d,
    revenue_7d,
    n_orders_7d,
    is_synthetic_purchase
from {{ ref('synthetic_exp__s1') }}
where not (
    variant = 'treatment'
    and abs(mod(farm_fingerprint(concat('s2-drop:', user_pseudo_id)), 1000000)) / 1e6 < 0.03
)
