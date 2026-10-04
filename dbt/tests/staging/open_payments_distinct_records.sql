-- distinct record IDs across all program years equal the documented 4,311,738 (and the two staged tables agree)
select 'general', count(distinct record_id), count(*) from {{ ref('stg_open_payments__general') }}
having count(distinct record_id) <> 4311738 or count(*) <> 4311738
union all
select 'record_products', count(distinct record_id), count(*) from {{ ref('stg_open_payments__record_products') }}
having count(distinct record_id) <> 4311738 or count(*) <> 4311738
