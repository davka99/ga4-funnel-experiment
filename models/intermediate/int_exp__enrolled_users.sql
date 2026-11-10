{{ config(materialized='table') }}

-- Experiment population per docs/experiment_plan.md (§3-4, §7.3).
-- One row per user enrolled at their first begin_checkout in 2020-11-16 .. 2020-12-27 (UTC).
-- Real events only: no assignment and no synthetic data.

with events as (

    select
        user_pseudo_id,
        session_key,
        event_name,
        event_ts,
        device_category,
        transaction_id,
        purchase_revenue_usd
    from {{ ref('stg_ga4__events') }}

),

triggers as (

    select
        user_pseudo_id,
        event_ts as trigger_ts,
        device_category
    from events
    where event_name = 'begin_checkout'
      and event_ts >= timestamp('2020-11-16')
      and event_ts <  timestamp('2020-12-28')
    qualify row_number() over (partition by user_pseudo_id order by event_ts) = 1

),

pre_sessions as (

    select
        t.user_pseudo_id,
        count(distinct e.session_key) as pre_sessions_14d
    from triggers as t
    inner join events as e
        on e.user_pseudo_id = t.user_pseudo_id
       and e.event_ts >= timestamp_sub(t.trigger_ts, interval 14 day)
       and e.event_ts <  t.trigger_ts
    group by t.user_pseudo_id

),

purchases_7d as (

    select
        t.user_pseudo_id,
        e.transaction_id,
        e.purchase_revenue_usd
    from triggers as t
    inner join events as e
        on e.user_pseudo_id = t.user_pseudo_id
       and e.event_name = 'purchase'
       and e.event_ts >= t.trigger_ts
       and e.event_ts <  timestamp_add(t.trigger_ts, interval 7 day)

),

valid_orders as (

    -- One row per user and valid transaction_id; duplicates collapse to the highest revenue.
    select
        user_pseudo_id,
        transaction_id,
        max(purchase_revenue_usd) as order_revenue_usd
    from purchases_7d
    where transaction_id is not null
      and transaction_id != '(not set)'
    group by user_pseudo_id, transaction_id

),

outcomes as (

    select
        user_pseudo_id,
        true as purchased_7d
    from purchases_7d
    group by user_pseudo_id

),

orders as (

    select
        user_pseudo_id,
        count(*)               as n_orders_7d,
        sum(order_revenue_usd) as revenue_7d
    from valid_orders
    group by user_pseudo_id

)

select
    t.user_pseudo_id,
    t.trigger_ts,
    t.device_category,
    coalesce(ps.pre_sessions_14d, 0) as pre_sessions_14d,
    coalesce(o.purchased_7d, false)  as purchased_7d,
    coalesce(od.revenue_7d, 0)       as revenue_7d,
    coalesce(od.n_orders_7d, 0)      as n_orders_7d
from triggers as t
left join pre_sessions as ps
    on ps.user_pseudo_id = t.user_pseudo_id
left join outcomes as o
    on o.user_pseudo_id = t.user_pseudo_id
left join orders as od
    on od.user_pseudo_id = t.user_pseudo_id
