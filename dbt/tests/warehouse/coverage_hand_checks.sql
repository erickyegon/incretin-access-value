-- hand-checked coverage values from the source documents; any row returned is a failure
with expected(state_code, first_treated_quarter, first_full_quarter) as (
    values ('MI', '2022Q1', '2022Q2'), ('CA', '2023Q1', '2023Q1'), ('PA', '2023Q1', '2023Q2'), ('KS', '2021Q3', '2021Q4'),
           ('MA', '2024Q1', '2024Q2')
),
actual as (
    select distinct state_code, first_treated_quarter, first_full_quarter from {{ ref('int_coverage__state_quarter') }}
)
select e.state_code, e.first_treated_quarter as expected_treated, a.first_treated_quarter as actual_treated,
       e.first_full_quarter as expected_full, a.first_full_quarter as actual_full
from expected e left join actual a using (state_code)
where a.first_treated_quarter is distinct from e.first_treated_quarter or a.first_full_quarter is distinct from e.first_full_quarter
union all
-- North Carolina: coverage ended 2025-09-30 and restarted 2025-12-12, so 2025Q4 is partly covered and 2026Q1 is active again
select 'NC', 'covered_days_share 2025Q4', covered_days_share::text, null, null
from {{ ref('int_coverage__state_quarter') }}
where state_code = 'NC' and quarter_label = '2025Q4' and not (covered_days_share > 0 and covered_days_share < 1)
union all
select 'NC', 'coverage_active 2026Q1', coverage_active::text, null, null
from {{ ref('int_coverage__state_quarter') }}
where state_code = 'NC' and quarter_label = '2026Q1' and not coverage_active
