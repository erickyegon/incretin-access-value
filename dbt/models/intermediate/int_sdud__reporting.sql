-- SDUD reporting completeness by panel state x quarter x utilization type (FFSU, MCOU), judged on ALL drugs (not only incretins).
-- SDUD omits a state-NDC-quarter that has no utilization, so a state-quarter with no row at all means the state did not report that
-- type of utilization that quarter (a false zero if read as zero prescriptions).
--   not_reported  zero rows across all drugs for the state, quarter and utilization type
--   anomalous     reported, but the all-drug prescription count is below 50% of the median of the four nearest other quarters of the same
--                 state and type (two before and two after; at either end the four nearest available quarters). A median of 0 cannot flag.
-- Prescription counts are the unsuppressed sums (suppressed rows are 1 to 10 each and add nothing), which is also the comparison basis.
-- Grain: state_code x year x quarter x utilization_type (51 x 33 x 2). No row is dropped or changed: the analysis decides how to handle flags.
with grid as (
    select s.state_code, q.year, q.quarter, q.quarter_label, q.quarter_start, row_number() over (order by q.quarter_start) as qi, t.utilization_type
    from {{ ref('states') }} s cross join {{ ref('quarters') }} q cross join (values ('FFSU'), ('MCOU')) as t(utilization_type)
    where s.in_panel
),
joined as (
    select g.*, coalesce(r.n_rows, 0) as n_rows, coalesce(r.n_suppressed_rows, 0) as n_suppressed_rows, coalesce(r.n_ndcs, 0) as n_ndcs,
           coalesce(r.rx_observed, 0) as rx_observed_all_drugs
    from grid g
    left join {{ ref('sdud_reporting') }} r
        on r.state = g.state_code and r.year = g.year and r.quarter = g.quarter and r.utilization_type = g.utilization_type
),
nbr as (
    select a.state_code, a.utilization_type, a.qi,
           b.rx_observed_all_drugs as nbr_rx,
           row_number() over (partition by a.state_code, a.utilization_type, a.qi order by abs(b.qi - a.qi), b.qi) as rk
    from joined a join joined b on b.state_code = a.state_code and b.utilization_type = a.utilization_type and b.qi <> a.qi and abs(b.qi - a.qi) <= 4
),
med as (
    select state_code, utilization_type, qi, percentile_cont(0.5) within group (order by nbr_rx) as neighbour_median_rx, count(*) as n_neighbours
    from nbr where rk <= 4 group by 1, 2, 3
)
select
    j.state_code, j.year, j.quarter, j.quarter_label, j.quarter_start, j.utilization_type,
    j.n_rows, j.n_suppressed_rows, j.n_ndcs, j.rx_observed_all_drugs,
    m.neighbour_median_rx, m.n_neighbours,
    (j.n_rows = 0) as not_reported,
    (j.n_rows > 0 and m.neighbour_median_rx > 0 and j.rx_observed_all_drugs < 0.5 * m.neighbour_median_rx) as anomalous
from joined j
left join med m on m.state_code = j.state_code and m.utilization_type = j.utilization_type and m.qi = j.qi
