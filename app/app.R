# Medicaid GLP-1 Coverage: Budget Impact and Evidence. A decision tool built on the incretin access-and-value project (Modules B, C and E).
# Thin entry point: the model engine is R/bia.R (unchanged logic), one Shiny module per tab is in R/mod_*.R, charts in R/plots.R, sensitivity analysis in R/psa.R, the theme in R/theme.R and the data in data/ (small aggregate CSVs).
# Shiny loads everything in R/ automatically. Packages: shiny, bslib, plotly. Scenarios, not forecasts; amounts are gross of rebates unless stated.
library(shiny)
library(bslib)
library(plotly)

ui <- page_navbar(
  id = "main_nav", theme = app_theme, lang = "en", fillable = FALSE, window_title = "Medicaid GLP-1 Coverage: Budget Impact and Evidence",
  title = tags$span(class = "navbar-brand mb-0 py-1", "Medicaid GLP-1 Coverage: Budget Impact and Evidence", tags$span(class = "sub", "Erick Kiprotich Yegon · Epidemiologist and data scientist")),
  nav_panel("Overview", value = "overview", div(class = "container-xl py-3", mod_overview_ui("overview"))),
  nav_panel("Evidence", value = "evidence", div(class = "container-xl py-3", mod_evidence_ui("evidence"))),
  nav_panel("Budget model", value = "budget", div(class = "container-xl py-3", mod_budget_ui("budget"))),
  nav_panel("Uncertainty", value = "uncertainty", div(class = "container-xl py-3", mod_uncertainty_ui("uncertainty"))),
  nav_panel("Compare", value = "compare", div(class = "container-xl py-3", mod_compare_ui("compare"))),
  nav_panel("Sources", value = "sources", div(class = "container-xl py-3", mod_sources_ui("sources"))),
  nav_spacer(),
  nav_item(tags$a("Project site", href = SITE, target = "_blank")), nav_item(tags$a("Report", href = paste0(SITE, "report.html"), target = "_blank")), nav_item(tags$a("Code", href = REPO, target = "_blank")),
  footer = div(class = "container-xl small-note py-3 border-top mt-3",
    "Public aggregate data; no company affiliation or endorsement; not patient-level claims. Scenarios, not forecasts; gross of rebates unless stated. I used AI tools to help write code and documentation. The study design, methods and conclusions are my own, and I verified all results.")
)

server <- function(input, output, session) {
  go <- function(tab) nav_select("main_nav", tab, session = session)
  scn <- mod_budget_server("budget")
  mod_overview_server("overview", scn, go)
  mod_evidence_server("evidence", go)
  mod_uncertainty_server("uncertainty", scn)
  mod_compare_server("compare", scn)
  mod_sources_server("sources")
}
shinyApp(ui, server)
