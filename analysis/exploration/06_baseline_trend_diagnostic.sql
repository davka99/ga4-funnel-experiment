-- Diagnostic for the weekly trend in checkout_conversion_7d.
-- Grain: user x ISO week (UTC) for users with >= 1 begin_checkout that week.
-- Anchor: the user's first begin_checkout that week. Outcome: any purchase in [anchor, anchor + 7 days).
-- Excluded: anchors in 2020-W44 (only 2020-11-01) and anchors on/after 2021-01-25 UTC (window does not fit).
-- returning = the user had a begin_checkout in an earlier ISO week (2020-W44 counts as history); new = otherwise.
-- Output rows per week: segment 'all' (A), 'new' / 'returning' (B); share_of_week on 'new' rows answers C.
-- Note: a user can appear in several weeks, and one purchase can count for two anchors less than 7 days apart.

with checkouts as (

    select
        user_pseudo_id,
        event_ts,
        format_timestamp('%G-W%V', event_ts) as iso_week
    from {{ ref('stg_ga4__events') }}
    where event_name = 'begin_checkout'

),

anchors as (

    select
        user_pseudo_id,
        iso_week,
        min(event_ts) as anchor_ts
    from checkouts
    group by user_pseudo_id, iso_week

),

first_week as (

    -- '%G-W%V' strings are zero-padded, so they sort chronologically.
    select
        user_pseudo_id,
        min(iso_week) as first_checkout_week
    from anchors
    group by user_pseudo_id

),

purchases as (

    select
        user_pseudo_id,
        event_ts
    from {{ ref('stg_ga4__events') }}
    where event_name = 'purchase'

),

user_weeks as (

    select
        a.user_pseudo_id,
        a.iso_week,
        a.iso_week > fw.first_checkout_week as is_returning,
        coalesce(
            logical_or(
                p.event_ts >= a.anchor_ts
                and p.event_ts < timestamp_add(a.anchor_ts, interval 7 day)
            ),
            false
        ) as purchased_within_7d
    from anchors as a
    inner join first_week as fw
        on fw.user_pseudo_id = a.user_pseudo_id
    left join purchases as p
        on p.user_pseudo_id = a.user_pseudo_id
    where a.iso_week != '2020-W44'
      and a.anchor_ts < timestamp('2021-01-25')
    group by a.user_pseudo_id, a.iso_week, is_returning

),

grouped as (

    select
        iso_week,
        'all'                        as segment,
        count(*)                     as n_users,
        countif(purchased_within_7d) as n_purchased
    from user_weeks
    group by iso_week

    union all

    select
        iso_week,
        if(is_returning, 'returning', 'new'),
        count(*),
        countif(purchased_within_7d)
    from user_weeks
    group by iso_week, 2

)

select
    iso_week,
    segment,
    n_users,
    round(safe_divide(n_users, sum(if(segment = 'all', n_users, 0)) over (partition by iso_week)), 4) as share_of_week,
    n_purchased,
    round(safe_divide(n_purchased, n_users), 4)                         as conversion,
    round({{ wilson_bound('n_purchased', 'n_users', 'lower') }}, 4)    as ci95_low,
    round({{ wilson_bound('n_purchased', 'n_users', 'upper') }}, 4)    as ci95_high
from grouped
order by
    iso_week,
    case segment when 'all' then 0 when 'new' then 1 else 2 end
