# Tab 3: build your scenario. Inputs live here; the module returns the scenario (parameters and model run) used by the other tabs.
state_choices <- function() stats::setNames(ENROLL$state_code, sprintf("%s: %s enrollees (%s)", ENROLL$state_name, num(ENROLL$enrollment), sub("Q", " Q", ENROLL$quarter_label)))

mod_budget_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::layout_sidebar(
    sidebar = bslib::sidebar(width = 380, open = "desktop",
      shiny::actionButton(ns("reset"), "Reset to the central case", class = "btn-outline-secondary btn-sm w-100"),
      bslib::accordion(open = c("Population", "Uptake"), multiple = TRUE,
        bslib::accordion_panel("Population",
          shiny::radioButtons(ns("plan_mode"), info("Plan size", "Number of Medicaid enrollees in the program. Type a size, or use a state's latest total Medicaid enrollment (average of monthly enrollment in the quarter shown)."), c("Enter a plan size" = "plan", "Use a state's Medicaid enrollment" = "state"), inline = FALSE),
          shiny::conditionalPanel(sprintf("input['%s'] == 'plan'", ns("plan_mode")), shiny::textInput(ns("plan"), NULL, value = "1,000,000"), shiny::tags$script(shiny::HTML("$(document).on('blur', 'input[id$=-plan]', function () { var v = this.value.replace(/[^0-9.]/g, ''); if (v !== '') { this.value = Number(v).toLocaleString('en-US', { maximumFractionDigits: 0 }); $(this).trigger('change'); } });"))),
          shiny::conditionalPanel(sprintf("input['%s'] == 'state'", ns("plan_mode")), shiny::selectInput(ns("state"), NULL, choices = state_choices(), selected = "CA")),
          shiny::textInput(ns("adult_share"), info("Adult share of enrollment (%)", "Share of Medicaid enrollees who are adults. Default: Medicaid enrollment data, 2024 Q3 to 2026 Q1 (measured). It sets the eligible pool only, not the cost."), value = sprintf("%.1f", 100 * INP$adult_share)),
          shiny::textInput(ns("elig_share"), info("Eligible share of adults (%)", "Share of Medicaid adults who meet the FDA label criteria, a lower bound from NHANES 2021-2023 (Module B). It sets the eligible pool (the ceiling), not the cost."), value = sprintf("%.1f", 100 * INP$eligible_share))),
        bslib::accordion_panel("Uptake",
          shiny::radioButtons(ns("effect"), info("Coverage effect", "Estimated extra prescriptions per 1,000 enrollees per quarter after coverage begins (Module C, difference-in-differences, 10 covering states against 34 never-covering). Choose the estimate or either end of its 95% confidence interval."),
                              c("Estimate" = "est", "Lower 95% CI" = "lo", "Upper 95% CI" = "hi"), inline = TRUE),
          shiny::sliderInput(ns("uptake"), info("Custom multiplier on the effect", "Scales the effect up or down (1.0 = as estimated). Use it for faster or slower uptake than the ten covering states showed. Assumption."), min = 0.5, max = 1.5, value = 1, step = 0.05),
          shiny::radioButtons(ns("y35"), info("Years 3 to 5", "No data exist beyond about nine quarters of coverage, so years 3 to 5 are scenarios: hold the quarter-8 level, extend the trend, or decline to half by quarter 20."),
                              c("Plateau at the quarter-8 level" = "plateau", "Continued growth" = "growth", "Decline to half by quarter 20" = "decline"))),
        bslib::accordion_panel("Access policy",
          shiny::sliderInput(ns("pa"), info("Prior authorization multiplier", "1.0 = as observed. The estimated effect already reflects the prior authorization rules of the 10 covering states (documented in 9 of 10), so 1.0 is the central case. Below 1.0 models tighter rules, above 1.0 looser rules. Assumption."), min = 0.5, max = 1.25, value = 1, step = 0.05),
          shiny::p(class = "small-note", "1.0 already reflects the prior authorization rules in the 10 covering states; 0.5 to 0.75 is tight and up to 1.25 is loose (assumptions).")),
        bslib::accordion_panel("Price and rebate",
          shiny::radioButtons(ns("price"), info("Price scenario", "Gross cost less a rebate you choose, or the announced $245 per monthly prescription taken as the net price (White House fact sheet, November 2025)."),
                              c("Gross cost less a rebate" = "rebate", "Announced $245 per monthly prescription (net)" = "announced")),
          shiny::sliderInput(ns("rebate"), info("Rebate share of gross cost, %", "23.1% is the statutory minimum Medicaid rebate (42 U.S.C. 1396r-8); 79.3% is the rebate implied by $245 at the 2025 gross cost. The central 51.2% is their midpoint and an assumption: actual net prices are confidential."), min = 0, max = 90, value = round(100 * INP$rebate$central, 3), step = 0.001, post = "%"),
          shiny::numericInput(ns("gross"), info("Gross cost per prescription, USD", "Observed Medicaid reimbursement per Wegovy or Zepbound prescription in covering states (State Drug Utilization Data, gross of rebates): $1,186 in 2025, range $1,164 to $1,252 across quarters."), value = round(INP$gross$central, 4), min = 100, max = 5000, step = 1)))),
    bslib::layout_columns(col_widths = bslib::breakpoints(sm = 12, lg = c(6, 6)),
      bslib::card(bslib::card_header(shiny::uiOutput(ns("title_rx"))), bslib::card_body(plotly::plotlyOutput(ns("rx_chart"), height = "280px")), bslib::card_footer(src_line("Source: Module C estimated effect (State Drug Utilization Data, Medicaid enrollment); years 3 to 5 are a scenario."))),
      bslib::card(bslib::card_header(shiny::uiOutput(ns("title_members"))), bslib::card_body(plotly::plotlyOutput(ns("members_chart"), height = "280px")), bslib::card_footer(src_line("Members treated = prescriptions divided by purchases per user-year (MEPS 4.3); pool = plan size x adult share x eligible share (NHANES, lower bound).")))),
    bslib::layout_columns(col_widths = bslib::breakpoints(sm = 12, lg = c(6, 6)),
      bslib::card(bslib::card_header(shiny::uiOutput(ns("title_annual"))), bslib::card_body(plotly::plotlyOutput(ns("annual_chart"), height = "280px")), bslib::card_footer(src_line("Gross = State Drug Utilization Data reimbursement (before rebates). Net applies the rebate or the announced price you chose."))),
      bslib::card(bslib::card_header(shiny::uiOutput(ns("title_waterfall"))), bslib::card_body(plotly::plotlyOutput(ns("waterfall_chart"), height = "280px")), bslib::card_footer(src_line("PMPM = per member per month, five-year average. Rebate and prior authorization (PA) steps are assumptions.")))),
    bslib::card(bslib::card_header("Results by year"), bslib::card_body(shiny::div(style = "overflow-x:auto", shiny::tableOutput(ns("table")))), bslib::card_footer(shiny::downloadButton(ns("download"), "Download CSV", class = "btn-outline-secondary btn-sm"), shiny::span(class = "small-note ms-2", "Scenario results, not forecasts; no medical cost offsets."))))
}

