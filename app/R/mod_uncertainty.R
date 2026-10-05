# Tab 4: uncertainty and sensitivity: one-way swings, a probabilistic analysis on demand, and the probability of staying within a budget.
mod_uncertainty_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    bslib::card(bslib::card_header(shiny::uiOutput(ns("title_tornado"))), bslib::card_body(plotly::plotlyOutput(ns("tornado"), height = "340px")),
      bslib::card_footer(src_line("One-way ranges from the assumptions table: effect 95% CI, prior authorization 0.5 to 1.25, years 3 to 5, gross cost $1,164 to $1,252, rebate 23.1% to the rate implied by $245, announced price, uptake 0.75 to 1.25. Each bar end is labeled with the parameter value that produces it; left = lower cost, right = higher cost."))),
    bslib::layout_sidebar(class = "mt-3", fillable = FALSE,
      sidebar = bslib::sidebar(width = 330, open = "desktop",
        shiny::actionButton(ns("run"), "Run the probabilistic analysis", class = "btn-primary w-100"),
        shiny::checkboxInput(ns("common"), info("Event-time effects move together", "Perfect correlation between the effects at different quarters since coverage began (the report's wider range). Unchecked = independent draws."), FALSE),
        shiny::checkboxInput(ns("random_y35"), info("Draw the years 3 to 5 path at random", "Checked: each draw picks plateau, growth or decline with equal probability, as in the report. Unchecked: use the path chosen in the Budget model tab."), TRUE),
        shiny::hr(), shiny::radioButtons(ns("basis"), "Budget applies to", c("Five-year total" = "five_year", "Highest single year" = "peak_year")),
        shiny::numericInput(ns("budget"), "Budget, USD millions", value = 150, min = 1, max = 5000, step = 5),
        shiny::p(class = "small-note", sprintf("10,000 draws, seeded (%s, the report's random-number stream), vectorized; results reflect the scenario when you pressed the button.", PSA_SEED))),
      bslib::layout_columns(col_widths = bslib::breakpoints(sm = 12, lg = c(6, 6)),
        bslib::card(bslib::card_header(shiny::uiOutput(ns("title_psa"))), bslib::card_body(plotly::plotlyOutput(ns("psa_hist"), height = "300px")), bslib::card_footer(src_line("Median (solid) and 90% interval (dashed) of the five-year net cost across draws."))),
        bslib::card(bslib::card_header(shiny::uiOutput(ns("title_cdf"))), bslib::card_body(plotly::plotlyOutput(ns("cdf"), height = "300px")), bslib::card_footer(src_line("Cost-acceptability style curve: the share of draws at or below each budget."))))),
    bslib::card(class = "mt-3", bslib::card_header("What the probabilistic analysis includes, and what it does not"), bslib::card_body(bslib::layout_columns(col_widths = bslib::breakpoints(sm = 12, md = c(6, 6)),
      shiny::div(shiny::strong("Included"), shiny::tags$ul(shiny::tags$li("Sampling uncertainty of the estimated effect at each quarter (standard errors from the difference-in-differences model)."), shiny::tags$li("Gross cost per prescription (observed range, $1,164 to $1,252)."), shiny::tags$li("Rebate between the statutory minimum and the rate implied by the announced $245 price."),
                                                 shiny::tags$li("Prior authorization (triangular around your setting, 0.5 to 1.25)."), shiny::tags$li("The years 3 to 5 path (random, or your choice)."))),
      shiny::div(shiny::strong("Not included"), shiny::tags$ul(shiny::tags$li("Plan size, uptake multiplier, adult and eligible shares and purchases per user: held at your values."), shiny::tags$li("Whether ten covering states represent your program (external validity) and model choice beyond the alternative analyses in the Evidence tab."), shiny::tags$li("Medical cost offsets (none are included) and future price changes."),
                                                 shiny::tags$li("Correlation between effects at different quarters, unless the box is checked."), shiny::tags$li("Actual net prices, which are confidential: the rebate range is an assumption."))))))
  )
}

mod_uncertainty_server <- function(id, scn) {
  shiny::moduleServer(id, function(input, output, session) {
    tor <- shiny::reactive(tornado_table(INP, scn$params()))
    output$title_tornado <- shiny::renderUI({ t <- tor(); nm <- function(x) { x <- sub(" \\(.*$", "", x); if (grepl("^Module", x)) paste("the", x) else paste("the", tolower(x)) }; sprintf("The widest swings in the five-year net cost come from %s (%s to %s) and %s", nm(t$parameter[1]), usdm(min(t$net_low[1], t$net_high[1])), usdm(max(t$net_low[1], t$net_high[1])), nm(t$parameter[2])) })
    output$tornado <- plotly::renderPlotly(plot_tornado(tor(), scn$run()$total$five_year_net))
    res <- shiny::eventReactive(input$run, { d <- psa_draws(INP, scn$params(), common = isTRUE(input$common), random_y35 = isTRUE(input$random_y35)); list(d = d, s = psa_summary(d), params = scn$params()) }, ignoreNULL = FALSE)
    output$title_psa <- shiny::renderUI({ r <- res(); sprintf("Five-year net cost: median %s, 90%% interval %s to %s (%s draws)", usdm(r$s[["median"]]), usdm(r$s[["p05"]]), usdm(r$s[["p95"]]), num(r$d$B)) })
    output$psa_hist <- plotly::renderPlotly({ r <- res(); plot_psa_hist(r$d, r$s) })
    output$title_cdf <- shiny::renderUI({
      shiny::validate(shiny::need(is.numeric(input$budget) && !is.na(input$budget) && input$budget > 0, "Enter a budget above zero."))
      r <- res(); pr <- psa_prob_within(r$d, input$budget * 1e6, input$basis)
      sprintf("The probability that the %s stays within $%sM is %s", if (input$basis == "five_year") "five-year net cost" else "highest annual net cost", formatC(input$budget, format = "f", digits = 0, big.mark = ","), pct(pr, 0)) })
    output$cdf <- plotly::renderPlotly({ shiny::validate(shiny::need(is.numeric(input$budget) && !is.na(input$budget) && input$budget > 0, "Enter a budget above zero.")); r <- res(); plot_cdf(r$d, input$budget * 1e6, input$basis) })
  })
}
