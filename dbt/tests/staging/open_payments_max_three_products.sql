-- no record has more than 3 product rows, and the row count per record equals n_inscope_products
select record_id, count(*) as n_product_rows, max(n_inscope_products) as n_inscope_products
from {{ ref('stg_open_payments__product_split') }}
group by record_id
having count(*) > 3 or count(*) <> max(n_inscope_products)
