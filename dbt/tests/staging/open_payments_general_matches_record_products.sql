-- the general table and the record-products table agree on amount per record
select g.record_id, g.total_amount_usd, r.total_amount_usd as record_products_amount
from {{ ref('stg_open_payments__general') }} g
join {{ ref('stg_open_payments__record_products') }} r using (record_id)
where g.total_amount_usd is distinct from r.total_amount_usd
