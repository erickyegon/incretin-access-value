-- Open Payments: the equal-split dollars in the mart add back to the headline total of all records (each record once), to the cent, by program
-- year and physician flag; the total is $238.9M; the overlapping dollars are never below the equal split
with by_year as (
    select program_year, is_physician, round(sum(total_amount_usd) * 100)::bigint as headline_cents
    from {{ ref('stg_open_payments__general') }} group by 1, 2
),
mart as (
    select program_year, is_physician, round(sum(amount_equal_split) * 100)::bigint as split_cents,
           sum(amount_overlapping) as overlapping, sum(amount_equal_split) as split
    from {{ ref('mart_open_payments_year_product') }} group by 1, 2
)
select b.program_year::text as period, b.is_physician::text as flag, 'equal split <> headline' as problem
from by_year b left join mart m using (program_year, is_physician)
where m.split_cents is distinct from b.headline_cents
union all
select 'total', null, 'headline total is not 238.9 million: ' || round(sum(total_amount_usd) / 1000000.0, 1)::text
from {{ ref('stg_open_payments__general') }} having round(sum(total_amount_usd) / 1000000.0, 1) <> 238.9
union all
select program_year::text, is_physician::text, 'overlapping below split' from mart where overlapping < split - 0.005
