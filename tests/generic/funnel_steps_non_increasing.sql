{#
    Fails when the number of rows where a step flag is true is greater than
    the number for the previous step. `steps` is an ordered list of boolean
    columns, e.g. [reached_view_item, reached_add_to_cart, ...].
    Returns one row per violating step.
#}
{% test funnel_steps_non_increasing(model, steps) %}

with counts as (

    select
        {% for step in steps %}
        countif({{ step }}) as n_{{ loop.index0 }}{{ "," if not loop.last }}
        {% endfor %}
    from {{ model }}

),

step_pairs as (

    {% for step in steps[1:] %}
    select
        '{{ steps[loop.index0] }}' as previous_step,
        n_{{ loop.index0 }}         as previous_n,
        '{{ step }}'                as step,
        n_{{ loop.index }}          as n
    from counts
    {{ "union all" if not loop.last }}
    {% endfor %}

)

select
    previous_step,
    previous_n,
    step,
    n
from step_pairs
where n > previous_n

{% endtest %}
