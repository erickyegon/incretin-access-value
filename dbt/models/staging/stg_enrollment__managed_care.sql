-- Medicaid managed care enrollment, yearly summary by state (CMS Managed Care Enrollment Report). One row per state x year.
-- Used for the managed-care share that links total Medicaid Rx to the fee-for-service-only secondary outcome.
select
    state_clean::text as state_name,
    year::int as year,
    total_medicaid_enrollees_n::numeric as total_medicaid_enrollees,
    total_medicaid_enrollment_in_any_type_of_managed_care_n::numeric as enrollment_any_managed_care,
    medicaid_enrollment_in_comprehensive_managed_care_n::numeric as enrollment_comprehensive_managed_care,
    medicaid_newly_eligible_adults_enrolled_in_comprehensive_mcos_n::numeric as newly_eligible_adults_in_comprehensive_mco,
    nullif(notes, '') as notes
from {{ source('raw', 'enrollment_managed_care_summary_yearly') }}
