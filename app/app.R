# Budget impact explorer for a state Medicaid programme covering Wegovy and Zepbound for obesity (Module E). Run locally with shiny::runApp("app").
# The model is bia.R (the same file the analysis uses); inputs are data/moduleE_inputs.rds (Module C effects, SDUD gross cost, rebate range, MEPS and NHANES inputs).
# SDUD amounts are gross of rebates; rebates, prior authorization and years 3-5 are assumptions; results are scenarios, not forecasts.
library(shiny)
library(ggplot2)
source("bia.R")
inp <- readRDS("data/moduleE_inputs.rds")
base <- bia_defaults(inp)
col_treated <- "#D55E00"; col_comparison <- "#595959"
theme_app <- function() theme_minimal(base_size = 12) + theme(plot.title = element_text(face = "bold"), panel.grid.minor = element_blank(), legend.position = "bottom")
usd <- function(x) paste0("$", formatC(round(x), format = "d", big.mark = ","))
usdm <- function(x) paste0("$", formatC(x / 1e6, format = "f", digits = 1, big.mark = ","), "M")

ui <- fluidPage(
  titlePanel("Budget impact: Medicaid coverage of Wegovy and Zepbound for obesity"),
  sidebarLayout(
    sidebarPanel(width = 4,
      numericInput("plan", "Plan size (Medicaid enrollees)", value = 1e6, min = 1e4, max = 2e7, step = 1e5),
      sliderInput("uptake", "Uptake multiplier on the observed effect", min = 0.5, max = 1.5, value = 1, step = 0.05),
      sliderInput("pa", "Prior authorization multiplier (0.5 tight to 1.0 as observed)", min = 0.5, max = 1, value = 0.75, step = 0.05),
      radioButtons("effect", "Module C effect", choices = c("Point estimate" = "est", "Lower 95% CI" = "lo", "Upper 95% CI" = "hi"), selected = "est", inline = TRUE),
      radioButtons("y35", "Years 3-5", choices = c("Plateau at the quarter-8 level" = "plateau", "Continued growth" = "growth", "Decline to half by quarter 20" = "decline"), selected = "plateau"),
      radioButtons("price", "Price scenario", choices = c("Gross cost less a rebate" = "rebate", "Announced $245 per monthly prescription (net)" = "announced"), selected = "rebate"),
      sliderInput("rebate", "Rebate share of gross cost (23.1% is the statutory minimum)", min = 0, max = 0.9, value = round(inp$rebate$central, 3), step = 0.01),
      sliderInput("gross", "Gross cost per prescription (USD, SDUD covered states 2024Q2-2025Q4: $1,164 to $1,252)", min = 800, max = 1600, value = round(inp$gross$central), step = 10),
      helpText("Gross: SDUD amounts are gross of rebates. Rebates, prior authorization and years 3-5 are assumptions; see the assumptions table in the repository (analysis/outputs/tables/moduleE_assumptions.csv).")),
    mainPanel(width = 8,
      fluidRow(column(4, h4("Net PMPM (5-year average)"), h2(textOutput("pmpm"))), column(4, h4("Five-year net cost"), h2(textOutput("net5"))), column(4, h4("Five-year gross cost"), h2(textOutput("gross5")))),
      hr(), h4("Annual results"), tableOutput("annual"), hr(), h4("One-way sensitivity of the five-year net cost (around the current settings)"), plotOutput("tornado", height = "320px"))))

server <- function(input, output, session) {
  params <- reactive({
    p <- base; p$plan <- input$plan; p$uptake_mult <- input$uptake; p$pa_mult <- input$pa; p$y35 <- input$y35; p$price <- input$price; p$rebate <- input$rebate; p$gross <- input$gross
    p$att9 <- switch(input$effect, est = inp$att$estimate, lo = inp$att$ci_low, hi = inp$att$ci_high); p })
  run <- reactive(bia_run(params()))
  output$pmpm <- renderText(sprintf("$%.2f", run()$total$pmpm_net))
  output$net5 <- renderText(usdm(run()$total$five_year_net))
  output$gross5 <- renderText(usdm(run()$total$five_year_gross))
  output$annual <- renderTable({ a <- run()$annual
    data.frame(Year = a$year, `Incremental prescriptions` = formatC(round(a$prescriptions), format = "d", big.mark = ","), `Gross cost` = usd(a$gross), `Net cost` = usd(a$net), `Net PMPM` = sprintf("$%.2f", a$pmpm_net),
               `Treated members` = formatC(round(a$treated_members), format = "d", big.mark = ","), `Eligible pool` = formatC(round(a$eligible_pool), format = "d", big.mark = ","), check.names = FALSE) }, striped = TRUE)
  output$tornado <- renderPlot({
    p0 <- params(); b0 <- bia_run(p0)$total$five_year_net
    mod <- function(...) { p <- p0; a <- list(...); for (n in names(a)) p[[n]] <- a[[n]]; p }
    f <- function(p) bia_run(p)$total$five_year_net
    d <- data.frame(parameter = c("Module C effect (95% CI)", "Prior authorization (0.5 to 1.0)", "Years 3-5 (decline to growth)", "Gross cost per prescription", "Rebate (23.1% to implied by $245)", "Uptake multiplier (0.75 to 1.25)"),
      lo = c(f(mod(att9 = inp$att$ci_low)), f(mod(pa_mult = 0.5)), f(mod(y35 = "decline")), f(mod(gross = inp$gross$low)), f(mod(price = "rebate", rebate = inp$rebate$high)), f(mod(uptake_mult = 0.75))),
      hi = c(f(mod(att9 = inp$att$ci_high)), f(mod(pa_mult = 1)), f(mod(y35 = "growth")), f(mod(gross = inp$gross$high)), f(mod(price = "rebate", rebate = inp$rebate$low)), f(mod(uptake_mult = 1.25))))
    d$span <- abs(d$hi - d$lo); d <- d[order(d$span), ]; d$parameter <- factor(d$parameter, levels = d$parameter)
    ggplot(d, aes(y = parameter)) + geom_segment(aes(x = lo / 1e6, xend = hi / 1e6, yend = parameter), colour = col_treated, linewidth = 6, alpha = 0.6) + geom_vline(xintercept = b0 / 1e6, colour = col_comparison, linetype = "dashed") +
      labs(x = "Five-year net cost (USD millions)", y = NULL) + theme_app() }, res = 110)
}
shinyApp(ui, server)
