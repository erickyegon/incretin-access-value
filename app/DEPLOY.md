# Publishing the budget impact app

The app is self-contained: `app.R`, `bia.R` (the model) and two small CSVs in `data/` (aggregate numbers already public in the report; each value is checked against `analysis/outputs/key_numbers.csv` by `analysis/scripts/45_check_app_data.R`).
It needs no database, no credentials and only the packages `shiny` and `ggplot2`. `manifest.json` (written with `rsconnect::writeManifest(appDir = "app")`) tells Posit Connect Cloud which packages to install.

## Posit Connect Cloud (from GitHub)
1. Sign in at connect.posit.cloud, choose **Publish**, then **Shiny**, and pick the GitHub repository `erickyegon/incretin-access-value` (branch `main`).
2. Select the primary file **`app/app.R`** (the folder `app/` holds `manifest.json`, so packages resolve from it).
3. Publish. The app URL is shown when the deployment finishes; send it to update the website, README and report.

## Local run and tests
```r
shiny::runApp("app")        # from the repository root; packages shiny and ggplot2
```
Browser test of every control in a clean R session: start `Rscript --vanilla -e 'shiny::runApp("app", port = 8765, launch.browser = FALSE)'`, then `NODE_PATH=<folder with puppeteer-core> node scripts/test/test_app.js`.

## After changing the model or inputs
Rerun `Rscript analysis/scripts/41_moduleE_model.R` (rewrites `app/bia.R` and `app/data/*.csv`), then `Rscript analysis/scripts/45_check_app_data.R`, then `Rscript --vanilla -e 'rsconnect::writeManifest(appDir = "app")'`, and commit.

## shinyapps.io (alternative)
`rsconnect::setAccountInfo(...)` with your own token (never commit it), then `rsconnect::deployApp("app", appName = "incretin-budget-impact")`.
