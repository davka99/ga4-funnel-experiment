{#
    Fails for every row where the boolean `expression` is not true.
#}
{% test expression_is_true(model, expression) %}

select
    *
from {{ model }}
where not coalesce({{ expression }}, false)

{% endtest %}
