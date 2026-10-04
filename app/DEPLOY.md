# Publishing the budget impact app

Live app: https://01a108a8-ecde-397c-5353-39196812b10c.share.connect.posit.cloud/

The app is self-contained: `app.R`, `R/` (one module per tab, plus `bia.R`, the unchanged model engine) and aggregate CSVs in `data/` (numbers already public in the report; `analysis/scripts/45_check_app_data.R` checks each value against `analysis/outputs/key_numbers.csv`).
It needs no database, no credentials and only shiny, bslib and plotly (with their dependencies). `manifest.json` tells Posit Connect Cloud which packages to install; `tests/` is excluded from it.

## Posit Connect Cloud (from GitHub)
Publish, Shiny, repository `erickyegon/incretin-access-value`, branch `main`, primary file `app/app.R`. Connect Cloud republishes when `main` changes.

## Local run and tests
```r
shiny::runApp("app")        # from the repository root
```
- Unit tests: `Rscript --vanilla app/tests/testthat.R` (central case equals key_numbers, sensitivity endpoints equal the model's table, PSA reproducible, state-enrollment scaling, validation).
- Browser test of every tab and control in a clean R session: start `Rscript --vanilla -e 'shiny::runApp("app", port = 8765, launch.browser = FALSE)'`, then `NODE_PATH=<folder with puppeteer-core> node scripts/test/test_app.js` (set `APP_URL` to test the live app). `scripts/test/screenshot_app.js <folder>` saves screenshots of each tab (desktop and phone).
- Expected values for the browser test come from `Rscript --vanilla app/tests/expected_values.R`.

## After changing the model or inputs
Rerun `analysis/scripts/41_moduleE_model.R` (writes `app/R/bia.R`, `app/data/model_settings.csv` and `moduleC_effects.csv`), `46_app_data.R`, `45_check_app_data.R`, then regenerate the manifest with the files list used in the repository history (all of `app/` except `tests/`, `manifest.json` and `DEPLOY.md`) and commit.
