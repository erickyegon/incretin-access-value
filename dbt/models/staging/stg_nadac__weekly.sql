-- National Average Drug Acquisition Cost, weekly price per NDC (incretin NDCs). Grain: ndc11 x effective_date x pharmacy type indicator.
-- Only exact duplicate rows are removed.
{% set years = range(2018, 2027) %}
select distinct * from (
{% for y in years %}
    select
        ndc::text as ndc11,
        ndc_description::text as ndc_description,
        nadac_per_unit::numeric as nadac_per_unit,
        pricing_unit::text as pricing_unit,
        effective_date::date as effective_date,
        classification_for_rate_setting::text as classification_for_rate_setting,
        explanation_code::text as explanation_code,
        pharmacy_type_indicator::text as pharmacy_type_indicator,
        as_of_date::date as as_of_date
    from {{ source('raw', 'nadac_' ~ y) }}
    {% if not loop.last %}union all{% endif %}
{% endfor %}
) u
