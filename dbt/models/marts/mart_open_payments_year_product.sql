-- Open Payments by program year and product, physicians apart from other recipients. Grain: program_year x product x is_physician.
-- Two dollar measures, never mixed: amount_equal_split divides each record over the in-scope products it names (sums to the headline total
-- across products, each record once); amount_overlapping counts the full record amount for every product named ("payments mentioning the
-- product"; sums exceed the headline). NPs and PAs enter the programme in 2021, so compare years with is_physician = true.
-- product_group: brand products map to their group; products named only by ingredient have no brand to place them (generic_name_only).
-- Combination products (Soliqua, Xultophy) stay here flagged is_combination, so the equal-split total equals the headline.
with grp as (
    select lower(brand) as brand_key, min(product_group) as product_group from {{ ref('product_groups') }} where brand is not null group by 1
)
select
    s.program_year, s.product, s.is_physician,
    coalesce(g.product_group, 'generic_name_only') as product_group,
    (coalesce(g.product_group, '') = 'combination_excluded') as is_combination,
    count(*) as n_records,
    count(distinct s.covered_recipient_npi) as n_distinct_recipients_npi,
    sum(s.amount_equal_split) as amount_equal_split,
    sum(s.amount_overlapping) as amount_overlapping
from {{ ref('stg_open_payments__product_split') }} s
left join grp g on g.brand_key = s.product
group by 1, 2, 3, 4, 5
