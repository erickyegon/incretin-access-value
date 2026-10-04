-- territories (states.in_panel = false) and XX never appear in the panel-state models
select 'mart_sdud_state_quarter_long' as model, state_code from {{ ref('mart_sdud_state_quarter_long') }}
where state_code = 'XX' or state_code in (select state_code from {{ ref('states') }} where not in_panel)
union all
select 'mart_sdud_cells_for_imputation', state_code from {{ ref('mart_sdud_cells_for_imputation') }}
where state_code = 'XX' or state_code in (select state_code from {{ ref('states') }} where not in_panel)
union all
select 'int_sdud__state_quarter_group', state_code from {{ ref('int_sdud__state_quarter_group') }}
where state_code = 'XX' or state_code in (select state_code from {{ ref('states') }} where not in_panel)
union all
select 'int_coverage__state_quarter', state_code from {{ ref('int_coverage__state_quarter') }}
where state_code in (select state_code from {{ ref('states') }} where not in_panel)
union all
select 'int_enrollment__state_quarter', state_code from {{ ref('int_enrollment__state_quarter') }}
where state_code in (select state_code from {{ ref('states') }} where not in_panel)
