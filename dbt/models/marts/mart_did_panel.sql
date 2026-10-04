-- Difference-in-differences panel: one row per state (50 states + DC) and quarter, 2018Q1 to 2026Q1: exactly 51 x 33 = 1,683 rows.
-- Outcomes are prescriptions per 1,000 enrollees in LEVELS (no logs, no imputation). Each rate has a named denominator:
--   _per_1000_medicaid       total Medicaid enrollment (item 8a), the primary denominator (SDUD counts Medicaid prescriptions)
--   _per_1000_medicaid_chip  Medicaid + CHIP enrollment (8a + 8h), sensitivity
--   _per_1000_adult_medicaid adult Medicaid enrollment (8d + 8g), sensitivity; sparsely reported, see n_months_present_adult_medicaid
--   _ffs_per_1000_ffs_medicaid  fee-for-service-only secondary outcome: FFSU prescriptions per 1,000 FFS enrollees, where
--                            FFS enrollees = Medicaid enrollment x (1 - comprehensive managed care share); the share for 2025 and 2026 is the
--                            2024 share carried forward (an assumption: mc_share_carried_forward)
-- Prescriptions are all utilization types (FFSU + MCOU) unless _ffs_. rx_*_observed excludes suppressed rows (CMS suppresses 1 to 10
-- prescriptions) and rx_*_upper_bound adds 10 per suppressed row; a state-quarter with no SDUD row has 0 observed and n_rows = 0.
-- sdud_reported_ffsu / sdud_reported_mcou are false when the state has no SDUD row for any drug that quarter and type (then a zero is not a real zero);
-- sdud_anomalous is true when the all-drug count is under 50% of the state's neighbouring-quarter median. Combination products are excluded. Territories are not in the panel.
{% set groups = ['obesity_wz', 'obesity_saxenda', 'obesity_other', 'diabetes_glp1'] %}
with grid as (
    select s.state_code, s.state_name, s.census_region, s.census_division, q.year, q.quarter, q.quarter_label, q.quarter_start, q.is_preliminary
    from {{ ref('states') }} s cross join {{ ref('quarters') }} q
    where s.in_panel
),
sdud as (
    select
        state_code, year, quarter,
{% for g in groups %}
        coalesce(sum(rx_observed) filter (where product_group = '{{ g }}' and utilization_type = 'ALL'), 0) as rx_{{ g }}_observed,
        coalesce(sum(rx_upper_bound) filter (where product_group = '{{ g }}' and utilization_type = 'ALL'), 0) as rx_{{ g }}_upper_bound,
        coalesce(sum(n_suppressed_rows) filter (where product_group = '{{ g }}' and utilization_type = 'ALL'), 0) as n_suppressed_rows_{{ g }},
        coalesce(sum(n_rows) filter (where product_group = '{{ g }}' and utilization_type = 'ALL'), 0) as n_rows_{{ g }},
        coalesce(sum(rx_observed) filter (where product_group = '{{ g }}' and utilization_type = 'FFSU'), 0) as rx_{{ g }}_ffs_observed,
{% endfor %}
        coalesce(sum(rx_observed) filter (where product_group = 'obesity_wz' and dosage_form_group = 'tablet' and utilization_type = 'ALL'), 0) as rx_obesity_wz_tablet_observed
    from {{ ref('int_sdud__state_quarter_group') }}
    group by 1, 2, 3
)
select
    g.state_code, g.state_name, g.census_region, g.census_division,
    g.year, g.quarter, g.quarter_label, g.quarter_start, g.is_preliminary,
    -- coverage
    c.analysis_group, c.has_coverage_spell, c.covered_days_share, c.covered_days_share_max, c.coverage_active, c.coverage_full_quarter,
    c.first_treated_quarter, c.first_full_quarter, c.start_quarter_earliest, c.start_quarter_latest, c.start_precision,
    c.post_withdrawal, c.kansas_flag, c.category_level_spa,
    -- denominators
    e.enrollment_medicaid_avg, e.n_months_present_medicaid,
    e.enrollment_medicaid_chip_avg, e.n_months_present_medicaid_chip,
    e.enrollment_adult_medicaid_avg, e.n_months_present_adult_medicaid,
    e.n_months_updated, e.n_months_preliminary,
    case when e.n_months_updated >= e.n_months_preliminary and e.n_months_updated > 0 then 'updated'
         when e.n_months_preliminary > 0 then 'preliminary' else 'missing' end as report_status_used,
    e.definition_caveat, e.n_months_definition_caveat, e.definition_caveat_medicaid_chip, e.definition_caveat_adult,
    e.data_unavailable_note, e.enrollment_zero_set_null,
    mc.share_comprehensive_managed_care as mc_share, coalesce(mc.is_carried_forward, false) as mc_share_carried_forward,
    e.enrollment_medicaid_avg * (1 - mc.share_comprehensive_managed_care) as enrollment_ffs_medicaid_assumed,
    -- SDUD reporting completeness (all drugs; see int_sdud__reporting): a flagged state-quarter is not dropped or changed
    rp.sdud_reported_ffsu, rp.sdud_reported_mcou, rp.sdud_anomalous, rp.rx_all_drugs_observed,
    -- prescriptions and rates
    coalesce(s.rx_obesity_wz_tablet_observed, 0) as rx_obesity_wz_tablet_observed,
{% for gp in groups %}
    coalesce(s.rx_{{ gp }}_observed, 0) as rx_{{ gp }}_observed,
    coalesce(s.rx_{{ gp }}_upper_bound, 0) as rx_{{ gp }}_upper_bound,
    coalesce(s.n_suppressed_rows_{{ gp }}, 0)::int as n_suppressed_rows_{{ gp }},
    coalesce(s.n_rows_{{ gp }}, 0)::int as n_rows_{{ gp }},
    1000 * coalesce(s.rx_{{ gp }}_observed, 0) / nullif(e.enrollment_medicaid_avg, 0) as rate_{{ gp }}_per_1000_medicaid,
    1000 * coalesce(s.rx_{{ gp }}_upper_bound, 0) / nullif(e.enrollment_medicaid_avg, 0) as rate_{{ gp }}_upper_bound_per_1000_medicaid,
    1000 * coalesce(s.rx_{{ gp }}_observed, 0) / nullif(e.enrollment_medicaid_chip_avg, 0) as rate_{{ gp }}_per_1000_medicaid_chip,
    1000 * coalesce(s.rx_{{ gp }}_observed, 0) / nullif(e.enrollment_adult_medicaid_avg, 0) as rate_{{ gp }}_per_1000_adult_medicaid,
    1000 * coalesce(s.rx_{{ gp }}_ffs_observed, 0) / nullif(e.enrollment_medicaid_avg * (1 - mc.share_comprehensive_managed_care), 0) as rate_{{ gp }}_ffs_per_1000_ffs_medicaid{% if not loop.last %},{% endif %}

{% endfor %}
from grid g
left join {{ ref('int_coverage__state_quarter') }} c on c.state_code = g.state_code and c.year = g.year and c.quarter = g.quarter
left join {{ ref('int_enrollment__state_quarter') }} e on e.state_code = g.state_code and e.year = g.year and e.quarter = g.quarter
left join {{ ref('int_enrollment__managed_care_share') }} mc on mc.state_code = g.state_code and mc.year = g.year
left join (
    select state_code, year, quarter,
        bool_or(not not_reported) filter (where utilization_type = 'FFSU') as sdud_reported_ffsu,
        bool_or(not not_reported) filter (where utilization_type = 'MCOU') as sdud_reported_mcou,
        bool_or(anomalous) as sdud_anomalous,
        sum(rx_observed_all_drugs) as rx_all_drugs_observed
    from {{ ref('int_sdud__reporting') }} group by 1, 2, 3
) rp on rp.state_code = g.state_code and rp.year = g.year and rp.quarter = g.quarter
left join sdud s on s.state_code = g.state_code and s.year = g.year and s.quarter = g.quarter
