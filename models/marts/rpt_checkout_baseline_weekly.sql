{{ config(materialized='table') }}

-- Reporting table: checkout_conversion_7d by ISO week (UTC) of the first begin_checkout,
-- with 95% Wilson intervals (real data). Same population as analysis/exploration/05_checkout_baseline.sql:
-- users with has_full_window = true.
-- is_partial_week: the ISO week starts before the first data day (2020-11-01) or ends after
-- the last day with a full 7-day window (2021-01-24), so it does not cover all 7 days.

with population as (

    select
        first_begin_checkout_ts,
        purchased_within_7d
    from {{ ref('int_ga4__user_checkout') }}
    where has_full_window

),

weekly as (

    select
        format_timestamp('%G-W%V', first_begin_checkout_ts)          as iso_week,
        min(date_trunc(date(first_begin_checkout_ts), isoweek))      as week_start_date,
        count(*)                                                     as users,
        countif(purchased_within_7d)                                 as buyers
    from population
    group by iso_week

)

select
    iso_week,
    week_start_date,
    users,
    buyers,
    safe_divide(buyers, users)                          as conversion,
    {{ wilson_bound('buyers', 'users', 'lower') }}      as ci_low,
    {{ wilson_bound('buyers', 'users', 'upper') }}      as ci_high,
    week_start_date < date '2020-11-01'
        or date_add(week_start_date, interval 6 day) > date '2021-01-24' as is_partial_week
from weekly
