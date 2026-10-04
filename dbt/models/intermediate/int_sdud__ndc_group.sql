-- NDC -> analysis product group and dosage-form group. Grain: ndc11 (one row per product_map NDC).
-- product_group comes from the product_groups seed by the key brand|ingredient|label_group (brand-less generics use GENERIC).
-- dosage_form_group: tablet when the FDA/RxNorm dosage form names a tablet, injection when it names an injection, pen or auto-injector,
-- unknown when the product_map has no dosage form (some SDUD-only NDCs). Wegovy tablets and injections are separated by this column.
select
    pm.ndc11,
    pm.brand,
    pm.ingredient,
    pm.label_group,
    pm.dosage_form,
    case
        when upper(pm.dosage_form) like '%TABLET%' then 'tablet'
        when upper(pm.dosage_form) ~ 'INJECT|PEN' then 'injection'
        else 'unknown'
    end as dosage_form_group,
    pm.is_combination,
    pm.labeler_verified,
    pg.product_group,
    coalesce(nullif(pm.brand, ''), 'GENERIC ' || pm.ingredient) as brand_label
from {{ ref('product_map') }} pm
left join {{ ref('product_groups') }} pg
    on pg.product_group_key = coalesce(nullif(pm.brand, ''), 'GENERIC') || '|' || pm.ingredient || '|' || pm.label_group
