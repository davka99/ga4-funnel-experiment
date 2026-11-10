{#
    Wilson score interval bound for a binomial proportion x / n.
    direction: 'lower' or 'upper'. z defaults to 1.959964 (95%).
#}
{% macro wilson_bound(x, n, direction, z=1.959964) %}
(
    (
        safe_divide({{ x }}, {{ n }}) + {{ z }} * {{ z }} / (2 * {{ n }})
        {{ '-' if direction == 'lower' else '+' }} {{ z }} * sqrt(
            safe_divide({{ x }}, {{ n }}) * (1 - safe_divide({{ x }}, {{ n }})) / {{ n }}
            + {{ z }} * {{ z }} / (4 * {{ n }} * {{ n }})
        )
    )
    / (1 + {{ z }} * {{ z }} / {{ n }})
)
{% endmacro %}
