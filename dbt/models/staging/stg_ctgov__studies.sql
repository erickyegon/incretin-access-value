-- ClinicalTrials.gov studies matching an incretin ingredient (API v2). Grain: nct_id. Registry dates are partial strings
-- (YYYY-MM or YYYY-MM-DD) and kept as text; start_date_parsed fills a missing day with 01.
select
    nct_id::text as nct_id, title::text as title, official_title::text as official_title, phase::text as phase, status::text as status,
    start_date::text as start_date,
    case when start_date ~ '^\d{4}-\d{2}-\d{2}$' then start_date::date
         when start_date ~ '^\d{4}-\d{2}$' then (start_date || '-01')::date end as start_date_parsed,
    primary_completion_date::text as primary_completion_date, completion_date::text as completion_date,
    sponsor::text as sponsor, sponsor_class::text as sponsor_class, enrollment::int as enrollment, enrollment_type::text as enrollment_type,
    results_posted::boolean as results_posted, conditions::text as conditions, interventions::text as interventions,
    study_type::text as study_type, last_update::text as last_update, matched_ingredients::text as matched_ingredients
from {{ source('raw', 'ctgov_studies') }}
