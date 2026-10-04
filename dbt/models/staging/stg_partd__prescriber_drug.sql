-- Medicare Part D Prescribers by Provider and Drug, incretin rows only. Grain: prescriber NPI x brand x generic x data_year.
-- CMS publishes a prescriber-drug row only when the prescriber has at least 11 claims for the drug (the row floor), so low-volume
-- prescribers are absent, not zero. The 65+ columns are suppressed (NULL) under 11 claims.
{% set years = range(2013, 2025) %}
{% for y in years %}
select
    "Prscrbr_NPI"::text as prescriber_npi,
    "Prscrbr_Last_Org_Name"::text as prescriber_last_org_name,
    "Prscrbr_First_Name"::text as prescriber_first_name,
    "Prscrbr_City"::text as prescriber_city,
    "Prscrbr_State_Abrvtn"::text as prescriber_state,
    "Prscrbr_State_FIPS"::text as prescriber_state_fips,
    "Prscrbr_Type"::text as prescriber_type,
    "Prscrbr_Type_Src"::text as prescriber_type_source,
    "Brnd_Name"::text as brand_name,
    "Gnrc_Name"::text as generic_name,
    "Tot_Clms"::numeric as total_claims,
    "Tot_30day_Fills"::numeric as total_30day_fills,
    "Tot_Day_Suply"::numeric as total_day_supply,
    "Tot_Drug_Cst"::numeric as total_drug_cost,
    "Tot_Benes"::numeric as total_beneficiaries,
    "GE65_Sprsn_Flag"::text as ge65_suppression_flag,
    "GE65_Tot_Clms"::numeric as ge65_total_claims,
    "GE65_Tot_30day_Fills"::numeric as ge65_total_30day_fills,
    "GE65_Tot_Drug_Cst"::numeric as ge65_total_drug_cost,
    "GE65_Tot_Day_Suply"::numeric as ge65_total_day_supply,
    "GE65_Bene_Sprsn_Flag"::text as ge65_beneficiary_suppression_flag,
    "GE65_Tot_Benes"::numeric as ge65_total_beneficiaries,
    "data_year"::int as data_year
from {{ source('raw', 'partd_prescribers_' ~ y) }}
{% if not loop.last %}union all{% endif %}
{% endfor %}
