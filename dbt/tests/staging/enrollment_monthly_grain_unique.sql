select state_code, month_start, report_status, count(*) as n_rows
from {{ ref('stg_enrollment__monthly') }}
group by 1, 2, 3
having count(*) > 1
