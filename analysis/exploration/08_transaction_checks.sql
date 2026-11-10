-- Transaction ID checks on valid purchase events (transaction_id not NULL and not '(not set)').
-- (a) transaction_id that appear for more than one user_pseudo_id
-- (b) duplicated transaction_id (more than one row) whose revenue differs between rows
-- Shown for all purchase events and for the experiment population's 7-day outcome windows.

with valid_purchases as (

    select
        user_pseudo_id,
        event_ts,
        transaction_id,
        purchase_revenue_usd
    from {{ ref('stg_ga4__events') }}
    where event_name = 'purchase'
      and transaction_id is not null
      and transaction_id != '(not set)'

),

in_exp_window as (

    select
        p.user_pseudo_id,
        p.transaction_id,
        p.purchase_revenue_usd
    from valid_purchases as p
    inner join {{ ref('int_exp__enrolled_users') }} as u
        on u.user_pseudo_id = p.user_pseudo_id
       and p.event_ts >= u.trigger_ts
       and p.event_ts <  timestamp_add(u.trigger_ts, interval 7 day)

),

per_id as (

    select
        'all purchase events'              as scope,
        transaction_id,
        count(*)                           as n_rows,
        count(distinct user_pseudo_id)     as n_users,
        count(distinct purchase_revenue_usd) as n_revenue_values
    from valid_purchases
    group by transaction_id

    union all

    select
        'experiment 7-day windows',
        transaction_id,
        count(*),
        count(distinct user_pseudo_id),
        count(distinct purchase_revenue_usd)
    from in_exp_window
    group by transaction_id

)

select
    scope,
    count(*)                                         as n_valid_transaction_ids,
    countif(n_users > 1)                             as a_ids_with_multiple_users,
    countif(n_rows > 1)                              as n_duplicated_ids,
    countif(n_rows > 1 and n_revenue_values > 1)     as b_duplicated_ids_with_differing_revenue
from per_id
group by scope
order by scope
