-- One row per Open Payments record with the count and list of in-scope incretin products it names. Grain: record_id.
-- n_inscope_products is the number of distinct in-scope products among the five product-name fields.
select
    "Record_ID"::text as record_id,
    "Program_Year"::int as program_year,
    "Covered_Recipient_Type"::text as covered_recipient_type,
    is_physician,
    nullif("Covered_Recipient_NPI", '')::text as covered_recipient_npi,
    round(amount::numeric, 2) as total_amount_usd,
    n_inscope_products::int as n_inscope_products,
    nullif(products, '')::text as products
from {{ source('raw', 'open_payments_record_products') }}
