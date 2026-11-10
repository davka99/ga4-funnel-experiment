{{ config(materialized='table') }}

with events as (

    select
        parse_date('%Y%m%d', event_date)                                                      as event_date,
        timestamp_micros(event_timestamp)                                                     as event_ts,
        event_name,
        user_pseudo_id,
        (select ep.value.int_value from unnest(event_params) as ep where ep.key = 'ga_session_id')     as ga_session_id,
        (select ep.value.int_value from unnest(event_params) as ep where ep.key = 'ga_session_number') as ga_session_number,
        (select ep.value.string_value from unnest(event_params) as ep where ep.key = 'page_location')  as page_location,
        device.category                                                                       as device_category,
        geo.country                                                                           as country,
        traffic_source.medium                                                                 as traffic_medium,
        traffic_source.source                                                                 as traffic_source,
        ecommerce.transaction_id                                                              as transaction_id,
        ecommerce.purchase_revenue_in_usd                                                     as purchase_revenue_usd
    from {{ source('ga4', 'events') }}
    where _table_suffix between '20201101' and '20210131'

)

select
    event_date,
    event_ts,
    event_name,
    user_pseudo_id,
    ga_session_id,
    ga_session_number,
    concat(user_pseudo_id, '-', cast(ga_session_id as string)) as session_key,
    page_location,
    device_category,
    country,
    traffic_medium,
    traffic_source,
    transaction_id,
    purchase_revenue_usd
from events
