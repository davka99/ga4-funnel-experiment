-- Baseline for checkout_conversion_7d (see docs/metrics.md) with 95% Wilson score intervals:
-- overall, by ISO week of first_begin_checkout_ts (UTC) and by device_category.
-- Population: users with has_full_window = true.

with population as (

    select
        first_begin_checkout_ts,
        purchased_within_7d,
        device_category
    from {{ ref('int_ga4__user_checkout') }}
    where has_full_window

),

grouped as (

    select
        'overall'                    as breakdown,
        'all'                        as segment,
        count(*)                     as n_users,
        countif(purchased_within_7d) as n_purchased
    from population

    union all

    select
        'iso_week',
        format_timestamp('%G-W%V', first_begin_checkout_ts),
        count(*),
        countif(purchased_within_7d)
    from population
    group by 2

    union all

    select
        'device_category',
        coalesce(device_category, '(null)'),
        count(*),
        countif(purchased_within_7d)
    from population
    group by 2

),

rates as (

    select
        breakdown,
        segment,
        n_users,
        n_purchased,
        safe_divide(n_purchased, n_users) as p,
        1.959964                          as z
    from grouped

)

select
    breakdown,
    segment,
    n_users,
    n_purchased,
    round(p, 4) as conversion,
    round(
        (p + z * z / (2 * n_users)
           - z * sqrt(p * (1 - p) / n_users + z * z / (4 * n_users * n_users)))
        / (1 + z * z / n_users),
        4
    ) as ci95_low,
    round(
        (p + z * z / (2 * n_users)
           + z * sqrt(p * (1 - p) / n_users + z * z / (4 * n_users * n_users)))
        / (1 + z * z / n_users),
        4
    ) as ci95_high
from rates
order by
    case breakdown when 'overall' then 0 when 'iso_week' then 1 else 2 end,
    segment
