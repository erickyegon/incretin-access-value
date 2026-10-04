-- Product-level attribution of Open Payments records, two ways. Grain: record_id x product.
--   amount_equal_split  = record amount / n_inscope_products (sums back to the record total; use for dollars by product)
--   amount_overlapping  = the full record amount counted for every product named (sums exceed the headline total; label as overlapping)
select
    "Record_ID"::text as record_id,
    "Program_Year"::int as program_year,
    is_physician,
    nullif("Covered_Recipient_NPI", '')::text as covered_recipient_npi,
    product::text as product,
    round(amount::numeric, 2) as record_amount_usd,
    n_inscope_products::int as n_inscope_products,
    amount_equal_split::numeric as amount_equal_split,
    amount_overlapping::numeric as amount_overlapping
from {{ source('raw', 'open_payments_product_attribution') }}
