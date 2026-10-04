select prescriber_npi, brand_name, generic_name, data_year, count(*) as n_rows
from {{ ref('stg_partd__prescriber_drug') }}
group by 1, 2, 3, 4
having count(*) > 1
