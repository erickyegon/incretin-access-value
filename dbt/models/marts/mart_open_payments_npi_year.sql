-- In-scope Open Payments by recipient NPI and program year, for linking to prescribers (Module D). Grain: covered_recipient_npi x program_year.
-- Each payment record counts once in amount_equal_split (the record amount divided over the in-scope products it names), so the sum over NPIs plus
-- recipients without an NPI (teaching hospitals) equals the headline total. amount_overlapping counts the full record for every product named.
-- NPs and PAs enter the programme in 2021; is_physician is the recipient-type flag. Recipients without an NPI are not in this table.
-- Aggregate use only: no NPI-level result is published from this table.
select
    covered_recipient_npi, program_year,
    bool_or(is_physician) as is_physician,
    count(distinct record_id) as n_records,
    sum(amount_equal_split) as amount_equal_split,
    sum(amount_overlapping) as amount_overlapping
from {{ ref('stg_open_payments__product_split') }}
where covered_recipient_npi is not null
group by 1, 2
