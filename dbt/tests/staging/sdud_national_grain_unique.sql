select utilization_type, ndc11, year, quarter, count(*) as n_rows
from {{ ref('stg_sdud__national') }}
group by 1, 2, 3, 4
having count(*) > 1
