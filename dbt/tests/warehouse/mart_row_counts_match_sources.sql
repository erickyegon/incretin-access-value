-- NHANES adults keep every participant aged 20+ (missing BMI kept); MEPS persons equal the full-year file rows; trials equal the registry rows
select 'nhanes adults' as problem, ((select count(*) from {{ ref('mart_nhanes_adults') }}) || ' vs ' || count(*)) as detail
from {{ ref('stg_nhanes__demo') }} where ridageyr >= 20
having count(*) <> (select count(*) from {{ ref('mart_nhanes_adults') }})
union all
select 'nhanes under 20 present', count(*)::text from {{ ref('mart_nhanes_adults') }} where ridageyr < 20 having count(*) > 0
union all
select 'nhanes bmi flag', count(*)::text from {{ ref('mart_nhanes_adults') }} where bmi_missing <> (bmxbmi is null) having count(*) > 0
union all
select 'meps persons', ((select count(*) from {{ ref('mart_meps_persons') }}) || ' vs ' || ((select count(*) from {{ ref('stg_meps__fyc_2023') }}) + (select count(*) from {{ ref('stg_meps__fyc_2024') }})))
where (select count(*) from {{ ref('mart_meps_persons') }}) <> (select count(*) from {{ ref('stg_meps__fyc_2023') }}) + (select count(*) from {{ ref('stg_meps__fyc_2024') }})
union all
select 'trials', count(*)::text from {{ ref('stg_ctgov__studies') }} having count(*) <> (select count(*) from {{ ref('mart_pipeline_trials') }})
