{{ config(severity='warn') }}
-- warn when a state-month has no enrollment row in either report (flagged 'missing', never silently filled)
select state_code, month_start from {{ ref('int_enrollment__state_month') }} where report_status_used = 'missing'
