-- for every record that names an in-scope product, the equal-split amounts add back to the record total (to the cent)
select s.record_id, max(s.record_amount_usd) as record_amount_usd, sum(s.amount_equal_split) as split_sum
from {{ ref('stg_open_payments__product_split') }} s
group by s.record_id
having abs(sum(s.amount_equal_split) - max(s.record_amount_usd)) >= 0.005
