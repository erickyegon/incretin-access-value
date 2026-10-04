-- Medicare Part D prescriber-drug rows with product group and prescriber specialty. Grain: prescriber_npi x brand_name x generic_name x data_year.
-- Only prescribers with at least 11 claims for a drug appear (CMS row floor); absent rows are not zero. Part D does not cover drugs used
-- only for weight loss, so Wegovy appears only for its cardiovascular indication (2024). Combination products are excluded.
-- Specialty: prescriber_type is the CMS Medicare specialty; taxonomy_* come from the NPPES primary taxonomy code and the NUCC code set.
select
    p.prescriber_npi, p.data_year,
    p.brand_name, p.generic_name, d.product_group, d.group_basis,
    p.prescriber_type,
    n.entity_type_code, n.practice_state, n.primary_taxonomy_code,
    t.classification as taxonomy_classification, t.specialization as taxonomy_specialization,
    (n.npi is not null) as in_nppes,
    p.prescriber_state, p.total_claims, p.total_30day_fills, p.total_day_supply, p.total_drug_cost, p.total_beneficiaries
from {{ ref('stg_partd__prescriber_drug') }} p
join {{ ref('int_drug_name__product_group') }} d on d.brand_name = p.brand_name and d.generic_name = p.generic_name
left join {{ ref('stg_nppes__provider') }} n on n.npi = p.prescriber_npi
left join {{ ref('stg_nucc__taxonomy') }} t on t.taxonomy_code = n.primary_taxonomy_code
where d.product_group <> 'combination_excluded'
