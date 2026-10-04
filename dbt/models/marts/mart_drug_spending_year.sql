-- Annual drug spending, Medicare Part D and Medicaid side by side (Overall rows, all manufacturers). Grain: brand_name x generic_name x year.
-- Both are gross of rebates and the two programmes are NOT additive with each other's definitions (Part D spend includes plan and
-- beneficiary payments; Medicaid spend is reimbursed amounts). Missing programme-year = NULL, not zero. Combination products are excluded.
select
    coalesce(p.brand_name, m.brand_name) as brand_name,
    coalesce(p.generic_name, m.generic_name) as generic_name,
    coalesce(p.year, m.year) as year,
    d.product_group,
    p.total_spending as partd_spending, p.total_claims as partd_claims, p.total_beneficiaries as partd_beneficiaries,
    p.total_dosage_units as partd_dosage_units, p.avg_spend_per_claim as partd_avg_spend_per_claim, p.outlier_flag as partd_outlier_flag,
    m.total_spending as medicaid_spending, m.total_claims as medicaid_claims,
    m.total_dosage_units as medicaid_dosage_units, m.avg_spend_per_claim as medicaid_avg_spend_per_claim, m.outlier_flag as medicaid_outlier_flag
from {{ ref('stg_spending__partd') }} p
full outer join {{ ref('stg_spending__medicaid') }} m
    on m.brand_name = p.brand_name and m.generic_name = p.generic_name and m.year = p.year
join {{ ref('int_drug_name__product_group') }} d
    on d.brand_name = coalesce(p.brand_name, m.brand_name) and d.generic_name = coalesce(p.generic_name, m.generic_name)
where d.product_group <> 'combination_excluded'
