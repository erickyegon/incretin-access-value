-- Medicaid and CHIP enrollment, one row per panel state (50 states + DC) and month, 2018-01 to 2026-03 (the SDUD window).
-- Report choice: the "updated" row for the state-month; the "preliminary" row only where no updated row exists. report_status_used
-- says which ('updated', 'preliminary') or 'missing' when the dataset has no row at all (the grid still carries the state-month).
-- Footnotes are definition caveats, not missing data: values are kept. definition_caveat is true when the footnote on that count says
-- the definition differs from a clean point-in-time count of people in the programme ("Includes ...", "Does Not Include ...").
-- The footnote "Unable to Provide Data due to System Limitations" is a missing-data note, not a definition caveat (data_unavailable_note).
-- Zeros that the loader set to NULL (Rhode Island) stay NULL.
with grid as (
    select s.state_code, m.month_start::date as month_start
    from {{ ref('states') }} s
    cross join generate_series('2018-01-01'::date, '2026-03-01'::date, interval '1 month') as m(month_start)
    where s.in_panel
),
ranked as (
    select e.*,
        row_number() over (partition by e.state_code, e.month_start
                           order by (e.report_status = 'updated') desc) as rn
    from {{ ref('stg_enrollment__monthly') }} e
),
chosen as (select * from ranked where rn = 1)
select
    g.state_code,
    g.month_start,
    extract(year from g.month_start)::int as year,
    extract(quarter from g.month_start)::int as quarter,
    coalesce(c.report_status, 'missing') as report_status_used,
    (c.state_code is not null) as has_enrollment_row,
    c.total_medicaid_enrollment,
    c.total_medicaid_and_chip_enrollment,
    c.total_adult_medicaid_enrollment,
    c.total_medicaid_enrollment_footnote,
    c.total_medicaid_and_chip_enrollment_footnote,
    c.total_adult_medicaid_enrollment_footnote,
    coalesce(c.total_medicaid_enrollment_footnote !~* 'unable to provide data', false) as definition_caveat,
    coalesce(c.total_medicaid_and_chip_enrollment_footnote !~* 'unable to provide data', false) as definition_caveat_medicaid_chip,
    coalesce(c.total_adult_medicaid_enrollment_footnote !~* 'unable to provide data', false) as definition_caveat_adult,
    coalesce(c.total_medicaid_enrollment_footnote ~* 'unable to provide data'
          or c.total_medicaid_and_chip_enrollment_footnote ~* 'unable to provide data'
          or c.total_adult_medicaid_enrollment_footnote ~* 'unable to provide data', false) as data_unavailable_note,
    coalesce(c.enrollment_zero_set_null, false) as enrollment_zero_set_null
from grid g
left join chosen c on c.state_code = g.state_code and c.month_start = g.month_start
