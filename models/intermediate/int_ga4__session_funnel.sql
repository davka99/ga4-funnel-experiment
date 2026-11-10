{{ config(
    materialized='table',
    cluster_by=['session_start_date']
) }}

-- One row per session_key with the first timestamp of each funnel step and
-- ordered reached_<step> flags. A step counts as reached only if every earlier
-- step was reached and each step's first timestamp is >= the previous step's.

with events as (

    select
        session_key,
        user_pseudo_id,
        event_date,
        event_ts,
        event_name
    from {{ ref('stg_ga4__events') }}
    where session_key is not null

),

sessions as (

    select
        session_key,
        any_value(user_pseudo_id)                                as user_pseudo_id,
        min(event_date)                                          as session_start_date,
        min(if(event_name = 'view_item',        event_ts, null)) as first_view_item_ts,
        min(if(event_name = 'add_to_cart',      event_ts, null)) as first_add_to_cart_ts,
        min(if(event_name = 'begin_checkout',   event_ts, null)) as first_begin_checkout_ts,
        min(if(event_name = 'add_payment_info', event_ts, null)) as first_add_payment_info_ts,
        min(if(event_name = 'purchase',         event_ts, null)) as first_purchase_ts
    from events
    group by session_key

)

select
    session_key,
    user_pseudo_id,
    session_start_date,
    first_view_item_ts,
    first_add_to_cart_ts,
    first_begin_checkout_ts,
    first_add_payment_info_ts,
    first_purchase_ts,

    first_view_item_ts is not null as reached_view_item,

    coalesce(
        first_add_to_cart_ts      >= first_view_item_ts,
        false
    ) as reached_add_to_cart,

    coalesce(
        first_add_to_cart_ts      >= first_view_item_ts
        and first_begin_checkout_ts   >= first_add_to_cart_ts,
        false
    ) as reached_begin_checkout,

    coalesce(
        first_add_to_cart_ts      >= first_view_item_ts
        and first_begin_checkout_ts   >= first_add_to_cart_ts
        and first_add_payment_info_ts >= first_begin_checkout_ts,
        false
    ) as reached_add_payment_info,

    coalesce(
        first_add_to_cart_ts      >= first_view_item_ts
        and first_begin_checkout_ts   >= first_add_to_cart_ts
        and first_add_payment_info_ts >= first_begin_checkout_ts
        and first_purchase_ts         >= first_add_payment_info_ts,
        false
    ) as reached_purchase

from sessions
