-- National (XX) prescriptions against the sum of the state rows, per NDC, quarter and utilization type. Grain: ndc11 x year x quarter x
-- utilization_type (FFSU, MCOU). State rows of ALL jurisdictions are summed (territories included) because the national row covers every
-- reporting jurisdiction. Combination products are excluded.
-- residual_rx = national prescriptions - observed state prescriptions: the volume sitting in suppressed state rows (plus any rounding or
-- reporting differences). residual_usable = the national row is unsuppressed and the residual is positive. Nothing is allocated here.
-- residual_within_bounds checks the residual against what the suppressed state rows could hold: between 0 and 10 x n_state_suppressed.
with nat as (
    select ndc11, year, quarter, utilization_type, suppressed as national_suppressed, number_of_prescriptions as national_rx, is_preliminary
    from {{ ref('stg_sdud__national') }}
),
st as (
    select
        ndc11, year, quarter, utilization_type,
        count(*) as n_state_rows,
        count(*) filter (where suppressed) as n_state_suppressed,
        coalesce(sum(number_of_prescriptions), 0) as state_rx_observed
    from {{ ref('stg_sdud__state') }}
    group by 1, 2, 3, 4
)
select
    coalesce(n.ndc11, s.ndc11) as ndc11,
    coalesce(n.year, s.year) as year,
    coalesce(n.quarter, s.quarter) as quarter,
    coalesce(n.utilization_type, s.utilization_type) as utilization_type,
    g.product_group, g.dosage_form_group,
    (n.ndc11 is not null) as has_national_row,
    n.national_suppressed,
    n.national_rx,
    coalesce(s.n_state_rows, 0)::int as n_state_rows,
    coalesce(s.n_state_suppressed, 0)::int as n_state_suppressed,
    coalesce(s.state_rx_observed, 0) as state_rx_observed,
    n.national_rx - coalesce(s.state_rx_observed, 0) as residual_rx,
    (n.ndc11 is not null and not n.national_suppressed and n.national_rx - coalesce(s.state_rx_observed, 0) > 0) as residual_usable,
    case when n.national_rx is not null
         then n.national_rx - coalesce(s.state_rx_observed, 0) between 0 and 10 * coalesce(s.n_state_suppressed, 0) end as residual_within_bounds
from nat n
full outer join st s on s.ndc11 = n.ndc11 and s.year = n.year and s.quarter = n.quarter and s.utilization_type = n.utilization_type
join {{ ref('int_sdud__ndc_group') }} g on g.ndc11 = coalesce(n.ndc11, s.ndc11)
where g.product_group <> 'combination_excluded'
