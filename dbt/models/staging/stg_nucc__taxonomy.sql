-- NUCC Health Care Provider Taxonomy code set. Grain: taxonomy code.
select
    "Code"::text as taxonomy_code,
    "Grouping"::text as grouping,
    "Classification"::text as classification,
    nullif("Specialization", '')::text as specialization,
    "Display Name"::text as display_name,
    "Section"::text as section
from {{ source('raw', 'nucc_taxonomy') }}
