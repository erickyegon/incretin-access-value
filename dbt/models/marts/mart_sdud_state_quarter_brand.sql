-- SDUD obesity-labelled products by brand, for the panel states: one row per state x quarter x brand x dosage form (FFSU + MCOU summed).
-- It exists so the payer-specific brand split (Wegovy versus Zepbound, tablet versus injection) can be read for states that cover the drugs
-- (coverage_active) without going to staging. Observed counts exclude suppressed rows (1 to 10 prescriptions each); rx_upper_bound adds 10 per
-- suppressed row. Combination products are excluded; territories are not in the panel states.
select
    s.state_code, s.year, s.quarter, q.quarter_label, s.quarter_start, s.is_preliminary,
    g.brand_label, g.product_group, g.dosage_form_group as dosage_form,
    c.coverage_active, c.analysis_group,
    count(*) as n_rows,
    count(*) filter (where s.suppressed) as n_suppressed_rows,
    coalesce(sum(s.number_of_prescriptions), 0) as rx_observed,
    coalesce(sum(s.number_of_prescriptions), 0) + 10 * count(*) filter (where s.suppressed) as rx_upper_bound,
    coalesce(sum(s.total_amount_reimbursed), 0) as amount_total_observed,
    coalesce(sum(s.medicaid_amount_reimbursed), 0) as amount_medicaid_observed
from {{ ref('stg_sdud__state') }} s
join {{ ref('int_sdud__ndc_group') }} g on g.ndc11 = s.ndc11
join {{ ref('states') }} st on st.state_code = s.state_code and st.in_panel
join {{ ref('quarters') }} q on q.year = s.year and q.quarter = s.quarter
left join {{ ref('int_coverage__state_quarter') }} c on c.state_code = s.state_code and c.year = s.year and c.quarter = s.quarter
where g.product_group in ('obesity_wz', 'obesity_saxenda', 'obesity_other')
group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
