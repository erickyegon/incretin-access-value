-- SDUD totals reconcile from staging to the marts (panel states, combinations excluded): prescriptions exactly, amounts in whole cents,
-- units in thousandths; ALL equals FFSU + MCOU; the panel agrees with the long mart; the national-residual model sees the same state rows
with stg as (
    select
        s.utilization_type,
        sum(s.number_of_prescriptions) as rx,
        round(sum(s.total_amount_reimbursed) * 100)::bigint as amount_total_cents,
        round(sum(s.medicaid_amount_reimbursed) * 100)::bigint as amount_medicaid_cents,
        round(sum(s.units_reimbursed) * 1000)::bigint as units_milli,
        count(*) filter (where s.suppressed) as n_suppressed
    from {{ ref('stg_sdud__state') }} s
    join {{ ref('int_sdud__ndc_group') }} g on g.ndc11 = s.ndc11 and g.product_group <> 'combination_excluded'
    join {{ ref('states') }} st on st.state_code = s.state_code and st.in_panel
    group by 1
),
stg_all as (
    select 'ALL' as utilization_type, sum(rx) as rx, sum(amount_total_cents) as amount_total_cents, sum(amount_medicaid_cents) as amount_medicaid_cents,
           sum(units_milli) as units_milli, sum(n_suppressed) as n_suppressed from stg
),
stg_u as (select * from stg union all select * from stg_all),
mart as (
    select utilization_type, sum(rx_observed) as rx, round(sum(amount_total_observed) * 100)::bigint as amount_total_cents,
           round(sum(amount_medicaid_observed) * 100)::bigint as amount_medicaid_cents, round(sum(units_observed) * 1000)::bigint as units_milli,
           sum(n_suppressed_rows) as n_suppressed
    from {{ ref('mart_sdud_state_quarter_long') }} group by 1
)
select s.utilization_type, 'staging vs mart' as problem
from stg_u s left join mart m on m.utilization_type = s.utilization_type
where m.rx is distinct from s.rx or m.amount_total_cents is distinct from s.amount_total_cents or m.amount_medicaid_cents is distinct from s.amount_medicaid_cents
   or m.units_milli is distinct from s.units_milli or m.n_suppressed is distinct from s.n_suppressed
union all
select 'panel', 'panel prescriptions differ from long mart (ALL)'
where (select sum(rx_obesity_wz_observed + rx_obesity_saxenda_observed + rx_obesity_other_observed + rx_diabetes_glp1_observed) from {{ ref('mart_did_panel') }})
   <> (select sum(rx_observed) from {{ ref('mart_sdud_state_quarter_long') }} where utilization_type = 'ALL')
union all
select 'national', 'state prescriptions in the residual model differ from staging (all jurisdictions, no combinations)'
where (select sum(state_rx_observed) from {{ ref('int_sdud__national_residual') }})
   <> (select sum(s.number_of_prescriptions) from {{ ref('stg_sdud__state') }} s
       join {{ ref('int_sdud__ndc_group') }} g on g.ndc11 = s.ndc11 and g.product_group <> 'combination_excluded')
