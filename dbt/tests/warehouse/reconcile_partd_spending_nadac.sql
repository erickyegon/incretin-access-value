-- Part D prescriber claims and cost, Part D and Medicaid spending, and NADAC row counts reconcile staging -> marts (combinations excluded
-- where the marts exclude them); every drug name has a product group
with pd as (
    select p.* from {{ ref('stg_partd__prescriber_drug') }} p
    join {{ ref('int_drug_name__product_group') }} d on d.brand_name = p.brand_name and d.generic_name = p.generic_name
    where d.product_group <> 'combination_excluded'
),
sp as (
    select p.* from {{ ref('stg_spending__partd') }} p
    join {{ ref('int_drug_name__product_group') }} d on d.brand_name = p.brand_name and d.generic_name = p.generic_name
    where d.product_group <> 'combination_excluded'
),
sm as (
    select m.* from {{ ref('stg_spending__medicaid') }} m
    join {{ ref('int_drug_name__product_group') }} d on d.brand_name = m.brand_name and d.generic_name = m.generic_name
    where d.product_group <> 'combination_excluded'
)
select 'prescriber claims' as problem where (select sum(total_claims) from {{ ref('mart_prescriber_year') }}) <> (select sum(total_claims) from pd)
union all
select 'prescriber rows' where (select count(*) from {{ ref('mart_prescriber_year') }}) <> (select count(*) from pd)
union all
select 'prescriber cost (cents)' where (select round(sum(total_drug_cost) * 100) from {{ ref('mart_prescriber_year') }}) <> (select round(sum(total_drug_cost) * 100) from pd)
union all
select 'part d spending (cents)' where (select round(sum(partd_spending) * 100) from {{ ref('mart_drug_spending_year') }}) <> (select round(sum(total_spending) * 100) from sp)
union all
select 'medicaid spending (cents)' where (select round(sum(medicaid_spending) * 100) from {{ ref('mart_drug_spending_year') }}) <> (select round(sum(total_spending) * 100) from sm)
union all
select 'nadac rows' where (select sum(n_weekly_ndc_rows) from {{ ref('mart_nadac_brand_quarter') }}) <> (select count(*) from {{ ref('stg_nadac__weekly') }})
union all
select 'drug name without product group: ' || brand_name from {{ ref('int_drug_name__product_group') }} where product_group is null
