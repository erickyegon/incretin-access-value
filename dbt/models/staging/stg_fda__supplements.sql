-- Drugs@FDA submissions (original applications and supplements). Grain: application number x submission type x submission number.
-- SubmissionType is padded in the source and SubmissionNo has mixed dtypes; both are normalised here.
select
    "ApplNo"::text as application_number,
    trim("SubmissionType")::text as submission_type,
    nullif(regexp_replace(trim("SubmissionNo"::text), '\.0$', ''), '')::int as submission_no,
    trim("SubmissionStatus")::text as submission_status,
    "SubmissionStatusDate"::date as submission_status_date,
    trim("ReviewPriority")::text as review_priority,
    trim("SubmissionClassCode")::text as submission_class_code,
    trim("SubmissionClassCodeDescription")::text as submission_class_description
from {{ source('raw', 'fda_submissions') }}
