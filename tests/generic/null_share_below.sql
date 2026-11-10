{#
    Fails (returns one row) when the share of NULL values in a column
    is greater than max_share. Use severity: warn for soft checks.
#}
{% test null_share_below(model, column_name, max_share) %}

with stats as (

    select
        count(*)                        as n_rows,
        countif({{ column_name }} is null) as n_null
    from {{ model }}

)

select
    n_rows,
    n_null,
    safe_divide(n_null, n_rows) as null_share
from stats
where safe_divide(n_null, n_rows) > {{ max_share }}

{% endtest %}
