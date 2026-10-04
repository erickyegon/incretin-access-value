-- ClinicalTrials.gov studies of the incretin ingredients (the pipeline and evidence inventory). Grain: nct_id.
-- The condition flags are plain keyword matches on the registry condition text (obes, overweight, weight; diabet) and say nothing about
-- the trial's primary indication. Dates are as registered; start_year is NULL when no start date is registered.
select
    s.nct_id, s.title, s.official_title, s.phase, s.status, s.study_type,
    s.start_date, s.start_date_parsed, extract(year from s.start_date_parsed)::int as start_year,
    s.primary_completion_date, s.completion_date,
    s.sponsor, s.sponsor_class, s.enrollment, s.enrollment_type, s.results_posted,
    s.conditions, s.interventions, s.matched_ingredients,
    (s.phase ~* 'PHASE3') as is_phase3,
    (s.conditions ~* 'obes|overweight|weight') as condition_mentions_obesity,
    (s.conditions ~* 'diabet') as condition_mentions_diabetes,
    s.last_update
from {{ ref('stg_ctgov__studies') }} s
