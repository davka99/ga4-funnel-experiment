-- Checks on int_exp__enrolled_users (experiment population, real events, no assignment).
-- Expected from plan v1.2: 5,962 enrolled users and 2,761 buyers.
-- rho = Pearson correlation between pre_sessions_14d (CUPED covariate) and purchased_7d (0/1).

with u as (

    select
        pre_sessions_14d,
        cast(purchased_7d as int64) as purchased,
        n_orders_7d,
        revenue_7d
    from {{ ref('int_exp__enrolled_users') }}

)

select
    count(*)                                                     as n_rows,
    sum(purchased)                                               as n_buyers,
    round(avg(purchased), 4)                                     as p_buyers,
    round(countif(pre_sessions_14d = 0) / count(*), 4)           as share_pre_sessions_0,
    countif(pre_sessions_14d = 1)                                as n_pre_sessions_1,
    countif(pre_sessions_14d = 2)                                as n_pre_sessions_2,
    countif(pre_sessions_14d >= 3)                               as n_pre_sessions_3plus,
    round(avg(pre_sessions_14d), 3)                              as mean_pre_sessions_14d,
    (
        select distinct percentile_cont(pre_sessions_14d, 0.5) over ()
        from u
    )                                                            as median_pre_sessions_14d,
    max(pre_sessions_14d)                                        as max_pre_sessions_14d,
    round(corr(pre_sessions_14d, purchased), 4)                  as rho,
    round(pow(corr(pre_sessions_14d, purchased), 2), 4)          as rho_squared,
    countif(purchased = 1 and n_orders_7d = 0)                   as n_buyers_without_valid_order,
    sum(n_orders_7d)                                             as n_valid_orders,
    round(sum(revenue_7d), 2)                                    as total_revenue_7d
from u
