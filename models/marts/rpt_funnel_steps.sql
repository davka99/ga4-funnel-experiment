{{ config(materialized='table') }}

-- Reporting table: sessions per funnel step and step conversion (real data).
-- Same logic as analysis/exploration/04_session_funnel_steps.sql.

with counts as (

    select
        count(*)                                       as n_all,
        countif(reached_view_item)                     as n_view_item,
        countif(reached_add_to_cart)                   as n_add_to_cart,
        countif(reached_begin_checkout)                as n_begin_checkout,
        countif(reached_add_payment_info)              as n_add_payment_info,
        countif(reached_purchase)                      as n_purchase,
        countif(first_view_item_ts is not null)        as any_view_item,
        countif(first_add_to_cart_ts is not null)      as any_add_to_cart,
        countif(first_begin_checkout_ts is not null)   as any_begin_checkout,
        countif(first_add_payment_info_ts is not null) as any_add_payment_info,
        countif(first_purchase_ts is not null)         as any_purchase
    from {{ ref('int_ga4__session_funnel') }}

),

steps as (

    select 0 as step_order, 'all sessions'     as step_name, n_all              as sessions_ordered, n_all                as sessions_any_order from counts
    union all
    select 1,               'view_item',                     n_view_item,                           any_view_item                             from counts
    union all
    select 2,               'add_to_cart',                   n_add_to_cart,                         any_add_to_cart                           from counts
    union all
    select 3,               'begin_checkout',                n_begin_checkout,                      any_begin_checkout                        from counts
    union all
    select 4,               'add_payment_info',              n_add_payment_info,                    any_add_payment_info                      from counts
    union all
    select 5,               'purchase',                      n_purchase,                            any_purchase                              from counts

)

select
    step_order,
    step_name,
    sessions_ordered,
    sessions_any_order,
    safe_divide(sessions_ordered, lag(sessions_ordered) over (order by step_order))         as conv_from_previous,
    safe_divide(sessions_ordered, first_value(sessions_ordered) over (order by step_order)) as conv_from_all
from steps
