-- Row count, NULL session_key and duplicate check for stg_ga4__events.
-- Expected n_rows: 4,295,584 (sum of n_events in 01_event_counts.sql).

with dup_groups as (

    select
        user_pseudo_id,
        event_ts,
        event_name,
        count(*) as n
    from {{ ref('stg_ga4__events') }}
    group by user_pseudo_id, event_ts, event_name
    having count(*) > 1

)

select
    (select count(*) from {{ ref('stg_ga4__events') }})                           as n_rows,
    (select countif(session_key is null) from {{ ref('stg_ga4__events') }})       as n_null_session_key,
    (select count(*) from dup_groups)                                             as n_duplicate_groups,
    (select coalesce(sum(n - 1), 0) from dup_groups)                              as n_duplicate_extra_rows
