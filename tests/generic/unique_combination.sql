{#
    Fails when any combination of the given columns occurs more than once.
    Returns one row per duplicated combination with its row count.
#}
{% test unique_combination(model, columns) %}

select
    {{ columns | join(', ') }},
    count(*) as n_rows
from {{ model }}
group by {{ columns | join(', ') }}
having count(*) > 1

{% endtest %}
