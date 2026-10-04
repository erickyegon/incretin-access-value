-- suppressed rows carry no counts, units or amounts; unsuppressed rows never show a count of 1 to 10 (CMS suppresses under 11)
select 'state' as model, state_code, ndc11, year, quarter from {{ ref('stg_sdud__state') }}
where (suppressed and (number_of_prescriptions is not null or units_reimbursed is not null or total_amount_reimbursed is not null))
   or (not suppressed and (number_of_prescriptions is null or number_of_prescriptions between 1 and 10))
union all
select 'national', state_code, ndc11, year, quarter from {{ ref('stg_sdud__national') }}
where (suppressed and (number_of_prescriptions is not null or units_reimbursed is not null or total_amount_reimbursed is not null))
   or (not suppressed and (number_of_prescriptions is null or number_of_prescriptions between 1 and 10))
