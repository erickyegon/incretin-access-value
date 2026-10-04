-- Product group for the drug names used by Part D prescriber, Part D spending and Medicaid spending (brand and generic names, no NDC).
-- Grain: brand_name x generic_name. Matching: the first word of the brand name (Victoza 2-Pak -> Victoza, Bydureon Bcise -> Bydureon)
-- against the brands in product_groups. If no brand matches (the file lists the generic name as the brand, e.g. Liraglutide), the generic
-- name is matched to an ingredient and the DIABETES group is taken: Part D excludes drugs used for weight loss by statute, so a generic-named
-- Part D row is a diabetes product. group_basis records which rule applied.
with names as (
    select brand_name, generic_name from {{ ref('stg_partd__prescriber_drug') }}
    union select brand_name, generic_name from {{ ref('stg_spending__partd') }}
    union select brand_name, generic_name from {{ ref('stg_spending__medicaid') }}
),
brand_groups as (
    select lower(brand) as brand_key, min(product_group) as product_group, count(distinct product_group) as n_groups
    from {{ ref('product_groups') }} where brand is not null group by 1
),
generic_groups as (
    select lower(ingredient) as ingredient_key, min(product_group) as product_group
    from {{ ref('product_groups') }} where brand is null and label_group = 'diabetes' group by 1
)
select
    n.brand_name, n.generic_name,
    coalesce(b.product_group, gg.product_group) as product_group,
    case when b.product_group is not null then 'brand' when gg.product_group is not null then 'generic_name_diabetes' end as group_basis
from names n
left join brand_groups b on b.brand_key = lower(split_part(n.brand_name, ' ', 1))
left join generic_groups gg on gg.ingredient_key = lower(split_part(n.generic_name, ' ', 1))
