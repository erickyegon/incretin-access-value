-- insulin/GLP-1 combination products (Soliqua, Xultophy) are in no outcome model
select 'int_sdud__state_quarter_group' as model, product_group as detail from {{ ref('int_sdud__state_quarter_group') }}
where product_group not in ('obesity_wz', 'obesity_saxenda', 'obesity_other', 'diabetes_glp1')
union all
select 'mart_sdud_state_quarter_long', product_group from {{ ref('mart_sdud_state_quarter_long') }}
where product_group not in ('obesity_wz', 'obesity_saxenda', 'obesity_other', 'diabetes_glp1')
union all
select 'mart_sdud_cells_for_imputation', product_group from {{ ref('mart_sdud_cells_for_imputation') }}
where product_group not in ('obesity_wz', 'obesity_saxenda', 'obesity_other', 'diabetes_glp1')
union all
select 'int_sdud__national_residual', product_group from {{ ref('int_sdud__national_residual') }}
where product_group not in ('obesity_wz', 'obesity_saxenda', 'obesity_other', 'diabetes_glp1')
union all
select 'mart_prescriber_year', brand_name from {{ ref('mart_prescriber_year') }}
where product_group = 'combination_excluded' or product_group is null
union all
select 'mart_drug_spending_year', brand_name from {{ ref('mart_drug_spending_year') }}
where product_group = 'combination_excluded' or product_group is null
union all
select 'mart_meps_persons', dupersid from {{ ref('mart_meps_persons') }} m
where false
union all
select 'combination NDC in imputation cells', g.ndc11 from {{ ref('int_sdud__ndc_group') }} g
join {{ ref('mart_sdud_cells_for_imputation') }} c on c.ndc11 = g.ndc11 where g.is_combination
