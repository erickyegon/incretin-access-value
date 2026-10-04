-- NPPES provider file (NPIs that appear in the Part D and Open Payments extracts). Grain: NPI.
-- primary_taxonomy_code is the first of the 15 taxonomy slots whose primary switch is 'Y' (NULL if none is flagged);
-- taxonomy_code_1 is kept as the fallback the registry lists first.
select
    "NPI"::text as npi,
    "Entity Type Code"::text as entity_type_code,
    nullif("Provider Credential Text", '')::text as credential_text,
    "Provider Business Practice Location Address State Name"::text as practice_state,
    left("Provider Business Practice Location Address Postal Code", 5)::text as practice_zip5,
    nullif("NPI Deactivation Date", '')::text as deactivation_date,
    nullif("Healthcare Provider Taxonomy Code_1", '')::text as taxonomy_code_1,
    coalesce(
{% for i in range(1, 16) %}
        case when "Healthcare Provider Primary Taxonomy Switch_{{ i }}" = 'Y' then nullif("Healthcare Provider Taxonomy Code_{{ i }}", '') end{% if not loop.last %},{% endif %}

{% endfor %}
    ) as primary_taxonomy_code
from {{ source('raw', 'nppes_provider') }}
