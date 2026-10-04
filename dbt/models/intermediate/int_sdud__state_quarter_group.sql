-- SDUD state rows aggregated to state x quarter x utilization type x product group x dosage-form group, panel states only (territories
-- and the national XX rows are excluded; combination products are excluded). Grain: state_code x year x quarter x utilization_type x
-- product_group x dosage_form_group, with utilization_type FFSU, MCOU and ALL (ALL = FFSU + MCOU: never add ALL to the other two).
-- Suppression: counts of 1 to 10 are NULL in the source. Nothing is imputed here:
--   rx_observed      = sum of the unsuppressed prescription counts
--   n_suppressed_rows = number of suppressed state-NDC rows (each is 1 to 10 prescriptions; 0 to 10 treated as possible)
--   rx_upper_bound   = rx_observed + 10 x n_suppressed_rows
--   units / amounts  = observed sums, plus an upper bound that gives each suppressed row 10 prescriptions at the highest per-prescription
--                      units (or amount) seen for that NDC in unsuppressed state rows; NULL when some suppressed row's NDC has no
--                      unsuppressed row to take that ratio from (units_bound_complete = false).
-- Cells with no SDUD row at all are absent here (SDUD lists a state-NDC-quarter only when it has utilization).
with rows_ as (
    select
        s.state_code, s.year, s.quarter, s.quarter_start, s.is_preliminary, s.utilization_type, s.ndc11, s.suppressed,
        g.product_group, g.dosage_form_group,
        s.number_of_prescriptions, s.units_reimbursed, s.total_amount_reimbursed, s.medicaid_amount_reimbursed
    from {{ ref('stg_sdud__state') }} s
    join {{ ref('int_sdud__ndc_group') }} g on g.ndc11 = s.ndc11
    join {{ ref('states') }} st on st.state_code = s.state_code and st.in_panel
    where g.product_group <> 'combination_excluded'
),
ratio as (
    select ndc11,
        max(units_reimbursed / nullif(number_of_prescriptions, 0)) as max_units_per_rx,
        max(total_amount_reimbursed / nullif(number_of_prescriptions, 0)) as max_total_amount_per_rx,
        max(medicaid_amount_reimbursed / nullif(number_of_prescriptions, 0)) as max_medicaid_amount_per_rx
    from rows_
    where not suppressed
    group by 1
),
base as (
    select
        r.state_code, r.year, r.quarter, r.quarter_start, r.is_preliminary, r.utilization_type, r.product_group, r.dosage_form_group,
        count(*) as n_rows,
        count(*) filter (where r.suppressed) as n_suppressed_rows,
        coalesce(sum(r.number_of_prescriptions), 0) as rx_observed,
        coalesce(sum(r.units_reimbursed), 0) as units_observed,
        coalesce(sum(r.total_amount_reimbursed), 0) as amount_total_observed,
        coalesce(sum(r.medicaid_amount_reimbursed), 0) as amount_medicaid_observed,
        sum(10 * ra.max_units_per_rx) filter (where r.suppressed) as units_suppressed_bound,
        sum(10 * ra.max_total_amount_per_rx) filter (where r.suppressed) as amount_total_suppressed_bound,
        sum(10 * ra.max_medicaid_amount_per_rx) filter (where r.suppressed) as amount_medicaid_suppressed_bound,
        count(*) filter (where r.suppressed and ra.max_units_per_rx is null) as n_suppressed_rows_without_ratio
    from rows_ r
    left join ratio ra on ra.ndc11 = r.ndc11
    group by 1, 2, 3, 4, 5, 6, 7, 8
),
all_util as (
    select
        state_code, year, quarter, quarter_start, is_preliminary, 'ALL'::text as utilization_type, product_group, dosage_form_group,
        sum(n_rows) as n_rows, sum(n_suppressed_rows) as n_suppressed_rows, sum(rx_observed) as rx_observed,
        sum(units_observed) as units_observed, sum(amount_total_observed) as amount_total_observed, sum(amount_medicaid_observed) as amount_medicaid_observed,
        sum(units_suppressed_bound) as units_suppressed_bound, sum(amount_total_suppressed_bound) as amount_total_suppressed_bound,
        sum(amount_medicaid_suppressed_bound) as amount_medicaid_suppressed_bound,
        sum(n_suppressed_rows_without_ratio) as n_suppressed_rows_without_ratio
    from base
    group by 1, 2, 3, 4, 5, 6, 7, 8
),
stacked as (select * from base union all select * from all_util)
select
    state_code, year, quarter, quarter_start, is_preliminary, utilization_type, product_group, dosage_form_group,
    n_rows::int as n_rows,
    n_suppressed_rows::int as n_suppressed_rows,
    rx_observed,
    rx_observed + 10 * n_suppressed_rows as rx_upper_bound,
    units_observed,
    case when n_suppressed_rows = 0 then units_observed
         when n_suppressed_rows_without_ratio = 0 then units_observed + units_suppressed_bound end as units_upper_bound,
    amount_total_observed,
    case when n_suppressed_rows = 0 then amount_total_observed
         when n_suppressed_rows_without_ratio = 0 then amount_total_observed + amount_total_suppressed_bound end as amount_total_upper_bound,
    amount_medicaid_observed,
    case when n_suppressed_rows = 0 then amount_medicaid_observed
         when n_suppressed_rows_without_ratio = 0 then amount_medicaid_observed + amount_medicaid_suppressed_bound end as amount_medicaid_upper_bound,
    (n_suppressed_rows_without_ratio = 0) as units_bound_complete
from stacked
