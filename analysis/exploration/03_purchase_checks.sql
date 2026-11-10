-- Checks on purchase events in stg_ga4__events:
-- NULL / '(not set)' transaction_id, repeated transaction_id and revenue distribution.
-- '(not set)' is excluded from the repeated-ID count because it is a placeholder, not an ID.

with purchases as (

    select
        transaction_id,
        purchase_revenue_usd
    from {{ ref('stg_ga4__events') }}
    where event_name = 'purchase'

),

repeated_ids as (

    select
        transaction_id,
        count(*) as n
    from purchases
    where transaction_id is not null
      and transaction_id != '(not set)'
    group by transaction_id
    having count(*) > 1

)

select
    count(*)                                                        as n_purchase_events,
    countif(transaction_id is null)                                 as n_null_transaction_id,
    round(safe_divide(countif(transaction_id is null), count(*)), 4) as share_null_transaction_id,
    countif(transaction_id = '(not set)')                           as n_not_set_transaction_id,
    (select count(*) from repeated_ids)                             as n_repeated_transaction_ids,
    (select coalesce(sum(n), 0) from repeated_ids)                  as n_events_with_repeated_id,
    countif(purchase_revenue_usd is null)                           as n_null_revenue,
    min(purchase_revenue_usd)                                       as min_revenue_usd,
    (
        select distinct percentile_cont(purchase_revenue_usd, 0.5) over ()
        from purchases
    )                                                               as median_revenue_usd,
    max(purchase_revenue_usd)                                       as max_revenue_usd
from purchases
