-- State Medicaid obesity-drug (Wegovy/Zepbound) coverage by panel state and quarter. Grain: state_code x quarter (51 x 33).
-- Territories are not in the panel (states.in_panel = false: AS, GU, MP, PR, UM, VI); see docs/warehouse.md.
-- Rules (docs/data_dictionary.md, coverage rules a-e):
--   covered_days_share      days inside a coverage spell / days in the quarter, using the LATEST possible start (start_date_high), so a
--                           range start never overstates coverage; covered_days_share_max uses the earliest possible start.
--   coverage_active         covered_days_share > 0 (any covered day in the quarter); coverage_full_quarter = share is 1.
--   first_treated_quarter   quarter that contains the first spell start; NULL when the start range straddles quarters (sensitivity states).
--   first_full_quarter      first quarter fully covered: the same quarter if the start is the first day of the quarter, else the next
--                           quarter (month-only starts such as Massachusetts take the next quarter, the conservative choice).
--   post_withdrawal         no covered day in the quarter, after a spell has ended.
-- analysis_group is primary, sensitivity or never_treated (states with no coverage spell).
with st as (select state_code, state_name from {{ ref('states') }} where in_panel),
qtr as (select *, lead(quarter_label) over (order by quarter_start) as next_quarter_label from {{ ref('quarters') }}),
spells as (select * from {{ ref('medicaid_obesity_coverage') }}),
first_spell as (select * from spells where spell_no = 1),
first_info as (
    select
        f.state_code, f.analysis_group, f.category_level_spa, f.kansas_flag, f.start_precision,
        qe.quarter_label as start_quarter_earliest,
        ql.quarter_label as start_quarter_latest,
        case when qe.quarter_label = ql.quarter_label then ql.quarter_label end as first_treated_quarter,
        case when qe.quarter_label = ql.quarter_label
             then case when f.start_date_high = ql.quarter_start and f.start_precision = 'day' then ql.quarter_label else ql.next_quarter_label end
        end as first_full_quarter
    from first_spell f
    join qtr qe on f.start_date_low between qe.quarter_start and qe.quarter_end
    join qtr ql on f.start_date_high between ql.quarter_start and ql.quarter_end
),
overlap as (
    select
        st.state_code, q.quarter_start,
        sum(greatest(0, least(q.quarter_end, coalesce(s.coverage_end, date '9999-12-31')) - greatest(q.quarter_start, s.start_date_high) + 1)) as days_conservative,
        sum(greatest(0, least(q.quarter_end, coalesce(s.coverage_end, date '9999-12-31')) - greatest(q.quarter_start, s.start_date_low) + 1)) as days_max,
        bool_or(s.coverage_end is not null and s.coverage_end < q.quarter_start) as a_spell_has_ended
    from st
    cross join qtr q
    join spells s on s.state_code = st.state_code
    group by 1, 2
)
select
    st.state_code,
    q.year, q.quarter, q.quarter_label, q.quarter_start,
    coalesce(fi.analysis_group, 'never_treated') as analysis_group,
    coalesce(o.days_conservative, 0)::numeric / q.days_in_quarter as covered_days_share,
    coalesce(o.days_max, 0)::numeric / q.days_in_quarter as covered_days_share_max,
    coalesce(o.days_conservative, 0) > 0 as coverage_active,
    coalesce(o.days_conservative, 0) = q.days_in_quarter as coverage_full_quarter,
    fi.first_treated_quarter,
    fi.first_full_quarter,
    fi.start_quarter_earliest,
    fi.start_quarter_latest,
    fi.start_precision,
    (coalesce(o.days_conservative, 0) = 0 and coalesce(o.a_spell_has_ended, false)) as post_withdrawal,
    coalesce(fi.kansas_flag, false) as kansas_flag,
    coalesce(fi.category_level_spa, false) as category_level_spa,
    (fi.state_code is not null) as has_coverage_spell
from st
cross join qtr q
left join first_info fi on fi.state_code = st.state_code
left join overlap o on o.state_code = st.state_code and o.quarter_start = q.quarter_start
