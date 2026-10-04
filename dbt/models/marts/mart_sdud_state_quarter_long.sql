-- SDUD in long form for the panel states: one row per state x quarter x utilization type x product group x dosage form group.
-- utilization_type is FFSU, MCOU or ALL (ALL = FFSU + MCOU: filter to one or the other before summing). dosage_form_group (tablet, injection,
-- unknown) separates Wegovy tablets from Wegovy injection within the obesity_wz exposure group. Observed counts exclude suppressed rows; the
-- upper bound adds 10 prescriptions per suppressed row. No imputation. Combination products and territories are excluded.
select
    s.state_code, st.state_name, st.census_region,
    s.year, s.quarter, q.quarter_label, s.quarter_start, s.is_preliminary,
    s.utilization_type, s.product_group, s.dosage_form_group as dosage_form,
    s.n_rows, s.n_suppressed_rows,
    s.rx_observed, s.rx_upper_bound,
    s.units_observed, s.units_upper_bound, s.units_bound_complete,
    s.amount_total_observed, s.amount_total_upper_bound,
    s.amount_medicaid_observed, s.amount_medicaid_upper_bound
from {{ ref('int_sdud__state_quarter_group') }} s
join {{ ref('states') }} st on st.state_code = s.state_code
join {{ ref('quarters') }} q on q.year = s.year and q.quarter = s.quarter
