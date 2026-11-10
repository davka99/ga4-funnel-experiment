-- SYNTHETIC/SIMULATED DATA. The dataset contains no real experiment.
-- Reporting table: exp_checkout_conversion_7d per variant in scenario S1, with 95% Wilson intervals.

{{ config(materialized='table') }}

with per_variant as (

    select
        variant,
        count(*)              as users,
        countif(purchased_7d) as buyers
    from {{ ref('synthetic_exp__s1') }}
    group by variant

)

select
    variant,
    users,
    buyers,
    safe_divide(buyers, users)                     as conversion,
    {{ wilson_bound('buyers', 'users', 'lower') }} as ci_low,
    {{ wilson_bound('buyers', 'users', 'upper') }} as ci_high,
    'SYNTHETIC/SIMULATED'                          as data_label
from per_variant
