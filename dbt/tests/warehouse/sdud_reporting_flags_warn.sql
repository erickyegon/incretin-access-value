{{ config(severity='warn') }}
-- warn when a panel state-quarter is not_reported or anomalous in SDUD (all drugs), for either utilization type
select state_code, quarter_label, utilization_type,
       case when not_reported then 'not_reported' else 'anomalous' end as flag
from {{ ref('int_sdud__reporting') }}
where not_reported or anomalous
