-- MEPS persons for 2023 and 2024 (Full Year Consolidated files) with condition and prescription flags from the linked files.
-- Grain: data_year x dupersid. Survey design: varstr, varpsu, person_weight (perwt23f / perwt24f). Conditions are 3-character ICD-10 codes
-- in MEPS, so type 2 diabetes is E11 and obesity E66 (the Z68 BMI codes are not available at 3 characters of detail). Incretin
-- prescriptions are matched by NDC (rxndc) to product_map; counts are purchase records, per product group, combination products excluded.
{% set years = [2023, 2024] %}
{% for y in years %}
{% set yy = y - 2000 %}
select
    {{ y }} as data_year, f.dupersid, f.panel, f.agelast as age_last, f.sex, f.racethx, f.povcat{{ yy }} as poverty_category,
    f.inscov{{ yy }} as insurance_coverage, f.hibpdx, f.chddx, f.diabdx_m18,
    f.totexp{{ yy }} as total_expenditure, f.rxtot{{ yy }} as rx_purchases, f.rxexp{{ yy }} as rx_expenditure,
    f.perwt{{ yy }}f as person_weight, f.varstr, f.varpsu,
    coalesce(c.has_t2d_condition, false) as has_t2d_condition,
    coalesce(c.has_obesity_condition, false) as has_obesity_condition,
    coalesce(r.n_rx_obesity_wz, 0) as n_rx_obesity_wz,
    coalesce(r.n_rx_obesity_saxenda, 0) as n_rx_obesity_saxenda,
    coalesce(r.n_rx_obesity_other, 0) as n_rx_obesity_other,
    coalesce(r.n_rx_diabetes_glp1, 0) as n_rx_diabetes_glp1
from {{ ref('stg_meps__fyc_' ~ y) }} f
left join (
    select dupersid, bool_or(icd10cdx = 'E11') as has_t2d_condition, bool_or(icd10cdx = 'E66') as has_obesity_condition
    from {{ ref('stg_meps__cond_' ~ y) }} group by 1
) c on c.dupersid = f.dupersid
left join (
    select x.dupersid,
        count(*) filter (where g.product_group = 'obesity_wz') as n_rx_obesity_wz,
        count(*) filter (where g.product_group = 'obesity_saxenda') as n_rx_obesity_saxenda,
        count(*) filter (where g.product_group = 'obesity_other') as n_rx_obesity_other,
        count(*) filter (where g.product_group = 'diabetes_glp1') as n_rx_diabetes_glp1
    from {{ ref('stg_meps__rx_' ~ y) }} x
    join {{ ref('int_sdud__ndc_group') }} g on g.ndc11 = x.rxndc and g.product_group <> 'combination_excluded'
    group by 1
) r on r.dupersid = f.dupersid
{% if not loop.last %}union all{% endif %}
{% endfor %}
