select ndc11, as_of_date, pharmacy_type_indicator, count(*) as n_rows
from {{ ref('stg_nadac__weekly') }}
group by 1, 2, 3
having count(*) > 1
