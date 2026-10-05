# Tab 1: the 30-second answer. The headline sentence, value boxes and chart update with the scenario built in Tab 3; defaults equal key_numbers.csv.
mod_overview_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    bslib::card(class = "mb-3", bslib::card_body(
      shiny::p(class = "text-uppercase small-note mb-1", "The question, the evidence, the decision, the uncertainty"),
      shiny::div(class = "headline", shiny::textOutput(ns("headline"), inline = TRUE)),
      shiny::p(class = "small-note mt-2 mb-0", "Estimates are associated with the coverage experience of 10 states (see the Evidence tab), scaled to your scenario. Scenarios, not forecasts; amounts are gross of rebates unless stated.")),
      bslib::card_footer(src_line("Source: project Modules C and E (State Drug Utilization Data, Medicaid enrollment, MEPS, NHANES); range = 90% interval of a 10,000-draw probabilistic analysis (see the Uncertainty tab for what it includes)."))),
    bslib::layout_columns(col_widths = bslib::breakpoints(sm = 6, md = 6, lg = 3), fill = FALSE,
      bslib::value_box(title = "Five-year net cost", value = shiny::textOutput(ns("v_net5")), shiny::textOutput(ns("v_net5_sub"))),
      bslib::value_box(title = "Net cost per member per month (PMPM)", value = shiny::textOutput(ns("v_pmpm")), shiny::textOutput(ns("v_pmpm_sub"))),
      bslib::value_box(title = "Members treated per year at the plateau", value = shiny::textOutput(ns("v_users")), shiny::textOutput(ns("v_users_sub"))),
      bslib::value_box(title = "Net cost per user per year", value = shiny::textOutput(ns("v_peruser")), shiny::textOutput(ns("v_peruser_sub")))),
    bslib::layout_columns(col_widths = bslib::breakpoints(sm = 12, lg = c(8, 4)),
      bslib::card(bslib::card_header(shiny::uiOutput(ns("title_chart"))), bslib::card_body(plotly::plotlyOutput(ns("chart"), height = "320px")), bslib::card_footer(src_line("Gross (light bar) is State Drug Utilization Data reimbursement before rebates; net (orange) applies your rebate or the announced $245 price."))),
      bslib::card(bslib::card_header("What drives this"), bslib::card_body(
        shiny::p(class = "small-note", "One-way swings in the five-year net cost around your scenario. Click to see all drivers."),
        shiny::uiOutput(ns("chips")),
        shiny::hr(), shiny::p(class = "mb-1", shiny::strong("Evidence behind the uptake")),
        shiny::p(class = "small-note", shiny::textOutput(ns("evidence_line"), inline = TRUE)),
        shiny::actionLink(ns("go_evidence"), "See the evidence →")))),
    bslib::card(class = "mt-3", bslib::card_header("How to use this app"), bslib::card_body(shiny::tags$ol(class = "mb-0",
      shiny::tags$li(shiny::strong("Evidence"), ": the estimated effect of coverage on prescriptions, by state, with robustness checks."),
      shiny::tags$li(shiny::strong("Budget model"), ": set the population, uptake, access policy and price; the Overview updates."),
      shiny::tags$li(shiny::strong("Uncertainty"), ": one-way sensitivity, a probabilistic analysis and the probability of staying within a budget."),
      shiny::tags$li(shiny::strong("Compare"), ": save up to three scenarios, or load a preset comparison."),
      shiny::tags$li(shiny::strong("Sources"), ": every assumption, labeled measured, sourced or assumed, with links."),
      shiny::tags$li("Hover any chart for values; hover the ⓘ marks for what an input means and where its default comes from; press 'Reset to the central case' in the Budget model tab to start over."))))
  )
}

mod_overview_server <- function(id, scn, go) {
  shiny::moduleServer(id, function(input, output, session) {
    psa <- shiny::reactive({ p <- scn$params(); psa_summary(psa_draws(INP, p)) }) |> shiny::bindCache(unlist(scn$params()[c("plan", "uptake_mult", "pa_mult", "y35", "price", "announced", "rebate", "gross", "fills")]))
    tor <- shiny::reactive({ tornado_table(INP, scn$params()) }) |> shiny::bindCache(unlist(scn$params()[c("plan", "uptake_mult", "pa_mult", "y35", "price", "rebate", "gross", "fills")]), paste(scn$params()$att9, collapse = ","))
    output$headline <- shiny::renderText({
      t <- scn$run()$total; s <- psa(); p <- scn$params()
      sprintf("Covering Wegovy and Zepbound for a %s Medicaid program is estimated to cost %s net over five years (%s per member per month), with a 90%% range of %s to %s.", plan_label(p$plan), usdm(t$five_year_net), usd2(t$pmpm_net), usdm(s[["p05"]]), usdm(s[["p95"]])) })
    output$v_net5 <- shiny::renderText(usdm(scn$run()$total$five_year_net))
    output$v_net5_sub <- shiny::renderText(sprintf("gross %s before rebates", usdm(scn$run()$total$five_year_gross)))
    output$v_pmpm <- shiny::renderText(usd2(scn$run()$total$pmpm_net))
    output$v_pmpm_sub <- shiny::renderText(sprintf("gross %s", usd2(scn$run()$total$pmpm_gross)))
    output$v_users <- shiny::renderText(num(scn$run()$annual$treated_members[5]))
    output$v_users_sub <- shiny::renderText({ a <- scn$run()$annual; sprintf("%s of the %s-member eligible pool", pct(a$treated_members[5] / a$eligible_pool[5]), num(a$eligible_pool[5])) })
    output$v_peruser <- shiny::renderText(usd(scn$run()$total$net_cost_per_user_year))
    output$v_peruser_sub <- shiny::renderText(sprintf("%s per member-year of continuous treatment (12 fills)", usd(scn$run()$total$net_cost_per_member_year_continuous)))
    output$title_chart <- shiny::renderUI({ a <- scn$run()$annual; sprintf("Annual net cost: %s in year 1, %s in year 3, %s in year 5", usdm(a$net[1]), usdm(a$net[3]), usdm(a$net[5])) })
    output$chart <- plotly::renderPlotly(plot_annual(scn$run()))
    output$chips <- shiny::renderUI({
      t <- tor(); pick <- function(pat) t[grepl(pat, t$parameter), ][1, ]
      mk <- function(lbl, r) shiny::actionButton(session$ns(paste0("chip_", gsub("[^a-z]", "", tolower(lbl)))), sprintf("%s: %s to %s", lbl, usdm(min(r$net_low, r$net_high)), usdm(max(r$net_low, r$net_high))), class = "chip d-block mb-2 text-start")
      shiny::tagList(mk("Coverage effect", pick("^Module C")), mk("Rebate", pick("^Rebate")), mk("Prior authorization", pick("^Prior")))
    })
    shiny::observeEvent(input$chip_coverageeffect, go("uncertainty")); shiny::observeEvent(input$chip_rebate, go("uncertainty")); shiny::observeEvent(input$chip_priorauthorization, go("uncertainty"))
    shiny::observeEvent(input$go_evidence, go("evidence"))
    output$evidence_line <- shiny::renderText(sprintf("The uptake path is an estimated effect of %s prescriptions per 1,000 enrollees per quarter (95%% CI %s), from %s covering and %s never-covering jurisdictions, and it holds in %s alternative analyses.", kf("c_att_overall"), kf_ci("c_att_overall"), kf("c_states_primary"), kf("c_states_never"), spec_all()))
  })
}
