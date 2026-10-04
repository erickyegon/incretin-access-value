-- Enrollment by panel state and quarter: the average of the months present (NULL months are skipped, not treated as zero) for each of the
-- three denominators, with the number of months present (0 to 3) so a short quarter is visible. Grain: state_code x year x quarter (51 x 33).
--   medicaid       = total_medicaid_enrollment (item 8a), the primary denominator
--   medicaid_chip  = total_medicaid_and_chip_enrollment (8a + 8h), sensitivity
--   adult_medicaid = total_adult_medicaid_enrollment (8d + 8g), sensitivity; reported by few states, check n_months_present_adult_medicaid
-- definition_caveat rolls up the month-level flag: true when any month of the quarter carries a definition footnote on that count.
with m as (select * from {{ ref('int_enrollment__state_month') }}),
q as (
    select
        state_code, year, quarter,
        avg(total_medicaid_enrollment) as enrollment_medicaid_avg,
        count(total_medicaid_enrollment) as n_months_present_medicaid,
        avg(total_medicaid_and_chip_enrollment) as enrollment_medicaid_chip_avg,
        count(total_medicaid_and_chip_enrollment) as n_months_present_medicaid_chip,
        avg(total_adult_medicaid_enrollment) as enrollment_adult_medicaid_avg,
        count(total_adult_medicaid_enrollment) as n_months_present_adult_medicaid,
        count(*) filter (where report_status_used = 'updated') as n_months_updated,
        count(*) filter (where report_status_used = 'preliminary') as n_months_preliminary,
        count(*) filter (where report_status_used = 'missing') as n_months_no_row,
        bool_or(definition_caveat) as definition_caveat,
        count(*) filter (where definition_caveat) as n_months_definition_caveat,
        bool_or(definition_caveat_medicaid_chip) as definition_caveat_medicaid_chip,
        bool_or(definition_caveat_adult) as definition_caveat_adult,
        bool_or(data_unavailable_note) as data_unavailable_note,
        bool_or(enrollment_zero_set_null) as enrollment_zero_set_null
    from m
    group by 1, 2, 3
)
select
    q.state_code, q.year, q.quarter,
    qt.quarter_label, qt.quarter_start,
    q.enrollment_medicaid_avg, q.n_months_present_medicaid,
    q.enrollment_medicaid_chip_avg, q.n_months_present_medicaid_chip,
    q.enrollment_adult_medicaid_avg, q.n_months_present_adult_medicaid,
    q.n_months_updated, q.n_months_preliminary, q.n_months_no_row,
    q.definition_caveat, q.n_months_definition_caveat, q.definition_caveat_medicaid_chip, q.definition_caveat_adult,
    q.data_unavailable_note, q.enrollment_zero_set_null,
    q.enrollment_medicaid_avg / nullif(lag(q.enrollment_medicaid_avg) over w, 0) - 1 as qoq_change_medicaid,
    q.enrollment_medicaid_chip_avg / nullif(lag(q.enrollment_medicaid_chip_avg) over w, 0) - 1 as qoq_change_medicaid_chip
from q
join {{ ref('quarters') }} qt on qt.year = q.year and qt.quarter = q.quarter
window w as (partition by q.state_code order by q.year, q.quarter)