mod_budget_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    observeEvent(input$reset, {
      shiny::updateRadioButtons(session, "plan_mode", selected = "plan"); shiny::updateTextInput(session, "plan", value = "1,000,000"); shiny::updateSelectInput(session, "state", selected = "CA")
      shiny::updateTextInput(session, "adult_share", value = sprintf("%.1f", 100 * INP$adult_share)); shiny::updateTextInput(session, "elig_share", value = sprintf("%.1f", 100 * INP$eligible_share))
      shiny::updateRadioButtons(session, "effect", selected = "est"); shiny::updateSliderInput(session, "uptake", value = 1); shiny::updateRadioButtons(session, "y35", selected = "plateau"); shiny::updateSliderInput(session, "pa", value = 1)
      shiny::updateRadioButtons(session, "price", selected = "rebate"); shiny::updateSliderInput(session, "rebate", value = round(100 * INP$rebate$central, 3)); shiny::updateNumericInput(session, "gross", value = round(INP$gross$central, 4)) })
    params <- shiny::reactive({
      plan <- if (identical(input$plan_mode, "state")) ENROLL$enrollment[match(input$state, ENROLL$state_code)] else parse_plan(input$plan)
      shiny::validate(shiny::need(is.numeric(plan) && length(plan) == 1 && !is.na(plan) && plan >= 1000, "Enter a plan size of at least 1,000 enrollees."),
                      shiny::need(is.numeric(input$gross) && !is.na(input$gross) && input$gross >= 100, "Enter a gross cost per prescription of at least $100."),
                      shiny::need(is.numeric(input$rebate) && !is.na(input$rebate) && input$rebate >= 0 && input$rebate <= 95, "Choose a rebate between 0% and 95%."),
                      shiny::need({ a <- parse_plan(input$adult_share); length(a) == 1 && !is.na(a) && a > 0 && a <= 100 }, "The adult share must be between 0% and 100%."),
                      shiny::need({ a <- parse_plan(input$elig_share); length(a) == 1 && !is.na(a) && a > 0 && a <= 100 }, "The eligible share must be between 0% and 100%."))
      p <- BASE; p$plan <- plan; p$uptake_mult <- input$uptake; p$pa_mult <- input$pa; p$y35 <- input$y35; p$price <- input$price; p$rebate <- input$rebate / 100; p$gross <- input$gross
      p$adult_share <- share_value(input$adult_share, INP$adult_share); p$eligible_share <- share_value(input$elig_share, INP$eligible_share)
      p$att9 <- switch(input$effect, est = INP$att$estimate, lo = INP$att$ci_low, hi = INP$att$ci_high); p })
    run <- shiny::reactive(bia_run(params()))
    output$title_rx <- shiny::renderUI({ q <- run()$quarterly; sprintf("Incremental prescriptions reach about %s a quarter by quarter 9 (estimated effect), then follow the years 3 to 5 scenario", num(q$prescriptions[9])) })
    output$title_members <- shiny::renderUI({ a <- run()$annual; sprintf("About %s members are treated a year at the plateau, %s of the %s-member eligible pool", num(a$treated_members[5]), pct(a$treated_members[5] / a$eligible_pool[5]), num(a$eligible_pool[5])) })
    output$title_annual <- shiny::renderUI({ a <- run()$annual; sprintf("Net cost rises from %s in year 1 to %s in year 5 (gross %s)", usdm(a$net[1]), usdm(a$net[5]), usdm(a$gross[5])) })
    output$title_waterfall <- shiny::renderUI({ t <- run()$total; sprintf("A gross %s per member per month becomes %s net", usd2(t$pmpm_gross), usd2(t$pmpm_net)) })
    output$rx_chart <- plotly::renderPlotly(plot_quarterly_rx(run()))
    output$members_chart <- plotly::renderPlotly(plot_members(run(), params()))
    output$annual_chart <- plotly::renderPlotly(plot_annual(run()))
    output$waterfall_chart <- plotly::renderPlotly(plot_waterfall(params()))
    results_df <- shiny::reactive({ a <- run()$annual
      data.frame(Year = a$year, `Incremental prescriptions` = round(a$prescriptions), `Members treated` = round(a$treated_members), `Eligible pool` = round(a$eligible_pool), `Gross cost (USD)` = round(a$gross), `Net cost (USD)` = round(a$net), `Net PMPM (USD)` = round(a$pmpm_net, 2), check.names = FALSE) })
    output$table <- shiny::renderTable({ d <- results_df(); d$`Incremental prescriptions` <- num(d$`Incremental prescriptions`); d$`Members treated` <- num(d$`Members treated`); d$`Eligible pool` <- num(d$`Eligible pool`); d$`Gross cost (USD)` <- usd(d$`Gross cost (USD)`); d$`Net cost (USD)` <- usd(d$`Net cost (USD)`); d$`Net PMPM (USD)` <- sprintf("$%.2f", d$`Net PMPM (USD)`); d }, striped = TRUE, width = "100%")
    output$download <- shiny::downloadHandler(filename = function() "budget_scenario_results.csv", content = function(file) utils::write.csv(results_df(), file, row.names = FALSE))
    list(params = params, run = run)
  })
}
usd2 <- function(x) sprintf("$%.2f", x)
# plan size is typed with thousands separators; numbers pass through
parse_plan <- function(x) if (is.numeric(x)) x else suppressWarnings(as.numeric(gsub("[, ]", "", x)))
# the share boxes show one decimal (57.9, 52.0); if the box still shows the rounded default, the exact default is used so the central case is unchanged
share_value <- function(x, default) { x <- parse_plan(x); if (is.numeric(x) && length(x) == 1 && !is.na(x) && isTRUE(all.equal(x, round(100 * default, 1)))) default else x / 100 }
