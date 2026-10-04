-- The suppressed SDUD cells that a later imputation step must fill, with the facts that bound or inform each one. NOTHING is imputed here.
-- Grain: one row per suppressed state-NDC-quarter-utilization-type row of the panel states (state_code x ndc11 x year x quarter x utilization_type).
-- The prescription count is unknown (NULL); CMS suppresses 1 to 10 prescriptions, and 0 to 10 are treated as possible (rx_lower_bound = 0,
-- rx_upper_bound = 10). national_* come from the XX national row for the same NDC, quarter and utilization type: residual_rx (national minus
-- observed state prescriptions) is the volume held in all suppressed state rows of that NDC-quarter, usable when residual_usable is true.
select
    s.state_code, s.ndc11, s.year, s.quarter, q.quarter_label, s.quarter_start, s.is_preliminary, s.utilization_type,
    g.brand_label, g.product_group, g.dosage_form_group as dosage_form,
    s.number_of_prescriptions as rx_observed,
    0 as rx_lower_bound,
    10 as rx_upper_bound,
    n.has_national_row, n.national_suppressed, n.national_rx, n.state_rx_observed as national_state_rx_observed,
    n.n_state_suppressed as n_suppressed_rows_same_ndc_quarter, n.residual_rx, n.residual_usable, n.residual_within_bounds,
    e.enrollment_medicaid_avg, e.n_months_present_medicaid,
    c.analysis_group, c.coverage_active, c.covered_days_share
from {{ ref('stg_sdud__state') }} s
join {{ ref('states') }} st on st.state_code = s.state_code and st.in_panel
join {{ ref('int_sdud__ndc_group') }} g on g.ndc11 = s.ndc11
join {{ ref('quarters') }} q on q.year = s.year and q.quarter = s.quarter
left join {{ ref('int_sdud__national_residual') }} n
    on n.ndc11 = s.ndc11 and n.year = s.year and n.quarter = s.quarter and n.utilization_type = s.utilization_type
left join {{ ref('int_enrollment__state_quarter') }} e on e.state_code = s.state_code and e.year = s.year and e.quarter = s.quarter
left join {{ ref('int_coverage__state_quarter') }} c on c.state_code = s.state_code and c.year = s.year and c.quarter = s.quarter
where s.suppressed and g.product_group <> 'combination_excluded'
