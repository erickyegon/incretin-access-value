-- every panel state-month from 2018-01 to 2026-03 has a report status: updated, preliminary, or the explicit flag 'missing'
select state_code, month_start, report_status_used from {{ ref('int_enrollment__state_month') }}
where report_status_used is null or report_status_used not in ('updated', 'preliminary', 'missing')
union all
select s.state_code, m.month_start::date, 'state-month absent from grid'
from {{ ref('states') }} s cross join generate_series('2018-01-01'::date, '2026-03-01'::date, interval '1 month') m(month_start)
where s.in_panel and not exists (
    select 1 from {{ ref('int_enrollment__state_month') }} e where e.state_code = s.state_code and e.month_start = m.month_start::date)
