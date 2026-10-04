-- coverage logic: shares within 0..1, max >= conservative, active <=> share > 0, a never-treated state has no coverage, withdrawal only with no
-- coverage, primary states have a unique start quarter, Kansas is primary, category-level SPAs are MS and TN only
select state_code, quarter_label, 'bad share' as problem from {{ ref('int_coverage__state_quarter') }}
where covered_days_share < 0 or covered_days_share > 1 or covered_days_share_max < covered_days_share
union all
select state_code, quarter_label, 'active flag inconsistent' from {{ ref('int_coverage__state_quarter') }}
where coverage_active <> (covered_days_share > 0)
union all
select state_code, quarter_label, 'never_treated with coverage' from {{ ref('int_coverage__state_quarter') }}
where analysis_group = 'never_treated' and (coverage_active or has_coverage_spell)
union all
select state_code, quarter_label, 'withdrawal while covered' from {{ ref('int_coverage__state_quarter') }}
where post_withdrawal and coverage_active
union all
select state_code, quarter_label, 'primary without unique start quarter' from {{ ref('int_coverage__state_quarter') }}
where analysis_group = 'primary' and (first_treated_quarter is null or first_full_quarter is null)
union all
select state_code, quarter_label, 'kansas not primary' from {{ ref('int_coverage__state_quarter') }}
where kansas_flag and analysis_group <> 'primary'
union all
select state_code, quarter_label, 'category spa not MS or TN' from {{ ref('int_coverage__state_quarter') }}
where category_level_spa and state_code not in ('MS', 'TN')
