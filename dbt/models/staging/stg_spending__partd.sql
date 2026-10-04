-- Medicare Part D Spending by Drug, Overall rows only (Mftr_Name = 'Overall', all manufacturers combined). Grain: brand x generic x year.
select
    "Brnd_Name"::text as brand_name,
    "Gnrc_Name"::text as generic_name,
    "Tot_Mftr"::int as total_manufacturers,
    year::int as year,
    "Tot_Spndng"::numeric as total_spending,
    "Tot_Dsg_Unts"::numeric as total_dosage_units,
    "Tot_Clms"::numeric as total_claims,
    "Tot_Benes"::numeric as total_beneficiaries,
    "Avg_Spnd_Per_Dsg_Unt_Wghtd"::numeric as avg_spend_per_dosage_unit_weighted,
    "Avg_Spnd_Per_Clm"::numeric as avg_spend_per_claim,
    "Avg_Spnd_Per_Bene"::numeric as avg_spend_per_beneficiary,
    "Outlier_Flag"::text as outlier_flag
from {{ source('raw', 'spending_partd_long') }}
where "Mftr_Name" = 'Overall'
