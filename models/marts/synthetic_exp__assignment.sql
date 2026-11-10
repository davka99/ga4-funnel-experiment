-- SYNTHETIC/SIMULATED DATA. The dataset contains no real experiment.
-- Simulated 50/50 assignment of the enrolled users (docs/experiment_plan.md §3):
-- deterministic hash of user_pseudo_id with the fixed salt 'checkout-v1:'.

{{ config(materialized='table') }}

select
    user_pseudo_id,
    if(
        abs(mod(farm_fingerprint(concat('checkout-v1:', user_pseudo_id)), 2)) = 0,
        'control',
        'treatment'
    ) as variant
from {{ ref('int_exp__enrolled_users') }}
