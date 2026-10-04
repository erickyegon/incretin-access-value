-- the panel is exactly 51 states x 33 quarters = 1,683 rows, every state has all 33 quarters, no territory or XX row
select 'row count' as problem, count(*)::text as detail from {{ ref('mart_did_panel') }} having count(*) <> 1683
union all
select 'states', count(distinct state_code)::text from {{ ref('mart_did_panel') }} having count(distinct state_code) <> 51
union all
select 'quarters per state', state_code from {{ ref('mart_did_panel') }} group by state_code having count(*) <> 33
union all
select 'territory or XX in panel', state_code from {{ ref('mart_did_panel') }}
where state_code = 'XX' or state_code in (select state_code from {{ ref('states') }} where not in_panel)
