{#
    Fails when the model does not have exactly `expected` rows.
#}
{% test row_count_equals(model, expected) %}

select
    count(*) as n_rows
from {{ model }}
having count(*) != {{ expected }}

{% endtest %}
