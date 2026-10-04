# Module C analysis (R)

- R version: 4.6.1 (2026), packages pinned in `renv.lock` (`renv::restore()` rebuilds the library). `fwildclusterboot` is installed from the author's r-universe repository because it is not on CRAN.
- Data: warehouse marts only, read through `get_mart()` in `R/db.R` (same environment-variable credentials as dbt: `INCRETIN_PG_PASSWORD`; the local server uses trust authentication).
- Run everything: `cd analysis` then `Rscript run_all.R`. One numbered script per step in `scripts/`; tables go to `outputs/tables` (CSV plus gt HTML), figures to `outputs/figures` (PNG 300 dpi and SVG).
- Seeds: every bootstrap and imputation sets and records its seed in its script (model scripts, after Checkpoint A).
- Plan: `analysis_plan_moduleC.md` (pre-specified; changes after results are logged in `outputs/deviations.md`).
- No output contains a suppressed SDUD cell value or a cell-level count under 11; outputs are aggregated to state-quarter rates or larger.
