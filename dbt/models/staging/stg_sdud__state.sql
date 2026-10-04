-- State Drug Utilization Data, state rows only (national XX rows are in stg_sdud__national).
-- Grain: state_code x utilization_type x ndc11 x year x quarter. Gross of rebates. Counts below 11 are suppressed by CMS: they are NULL here
-- and suppressed = true. Only exact duplicate rows are removed (select distinct).
{% set years = range(2018, 2027) %}
with unioned as (
{% for y in years %}
    select
        utilization_type::text as utilization_type,
        state::text as state_code,
        ndc::text as ndc11,
        year::int as year,
        quarter::int as quarter,
        suppression_used::boolean as suppressed,
        product_name::text as product_name,
        units_reimbursed::numeric as units_reimbursed,
        number_of_prescriptions::numeric as number_of_prescriptions,
        total_amount_reimbursed::numeric as total_amount_reimbursed,
        medicaid_amount_reimbursed::numeric as medicaid_amount_reimbursed,
        non_medicaid_amount_reimbursed::numeric as non_medicaid_amount_reimbursed
    from {{ source('raw', 'sdud_state_' ~ y) }}
    {% if not loop.last %}union all{% endif %}
{% endfor %}
)
select distinct
    state_code, utilization_type, ndc11, year, quarter,
    make_date(year, (quarter - 1) * 3 + 1, 1) as quarter_start,
    suppressed, product_name,
    units_reimbursed, number_of_prescriptions, total_amount_reimbursed, medicaid_amount_reimbursed, non_medicaid_amount_reimbursed,
    make_date(year, (quarter - 1) * 3 + 1, 1) >= '{{ var("preliminary_from_quarter_start") }}'::date as is_preliminary
from unioned
where state_code <> 'XX'
