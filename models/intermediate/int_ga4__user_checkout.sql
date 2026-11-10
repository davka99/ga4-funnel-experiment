{{ config(materialized='table') }}

-- One row per user_pseudo_id with at least one begin_checkout event.
-- Anchored on the user's first begin_checkout. All timestamps are UTC.

with events as (

    select
        user_pseudo_id,
        session_key,
        event_name,
        event_ts,
        device_category
    from {{ ref('stg_ga4__events') }}

),

first_checkout as (

    select
        user_pseudo_id,
        session_key     as checkout_session_key,
        event_ts        as first_begin_checkout_ts,
        device_category
    from events
    where event_name = 'begin_checkout'
    qualify row_number() over (partition by user_pseudo_id order by event_ts) = 1

),

session_starts as (

    select
        user_pseudo_id,
        session_key,
        min(event_ts) as session_start_ts
    from events
    where session_key is not null
    group by user_pseudo_id, session_key

),

sessions_before as (

    -- Observed sessions that started before the session containing the first begin_checkout.
    select
        fc.user_pseudo_id,
        countif(s.session_start_ts < cs.session_start_ts) as n_sessions_before_checkout
    from first_checkout as fc
    left join session_starts as cs
        on cs.session_key = fc.checkout_session_key
    left join session_starts as s
        on s.user_pseudo_id = fc.user_pseudo_id
    group by fc.user_pseudo_id

),

purchases as (

    select
        fc.user_pseudo_id,
        logical_or(
            e.event_ts >= fc.first_begin_checkout_ts
            and e.event_ts < timestamp_add(fc.first_begin_checkout_ts, interval 7 day)
        ) as purchased_within_7d
    from first_checkout as fc
    inner join events as e
        on e.user_pseudo_id = fc.user_pseudo_id
       and e.event_name = 'purchase'
    group by fc.user_pseudo_id

)

select
    fc.user_pseudo_id,
    fc.first_begin_checkout_ts,
    -- 7-day window fits inside the data (ends 2021-01-31) only for checkouts before this cutoff.
    fc.first_begin_checkout_ts < timestamp('2021-01-25')   as has_full_window,
    coalesce(p.purchased_within_7d, false)                 as purchased_within_7d,
    fc.device_category,
    sb.n_sessions_before_checkout
from first_checkout as fc
left join purchases as p
    on p.user_pseudo_id = fc.user_pseudo_id
left join sessions_before as sb
    on sb.user_pseudo_id = fc.user_pseudo_id
