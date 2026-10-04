select * from {{ ref('stg_sdud__state') }} where state_code = 'XX'
