-- suppressed values stay NULL: every imputation cell has a NULL count and bounds 0..10, there is one cell per suppressed non-combination
-- panel-state staging row, no unsuppressed staging row carries a count of 1 to 10, and upper bound = observed + 10 x suppressed rows
select 'cell with a count' as problem, count(*)::text as detail from {{ ref('mart_sdud_cells_for_imputation') }}
where rx_observed is not null or rx_lower_bound <> 0 or rx_upper_bound <> 10 having count(*) > 0
union all
select 'cell count differs from staged suppressed rows', ((select count(*) from {{ ref('mart_sdud_cells_for_imputation') }}) || ' vs ' || count(*))
from {{ ref('stg_sdud__state') }} s
join {{ ref('int_sdud__ndc_group') }} g on g.ndc11 = s.ndc11
join {{ ref('states') }} st on st.state_code = s.state_code and st.in_panel
where s.suppressed and g.product_group <> 'combination_excluded'
having count(*) <> (select count(*) from {{ ref('mart_sdud_cells_for_imputation') }})
union all
select 'unsuppressed count of 1 to 10', count(*)::text from {{ ref('stg_sdud__state') }}
where not suppressed and number_of_prescriptions between 1 and 10 having count(*) > 0
union all
select 'upper bound formula', count(*)::text from {{ ref('mart_sdud_state_quarter_long') }}
where rx_upper_bound <> rx_observed + 10 * n_suppressed_rows having count(*) > 0
