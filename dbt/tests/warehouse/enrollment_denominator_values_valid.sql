-- denominators are positive when present; Medicaid + CHIP is never below Medicaid-only; months present stay within 0..3; zeros are NULL
select state_code, month_start::text as period, 'non-positive enrollment' as problem from {{ ref('int_enrollment__state_month') }}
where total_medicaid_enrollment <= 0 or total_medicaid_and_chip_enrollment <= 0 or total_adult_medicaid_enrollment <= 0
union all
select state_code, month_start::text, 'medicaid+chip below medicaid' from {{ ref('int_enrollment__state_month') }}
where total_medicaid_and_chip_enrollment < total_medicaid_enrollment
union all
select state_code, quarter_label, 'months present out of range' from {{ ref('int_enrollment__state_quarter') }}
where n_months_present_medicaid not between 0 and 3 or n_months_present_adult_medicaid not between 0 and 3
