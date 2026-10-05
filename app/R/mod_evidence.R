# Tab 2: the evidence behind the uptake input: the project's own causal estimate of what coverage did, state by state, with robustness checks.
mod_evidence_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    bslib::layout_columns(col_widths = bslib::breakpoints(sm = 12, lg = c(7, 5)),
      bslib::card(bslib::card_header(shiny::textOutput(ns("title_es"), inline = TRUE)), bslib::card_body(plotly::plotlyOutput(ns("es_chart"), height = "340px")),
        bslib::card_footer(src_line("Source: CMS State Drug Utilization Data and Medicaid enrollment; Callaway and Sant'Anna estimator, state clusters, 20 imputations of suppressed cells combined with Rubin's rules. Pointwise 95% CIs. Part of the later growth is national market growth."))),
      bslib::card(bslib::card_header("Where coverage began: click or hover a state"), bslib::card_body(plotly::plotlyOutput(ns("map"), height = "360px"), shiny::uiOutput(ns("state_detail"))),
        bslib::card_footer(src_line("Source: state Medicaid documents and CMS approvals (docs/sources_index.csv); criteria table in the report. Orange cohorts = year coverage began (primary analysis); outlined white = sensitivity states; grey = never covered.")))),
    bslib::card(class = "mt-3", bslib::card_header(shiny::textOutput(ns("title_state"), inline = TRUE)),
      bslib::card_body(shiny::selectInput(ns("state"), "State", choices = state_selector(), selected = "AVG", width = "320px"), plotly::plotlyOutput(ns("state_chart"), height = "300px")),
      bslib::card_footer(src_line("Source: State Drug Utilization Data and Medicaid enrollment. Observed (unsuppressed) Wegovy and Zepbound prescriptions per 1,000 enrollees, so rates are lower bounds; the grey line is the observed mean of the never-covering states. The average is the simple mean of the covering states' observed rates by calendar quarter (states began coverage at different dates). Dotted line = coverage start."))),
    bslib::layout_columns(col_widths = bslib::breakpoints(sm = 12, lg = c(7, 5)), class = "mt-3",
      bslib::card(bslib::card_header(shiny::textOutput(ns("title_spec"), inline = TRUE)), bslib::card_body(plotly::plotlyOutput(ns("spec_chart"), height = "430px")),
        bslib::card_footer(src_line(sprintf("Source: Module C specification table (95%% CIs). Fee-for-service only (specification 12) is not estimable. Placebo: coverage moved four quarters earlier gives %s (95%% CI %s), no effect.", kf("c_placebo"), kf_ci("c_placebo"))))),
      shiny::div(
        shiny::div(class = "callout mb-3", shiny::strong("Managed care is where coverage operates. "), sprintf("In South Carolina and Rhode Island, uptake runs almost entirely through managed-care organizations: %s%% of South Carolina's observed prescriptions in 2025 Q3 and %s%% in every Rhode Island quarter. A fee-for-service-only estimate is not reliable; a managed-care-only estimate is %s per 1,000 managed-care enrollees (95%% CI %s).", kf("m_sc_mcou_share"), kf("m_ri_mcou_share"), kf("c_spec14"), kf_ci("c_spec14"))),
        shiny::div(class = "callout", shiny::strong("First withdrawals are preliminary. "), sprintf("After coverage ended, prescriptions per enrollee fell by %s%% in California and %s%% in Pennsylvania from 2025 Q4 to 2026 Q1 (descriptive; 2026 Q1 is a preliminary quarter).", kf("c_withdraw_ca"), kf("c_withdraw_pa"))),
        shiny::p(class = "small-note mt-3", "Part D claims reflect diabetes and other covered uses; this tab uses Medicaid obesity-labeled prescriptions only.")))
  )
}

mod_evidence_server <- function(id, go) {
  shiny::moduleServer(id, function(input, output, session) {
    sel <- shiny::reactiveVal("AVG")
    output$title_es <- shiny::renderText(sprintf("Coverage was associated with an estimated %s additional prescriptions per 1,000 enrollees per quarter on average, rising from %s to %s over eight quarters", kf("c_att_overall"), kf("c_es_e0"), kf("c_es_e8")))
    output$es_chart <- plotly::renderPlotly(plot_event_study()) |> shiny::bindCache("es")
    output$map <- plotly::renderPlotly(plot_map(sel(), session$ns("map")))
    shiny::observeEvent(plotly::event_data("plotly_click", source = session$ns("map")), { d <- plotly::event_data("plotly_click", source = session$ns("map")); if (!is.null(d$customdata)) { sel(as.character(d$customdata[[1]])); shiny::updateSelectInput(session, "state", selected = sel()) } })
    shiny::observeEvent(input$state, sel(input$state), ignoreInit = TRUE)
    output$state_detail <- shiny::renderUI({
      if (identical(sel(), "AVG")) { pr <- STATES[STATES$group == "primary", ]; return(shiny::div(class = "mt-2 small", shiny::strong(AVG_LABEL), ": ", sprintf("%s (primary analysis). Click a state on the map or pick one below to see its start date, prior authorization rules and sources.", paste(pr$state_name[order(pr$cohort_quarter)], collapse = ", ")))) }
      s <- STATES[STATES$state_code == sel(), ]; if (!nrow(s)) return(NULL)
      st <- if (s$group == "primary") paste0("Primary analysis; coverage began ", s$cohort_quarter) else if (s$group == "sensitivity") "Sensitivity analysis only (uncertain start quarter)" else "Never covered in the study window"
      shiny::div(class = "mt-2 small", shiny::strong(s$state_name), ": ", st,
        if (!is.na(s$coverage_start)) shiny::tagList(shiny::br(), "Start: ", s$coverage_start), if (!is.na(s$coverage_end)) shiny::tagList(shiny::br(), "End: ", s$coverage_end),
        if (!is.na(s$prior_authorization)) shiny::tagList(shiny::br(), "Prior authorization: ", s$prior_authorization), if (!is.na(s$bmi_threshold)) shiny::tagList(shiny::br(), "BMI threshold: ", s$bmi_threshold),
        if (!is.na(s$start_source)) shiny::tagList(shiny::br(), shiny::strong("Start date source: "), if (!is.na(s$start_source_url)) shiny::tags$a(href = s$start_source_url, target = "_blank", s$start_source) else s$start_source),
        if (!is.na(s$document)) shiny::tagList(shiny::br(), shiny::strong("Criteria source"), if (!is.na(s$criteria_source_type)) paste0(" (", s$criteria_source_type, ")"), ": ", if (!is.na(s$source_url)) shiny::tags$a(href = s$source_url, target = "_blank", s$document) else s$document))
    })
    output$title_state <- shiny::renderText({ nm <- if (identical(sel(), "AVG")) AVG_LABEL else STATES$state_name[STATES$state_code == sel()]; sprintf("%s: observed obesity-labeled prescriptions per 1,000 enrollees against the never-covering mean", nm) })
    output$state_chart <- plotly::renderPlotly(plot_state_rates(sel()))
    output$title_spec <- shiny::renderText(sprintf("The estimate holds in %s alternative analyses (fee-for-service only is not estimable)", spec_all()))
    output$spec_chart <- plotly::renderPlotly(plot_spec()) |> shiny::bindCache("spec")
  })
}
