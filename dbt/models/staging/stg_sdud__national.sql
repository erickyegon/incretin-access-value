-- State Drug Utilization Data, national rows (state = XX). Kept apart from state rows so that national totals are never summed with states.
-- Grain: utilization_type x ndc11 x year x quarter. Counts below 11 are suppressed (NULL, suppressed = true).
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
    from {{ source('raw', 'sdud_national_' ~ y) }}
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
where state_code = 'XX'
