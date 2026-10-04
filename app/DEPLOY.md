# Deploying the budget impact app (not done: it needs your account)

The app runs locally with `shiny::runApp("app")` from the repository root (R 4.6.1; packages `shiny` and `ggplot2`). It is self-contained: `app.R`, `bia.R` (the model) and `data/moduleE_inputs.rds`.
It contains no raw or interim data and no credentials.

## Posit Connect Cloud
1. Push this repository (or only the `app/` folder) to a GitHub repository you control; the project has no remote yet, so create one first.
2. In Posit Connect Cloud choose Publish, pick the repository, set the primary file to `app/app.R`, and let it resolve packages (add a `manifest.json` with `rsconnect::writeManifest(appDir = "app")` from R if asked).
3. Publish; the app URL is shown when the deployment finishes.

## shinyapps.io
1. `install.packages("rsconnect")`, then `rsconnect::setAccountInfo(name = "<account>", token = "<token>", secret = "<secret>")` with the values from your shinyapps.io dashboard (keep them out of the repository).
2. `rsconnect::deployApp("app", appName = "incretin-budget-impact")` from the repository root.
3. Open the URL it prints. To update later, run the same call again.

Before deploying, rerun `Rscript analysis/scripts/41_moduleE_model.R` so `app/data/` and `app/bia.R` match the analysis.
