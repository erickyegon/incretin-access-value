-- the brand-level SDUD mart adds back to the long mart (ALL utilization) for the obesity product groups, in prescriptions and cents
with b as (select product_group, sum(rx_observed) rx, round(sum(amount_total_observed) * 100)::bigint cents from {{ ref('mart_sdud_state_quarter_brand') }} group by 1),
l as (select product_group, sum(rx_observed) rx, round(sum(amount_total_observed) * 100)::bigint cents from {{ ref('mart_sdud_state_quarter_long') }}
      where utilization_type = 'ALL' and product_group in ('obesity_wz', 'obesity_saxenda', 'obesity_other') group by 1)
select b.product_group from b full outer join l using (product_group) where b.rx is distinct from l.rx or b.cents is distinct from l.cents
