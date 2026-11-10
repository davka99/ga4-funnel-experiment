-- SYNTHETIC/SIMULATED DATA. The dataset contains no real experiment.
-- Scenario S1 (docs/experiment_plan.md §6): true effect +4.0 pp on exp_checkout_conversion_7d.
-- Treatment users without a real purchase get a simulated purchase when u < q,
-- with q = 0.04 / (1 - p_ctrl) and p_ctrl = share of buyers in control (real data).
-- A simulated purchase gets n_orders_7d = 1 and the revenue of one real valid order,
-- chosen deterministically from the pool of valid orders in the population's 7-day windows.

{{ config(materialized='table') }}

with users as (

    select
        u.user_pseudo_id,
        a.variant,
        u.pre_sessions_14d,
        u.purchased_7d,
        u.revenue_7d,
        u.n_orders_7d
    from {{ ref('int_exp__enrolled_users') }} as u
    inner join {{ ref('synthetic_exp__assignment') }} as a
        on a.user_pseudo_id = u.user_pseudo_id

),

params as (

    select
        0.04 / (1 - avg(if(purchased_7d, 1, 0))) as q
    from users
    where variant = 'control'

),

valid_orders as (

    -- Real valid orders in the enrolled users' 7-day outcome windows, one row per user and
    -- transaction_id (highest revenue per duplicated ID), as in int_exp__enrolled_users.
    select
        p.user_pseudo_id,
        p.transaction_id,
        max(p.purchase_revenue_usd) as order_revenue_usd
    from {{ ref('stg_ga4__events') }} as p
    inner join {{ ref('int_exp__enrolled_users') }} as u
        on u.user_pseudo_id = p.user_pseudo_id
       and p.event_ts >= u.trigger_ts
       and p.event_ts <  timestamp_add(u.trigger_ts, interval 7 day)
    where p.event_name = 'purchase'
      and p.transaction_id is not null
      and p.transaction_id != '(not set)'
    group by p.user_pseudo_id, p.transaction_id

),

order_pool as (

    select
        row_number() over (order by user_pseudo_id, transaction_id) - 1 as order_idx,
        order_revenue_usd
    from valid_orders

),

draws as (

    select
        users.*,
        abs(mod(farm_fingerprint(concat('s1-effect:', user_pseudo_id)), 1000000)) / 1e6 as u,
        abs(mod(farm_fingerprint(concat('s1-rev:', user_pseudo_id)), (select count(*) from order_pool))) as order_idx
    from users

),

flagged as (

    select
        d.*,
        d.variant = 'treatment'
            and not d.purchased_7d
            and d.u < (select q from params) as is_synthetic_purchase
    from draws as d

)

select
    f.user_pseudo_id,
    f.variant,
    f.pre_sessions_14d,
    f.purchased_7d or f.is_synthetic_purchase                  as purchased_7d,
    if(f.is_synthetic_purchase, op.order_revenue_usd, f.revenue_7d) as revenue_7d,
    if(f.is_synthetic_purchase, 1, f.n_orders_7d)               as n_orders_7d,
    f.is_synthetic_purchase
from flagged as f
left join order_pool as op
    on op.order_idx = f.order_idx
