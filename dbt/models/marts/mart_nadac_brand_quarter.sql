-- NADAC acquisition cost by product label and quarter. Grain: brand_label x product_group x pricing_unit x quarter. A weekly NADAC row is one NDC at one
-- as_of_date; the quarter is the quarter of as_of_date. Statistics are across all weekly NDC rows of the label in the quarter (price per
-- pricing unit: EA = each, ML = millilitre). Quarters follow the NADAC file (to 2026Q3), beyond the SDUD window. Brand-less generics are labelled 'GENERIC <ingredient>'. Combination products are flagged.
select
    g.brand_label, g.brand, g.ingredient, g.product_group, g.is_combination,
    n.pricing_unit,
    extract(year from n.as_of_date)::int as year,
    extract(quarter from n.as_of_date)::int as quarter,
    extract(year from n.as_of_date)::int || 'Q' || extract(quarter from n.as_of_date)::int as quarter_label,
    date_trunc('quarter', n.as_of_date)::date as quarter_start,
    count(*) as n_weekly_ndc_rows,
    count(distinct n.ndc11) as n_ndcs,
    count(distinct n.as_of_date) as n_weeks,
    avg(n.nadac_per_unit) as nadac_per_unit_mean,
    min(n.nadac_per_unit) as nadac_per_unit_min,
    max(n.nadac_per_unit) as nadac_per_unit_max
from {{ ref('stg_nadac__weekly') }} n
join {{ ref('int_sdud__ndc_group') }} g on g.ndc11 = n.ndc11
group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
