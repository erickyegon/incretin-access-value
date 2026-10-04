-- the two raw parts of the MEPS 2024 FYC file join one-to-one on DUPERSID: equal row counts, nobody missing from either part,
-- no duplicated DUPERSID in either part, and the staging view keeps every person
with p1 as (select "DUPERSID" as id from {{ source('raw', 'meps_fyc_2024_p1') }}),
     p2 as (select "DUPERSID" as id from {{ source('raw', 'meps_fyc_2024_p2') }}),
     stg as (select dupersid as id from {{ ref('stg_meps__fyc_2024') }})
select 'row counts differ' as problem, (select count(*) from p1) as a, (select count(*) from p2) as b
where (select count(*) from p1) <> (select count(*) from p2)
union all
select 'person in part 1 missing from part 2', count(*), null from p1 where id not in (select id from p2) having count(*) > 0
union all
select 'person in part 2 missing from part 1', count(*), null from p2 where id not in (select id from p1) having count(*) > 0
union all
select 'duplicate DUPERSID in part 1', count(*) - count(distinct id), null from p1 having count(*) > count(distinct id)
union all
select 'duplicate DUPERSID in part 2', count(*) - count(distinct id), null from p2 having count(*) > count(distinct id)
union all
select 'staging view row count differs from parts', (select count(*) from stg), (select count(*) from p1)
where (select count(*) from stg) <> (select count(*) from p1)
