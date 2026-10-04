-- every prescriber row has a specialty group from the fixed list, and the CMS-type group is never null
select prescriber_npi, data_year, specialty_group from {{ ref('mart_prescriber_year') }}
where specialty_group is null or specialty_group not in ('Primary care physicians', 'Nurse practitioners and physician assistants', 'Endocrinology', 'Cardiology', 'Other')
union all
select prescriber_npi, data_year, specialty_group_nppes from {{ ref('mart_prescriber_year') }}
where specialty_group_nppes is not null and specialty_group_nppes not in ('Primary care physicians', 'Nurse practitioners and physician assistants', 'Endocrinology', 'Cardiology', 'Other')
