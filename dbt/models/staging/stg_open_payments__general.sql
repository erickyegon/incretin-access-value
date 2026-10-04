-- Open Payments general payments matched to an incretin product name. Grain: one payment record (record_id) per program year.
-- is_physician follows the Phase 3 rule: Covered_Recipient_Type starts with 'Covered Recipient Physician' (teaching hospitals and
-- non-physician practitioners are false; NPs and PAs enter the program in 2021). Headline totals count each record once.
{% set years = range(2019, 2026) %}
{% for y in years %}
select
    "Record_ID"::text as record_id,
    "Program_Year"::int as program_year,
    "Change_Type"::text as change_type,
    "Dispute_Status_for_Publication"::text as dispute_status,
    "Covered_Recipient_Type"::text as covered_recipient_type,
    ("Covered_Recipient_Type" like 'Covered Recipient Physician%') as is_physician,
    nullif("Covered_Recipient_NPI", '')::text as covered_recipient_npi,
    "Covered_Recipient_Primary_Type_1"::text as covered_recipient_primary_type,
    "Covered_Recipient_Specialty_1"::text as covered_recipient_specialty,
    "Recipient_State"::text as recipient_state,
    "Recipient_Zip_Code"::text as recipient_zip,
    "Applicable_Manufacturer_or_Applicable_GPO_Making_Payment_Name"::text as manufacturer_name,
    "Total_Amount_of_Payment_USDollars"::numeric(14, 2) as total_amount_usd,
    to_date("Date_of_Payment", 'MM/DD/YYYY') as date_of_payment,
    "Nature_of_Payment_or_Transfer_of_Value"::text as nature_of_payment,
    "Form_of_Payment_or_Transfer_of_Value"::text as form_of_payment,
    "Name_of_Drug_or_Biological_or_Device_or_Medical_Supply_1"::text as product_name_1,
    "Name_of_Drug_or_Biological_or_Device_or_Medical_Supply_2"::text as product_name_2,
    "Name_of_Drug_or_Biological_or_Device_or_Medical_Supply_3"::text as product_name_3,
    "Name_of_Drug_or_Biological_or_Device_or_Medical_Supply_4"::text as product_name_4,
    "Name_of_Drug_or_Biological_or_Device_or_Medical_Supply_5"::text as product_name_5,
    "matched_product_name"::text as matched_product_name
from {{ source('raw', 'open_payments_general_' ~ y) }}
{% if not loop.last %}union all{% endif %}
{% endfor %}
