-- grain of stg_sdud__state: one row per state, utilization type, NDC, year, quarter
select state_code, utilization_type, ndc11, year, quarter, count(*) as n_rows
from {{ ref('stg_sdud__state') }}
group by 1, 2, 3, 4, 5
having count(*) > 1
