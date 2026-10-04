-- Medicaid and CHIP monthly enrollment (CMS Performance Indicator dataset), one row per state x month x report status.
-- Each state-month can appear twice: a Preliminary report (P / final_report N) and an Updated report (U / final_report Y); both are kept
-- and report_status says which. Fields (data dictionary): total_medicaid_and_chip_enrollment = items 8a + 8h (Medicaid or CHIP);
-- total_medicaid_enrollment = item 8a (Medicaid only); total_chip_enrollment = 8h. All are point-in-time counts of people eligible for
-- comprehensive benefits. A reported zero is a non-report (Rhode Island): it is NULL in every count column and enrollment_zero_set_null is true. Footnote text is kept; it is mostly a definition caveat.
select
    state_abbreviation::text as state_code,
    state_name::text as state_name,
    month::date as month_start,
    reporting_period::text as reporting_period,
    state_expanded_medicaid::text as state_expanded_medicaid,
    case preliminary_or_updated when 'P' then 'preliminary' when 'U' then 'updated' end as report_status,
    (final_report = 'Y') as is_final_report,
    nullif(total_medicaid_and_chip_enrollment, 0)::numeric as total_medicaid_and_chip_enrollment,
    nullif(total_medicaid_enrollment, 0)::numeric as total_medicaid_enrollment,
    nullif(total_chip_enrollment, 0)::numeric as total_chip_enrollment,
    nullif(total_adult_medicaid_enrollment, 0)::numeric as total_adult_medicaid_enrollment,
    nullif(medicaid_and_chip_child_enrollment, 0)::numeric as medicaid_and_chip_child_enrollment,
    nullif(total_medicaid_and_chip_enrollment_footnotes, '') as total_medicaid_and_chip_enrollment_footnote,
    nullif(total_medicaid_enrollment_footnotes, '') as total_medicaid_enrollment_footnote,
    nullif(total_chip_enrollment_footnotes, '') as total_chip_enrollment_footnote,
    nullif(total_adult_medicaid_enrollment_footnotes, '') as total_adult_medicaid_enrollment_footnote,
    (coalesce(enrollment_zero_set_null, false) or 0 in (total_medicaid_and_chip_enrollment, total_medicaid_enrollment, total_chip_enrollment,
        total_adult_medicaid_enrollment, medicaid_and_chip_child_enrollment)) as enrollment_zero_set_null
from {{ source('raw', 'enrollment_medicaid_chip_monthly') }}
