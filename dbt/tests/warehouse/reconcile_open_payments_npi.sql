-- the NPI-level payments mart adds back to the record-product table for recipients with an NPI, in whole cents by program year
with a as (select program_year, round(sum(amount_equal_split) * 100)::bigint c from {{ ref('mart_open_payments_npi_year') }} group by 1),
b as (select program_year, round(sum(amount_equal_split) * 100)::bigint c from {{ ref('stg_open_payments__product_split') }} where covered_recipient_npi is not null group by 1)
select coalesce(a.program_year, b.program_year) as program_year from a full outer join b using (program_year) where a.c is distinct from b.c
