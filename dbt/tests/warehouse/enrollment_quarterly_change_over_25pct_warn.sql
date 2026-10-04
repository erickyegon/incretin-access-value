{{ config(severity='warn') }}
-- warn when a state's quarter-average enrollment moves more than 25% from the previous quarter (primary or Medicaid + CHIP denominator)
select state_code, quarter_label, qoq_change_medicaid, qoq_change_medicaid_chip from {{ ref('int_enrollment__state_quarter') }}
where abs(qoq_change_medicaid) > 0.25 or abs(qoq_change_medicaid_chip) > 0.25
