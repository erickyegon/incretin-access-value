-- Calendar quarters 2018Q1 to 2026Q1 (the SDUD window). One row per quarter. 2026Q1 is preliminary in SDUD.
with spine as (
    {{ dbt_utils.date_spine(datepart="month", start_date="cast('2018-01-01' as date)", end_date="cast('2026-04-01' as date)") }}
)
select
    extract(year from date_month)::int as year,
    extract(quarter from date_month)::int as quarter,
    extract(year from date_month)::int * 10 + extract(quarter from date_month)::int as quarter_id,
    (extract(year from date_month)::int || 'Q' || extract(quarter from date_month)::int) as quarter_label,
    date_month::date as quarter_start,
    (date_month + interval '3 months' - interval '1 day')::date as quarter_end,
    ((date_month + interval '3 months')::date - date_month::date) as days_in_quarter,
    date_month::date >= '{{ var("preliminary_from_quarter_start") }}'::date as is_preliminary
from spine
where extract(month from date_month) in (1, 4, 7, 10)
