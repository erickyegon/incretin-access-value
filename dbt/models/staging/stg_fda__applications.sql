-- Drugs@FDA applications joined to their products. Grain: application number x product number.
select
    a."ApplNo"::text as application_number, a."ApplType"::text as application_type, a."SponsorName"::text as sponsor_name,
    p."ProductNo"::text as product_no, p."Form"::text as form, p."Strength"::text as strength, p."DrugName"::text as drug_name,
    p."ActiveIngredient"::text as active_ingredient
from {{ source('raw', 'fda_applications') }} a
left join {{ source('raw', 'fda_products') }} p on p."ApplNo" = a."ApplNo"
