# Tab 5: compare up to three saved scenarios, or load a preset comparison (built from the central case, not from your current inputs).
scenario_row <- function(name, p) { t <- bia_run(p)$total; data.frame(name = name, five_year_net = t$five_year_net, five_year_gross = t$five_year_gross, pmpm_net = t$pmpm_net, net_cost_per_user_year = t$net_cost_per_user_year,
                                                                     prior_authorization = p$pa_mult, years_3_to_5 = p$y35, price = if (identical(p$price, "announced")) "announced $245" else sprintf("rebate %.1f%%", 100 * p$rebate), plan_size = p$plan, stringsAsFactors = FALSE) }
preset_rows <- function(which) {
  b <- BASE; mk <- function(nm, ...) { p <- b; a <- list(...); for (k in names(a)) p[[k]] <- a[[k]]; scenario_row(nm, p) }
  if (which == "pa") rbind(mk("Tight prior authorization (0.5)", pa_mult = 0.5), mk("As observed (1.0)", pa_mult = 1), mk("Loose prior authorization (1.25)", pa_mult = 1.25))
  else rbind(mk("Statutory-minimum rebate (23.1%)", rebate = INP$rebate$low), mk("Central rebate (51.2%)"), mk("Announced $245 price", price = "announced"))
}

mod_compare_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    bslib::card(bslib::card_header("Build a comparison"), bslib::card_body(bslib::layout_columns(col_widths = bslib::breakpoints(sm = 12, md = c(5, 7)),
      shiny::div(shiny::textInput(ns("name"), info("Scenario name", "A label for the scenario you built in the Budget model tab."), placeholder = "for example, loose PA with $245"), shiny::actionButton(ns("save"), "Save the current scenario", class = "btn-primary btn-sm"), shiny::actionButton(ns("clear"), "Clear", class = "btn-outline-secondary btn-sm ms-2")),
      shiny::div(shiny::p(class = "mb-1", shiny::strong("Preset comparisons")), shiny::actionButton(ns("preset_pa"), "Tight vs as observed vs loose prior authorization", class = "btn-outline-secondary btn-sm mb-2"), shiny::br(),
                 shiny::actionButton(ns("preset_price"), "Statutory-minimum rebate vs central vs $245 price", class = "btn-outline-secondary btn-sm"))))),
    bslib::card(class = "mt-3", bslib::card_header(shiny::uiOutput(ns("title"))), bslib::card_body(plotly::plotlyOutput(ns("chart"), height = "300px"), shiny::div(style = "overflow-x:auto", shiny::tableOutput(ns("table")))),
      bslib::card_footer(shiny::downloadButton(ns("download"), "Download comparison CSV", class = "btn-outline-secondary btn-sm"), shiny::span(class = "small-note ms-2", "Up to three scenarios. Presets start from the central case; saved scenarios use your inputs in the Budget model tab. Scenarios, not forecasts.")))
  )
}

mod_compare_server <- function(id, scn) {
  shiny::moduleServer(id, function(input, output, session) {
    store <- shiny::reactiveVal(preset_rows("pa"))
    shiny::observeEvent(input$save, {
      cur <- store(); nm <- trimws(input$name); if (!nzchar(nm)) nm <- paste("Scenario", (if (is.null(cur)) 0 else nrow(cur)) + 1)
      if (!is.null(cur) && nrow(cur) >= 3) { shiny::showNotification("Three scenarios are saved. Clear one or press Clear to start again.", type = "warning"); return() }
      p <- try(scn$params(), silent = TRUE); if (inherits(p, "try-error")) { shiny::showNotification("Fix the inputs in the Budget model tab first.", type = "warning"); return() }
      store(rbind(cur, scenario_row(nm, p))) })
    shiny::observeEvent(input$clear, store(NULL))
    shiny::observeEvent(input$preset_pa, store(preset_rows("pa"))); shiny::observeEvent(input$preset_price, store(preset_rows("price")))
    output$title <- shiny::renderUI({ d <- store(); if (is.null(d)) "Saved scenarios appear here" else if (nrow(d) == 1) sprintf("Saved scenario: five-year net cost of %s", usdm(d$five_year_net)) else sprintf("Five-year net cost ranges from %s to %s across %d scenarios", usdm(min(d$five_year_net)), usdm(max(d$five_year_net)), nrow(d)) })
    output$chart <- plotly::renderPlotly({ d <- store(); shiny::validate(shiny::need(!is.null(d), "Save a scenario, or load a preset comparison.")); plot_compare(d) })
    output$table <- shiny::renderTable({ d <- store(); shiny::req(d); data.frame(Scenario = d$name, `Five-year net` = usdm(d$five_year_net), `Five-year gross` = usdm(d$five_year_gross), PMPM = usd2(d$pmpm_net), `Net per user per year` = usd(d$net_cost_per_user_year), `Prior authorization` = d$prior_authorization, `Years 3-5` = d$years_3_to_5, Price = d$price, check.names = FALSE) }, striped = TRUE, width = "100%")
    output$download <- shiny::downloadHandler(filename = function() "scenario_comparison.csv", content = function(file) { d <- store(); utils::write.csv(if (is.null(d)) data.frame() else d, file, row.names = FALSE) })
  })
}
