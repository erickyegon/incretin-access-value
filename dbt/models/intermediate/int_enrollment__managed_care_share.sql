-- Share of Medicaid enrollees in comprehensive managed care, by panel state and year, from the CMS Managed Care Enrollment Report.
-- Used only for the secondary fee-for-service-only outcome: FFS enrollment = Medicaid enrollment x (1 - share).
-- Comprehensive managed care is the right measure because those plans (MCOs) pay for pharmacy, which SDUD labels MCOU; limited-benefit
-- plans do not. Report years end in 2024: later years carry the 2024 share forward, an ASSUMPTION flagged in is_carried_forward.
-- Grain: state_code x year (2018 to 2026).
with src as (
    select
        s.state_code,
        m.year,
        m.enrollment_comprehensive_managed_care / nullif(m.total_medicaid_enrollees, 0) as share_comprehensive_managed_care,
        m.total_medicaid_enrollees,
        m.enrollment_comprehensive_managed_care
    from {{ ref('stg_enrollment__managed_care') }} m
    join {{ ref('states') }} s on s.state_name = m.state_name and s.in_panel
),
years as (select generate_series(2018, 2026) as year),
grid as (select s.state_code, y.year from {{ ref('states') }} s cross join years y where s.in_panel),
last_report as (
    select state_code, share_comprehensive_managed_care as share_2024 from src where year = 2024
)
select
    g.state_code,
    g.year,
    coalesce(s.share_comprehensive_managed_care, case when g.year > 2024 then l.share_2024 end) as share_comprehensive_managed_care,
    (g.year > 2024 and l.share_2024 is not null) as is_carried_forward,
    s.total_medicaid_enrollees as report_total_medicaid_enrollees,
    s.enrollment_comprehensive_managed_care as report_enrollment_comprehensive_managed_care
from grid g
left join src s on s.state_code = g.state_code and s.year = g.year
left join last_report l on l.state_code = g.state_code
