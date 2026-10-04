# Budget impact explorer for a state Medicaid programme covering Wegovy and Zepbound for obesity (Module E of the incretin access-and-value project).
# Self-contained: reads only the small CSVs in data/ (aggregate numbers already public in the project report) and the model in bia.R. Needs only the packages shiny and ggplot2.
# Run locally with shiny::runApp("app") or publish from GitHub (primary file app/app.R). Results are scenarios, not forecasts; SDUD amounts are gross of rebates.
library(shiny)
library(ggplot2)
source("bia.R")
eff <- read.csv("data/moduleC_effects.csv")
st <- read.csv("data/model_settings.csv", stringsAsFactors = FALSE)
g <- function(param, col) st[[col]][st$parameter == param]
inp <- list(att = data.frame(e = eff$event_quarter, estimate = eff$estimate, ci_low = eff$ci_low, ci_high = eff$ci_high),
            gross = list(central = g("gross_cost_per_prescription", "central"), low = g("gross_cost_per_prescription", "low"), high = g("gross_cost_per_prescription", "high")),
            rebate = list(central = g("rebate_share", "central"), low = g("rebate_share", "low"), high = g("rebate_share", "high")), announced = g("announced_net_price", "central"),
            fills = list(central = g("purchases_per_user_year", "central"), low = g("purchases_per_user_year", "low"), high = g("purchases_per_user_year", "high")),
            adult_share = g("adult_share_of_enrollment", "central"), eligible_share = g("eligible_share_of_medicaid_adults", "central"))
base <- bia_defaults(inp)
SITE <- "https://erickyegon.github.io/incretin-access-value/"
col_treated <- "#D55E00"; col_comparison <- "#595959"
theme_app <- function() theme_minimal(base_size = 12) + theme(plot.title = element_text(face = "bold"), panel.grid.minor = element_blank(), legend.position = "bottom")
usd <- function(x) paste0("$", formatC(round(x), format = "d", big.mark = ","))
usdm <- function(x) paste0("$", formatC(x / 1e6, format = "f", digits = 1, big.mark = ","), "M")
reb_pct <- round(100 * inp$rebate$central, 3); gross0 <- round(inp$gross$central, 4)   # exact central values, so the defaults reproduce the central case

controls <- sidebarPanel(width = 4,
  numericInput("plan", "Plan size (Medicaid enrollees)", value = 1e6, min = 1e4, max = 2e7, step = 1e5),
  sliderInput("uptake", "Uptake multiplier on the observed effect", min = 0.5, max = 1.5, value = 1, step = 0.05),
  sliderInput("pa", "Prior authorization multiplier (1.0 = as observed in the 10 covering states; below 1.0 tight, above 1.0 loose; assumption)", min = 0.5, max = 1.25, value = 1, step = 0.05),
  radioButtons("effect", "Module C effect", choices = c("Point estimate" = "est", "Lower 95% CI" = "lo", "Upper 95% CI" = "hi"), selected = "est", inline = TRUE),
  radioButtons("y35", "Years 3-5", choices = c("Plateau at the quarter-8 level" = "plateau", "Continued growth" = "growth", "Decline to half by quarter 20" = "decline"), selected = "plateau"),
  radioButtons("price", "Price scenario", choices = c("Gross cost less a rebate" = "rebate", "Announced $245 per monthly prescription (net)" = "announced"), selected = "rebate"),
  sliderInput("rebate", "Rebate share of gross cost, % (23.1% statutory minimum; central 51.2% = midpoint of 23.1% and 79.3%)", min = 0, max = 90, value = reb_pct, step = 0.001),
  numericInput("gross", "Gross cost per prescription (USD; covering states 2024 Q2 to 2025 Q4: $1,164 to $1,252)", value = gross0, min = 800, max = 1600, step = 1),
  actionButton("reset", "Reset to the central case"),
  helpText("Gross: SDUD amounts are gross of rebates. Rebates, prior authorization and years 3-5 are assumptions; see the Notes tab."))

model_panel <- mainPanel(width = 8,
  fluidRow(column(4, h4("Net PMPM (5-year average)"), h2(textOutput("pmpm"))), column(4, h4("Five-year net cost"), h2(textOutput("net5"))), column(4, h4("Five-year gross cost"), h2(textOutput("gross5")))),
  fluidRow(column(6, h4("Net cost per user per year (4.3 fills, MEPS)"), h3(textOutput("peruser"))), column(6, h4("Net cost per member-year of continuous treatment (12 fills, assumption)"), h3(textOutput("percont")))),
  hr(), h4("Annual results"), tableOutput("annual"), hr(), h4("One-way sensitivity of the five-year net cost (around the current settings)"), plotOutput("tornado", height = "320px"))

notes <- div(style = "max-width: 820px;",
  h3("Notes"),
  tags$ul(
    tags$li(tags$b("Gross of rebates."), " Cost per prescription is the Medicaid amount reimbursed in State Drug Utilization Data, which is before manufacturer rebates. Net cost applies a rebate share you choose."),
    tags$li(tags$b("Rebate range."), " 23.1% is the statutory minimum Medicaid rebate (42 U.S.C. 1396r-8); 79.3% is the rebate implied by the announced $245 price at the 2025 gross cost; the central 51.2% is their midpoint and is an assumption, because actual net prices are confidential."),
    tags$li(tags$b("Scenarios, not forecasts."), " Years 3 to 5, prior authorization (1.0 = as observed in the 10 covering states), uptake and the rebate are assumptions. No medical cost offsets are included. The effect comes from ten states and may not carry over."),
    tags$li(tags$b("Data sources."), " Coverage effect: CMS State Drug Utilization Data and Medicaid enrollment (project Module C, difference-in-differences, 95% CIs from the Callaway and Sant'Anna estimator). Gross cost: SDUD, cross-checked with NADAC. Purchases per user: MEPS. Eligible adults: NHANES 2021-2023. Rebate floor: 42 U.S.C. 1396r-8. Announced price: White House fact sheet, November 2025."),
    tags$li(tags$b("Project."), " Report, deck and code: ", tags$a(href = SITE, target = "_blank", "erickyegon.github.io/incretin-access-value"), " and ", tags$a(href = "https://github.com/erickyegon/incretin-access-value", target = "_blank", "github.com/erickyegon/incretin-access-value"), "."),
    tags$li(tags$b("Disclaimer."), " Public aggregate data; no company affiliation or endorsement; not patient-level claims; scenarios are not effects of any company's promotion."),
    tags$li(tags$b("AI-use statement."), " I used AI tools to help write code and documentation. The study design, methods and conclusions are my own, and I verified all results.")))

ui <- fluidPage(
  titlePanel("Budget impact: Medicaid coverage of Wegovy and Zepbound for obesity"),
  tabsetPanel(tabPanel("Model", br(), sidebarLayout(controls, model_panel)), tabPanel("Notes", br(), notes)))

server <- function(input, output, session) {
  observeEvent(input$reset, {
    updateNumericInput(session, "plan", value = 1e6); updateSliderInput(session, "uptake", value = 1); updateSliderInput(session, "pa", value = 1)
    updateRadioButtons(session, "effect", selected = "est"); updateRadioButtons(session, "y35", selected = "plateau"); updateRadioButtons(session, "price", selected = "rebate")
    updateSliderInput(session, "rebate", value = reb_pct); updateNumericInput(session, "gross", value = gross0) })
  params <- reactive({
    p <- base; p$plan <- input$plan; p$uptake_mult <- input$uptake; p$pa_mult <- input$pa; p$y35 <- input$y35; p$price <- input$price; p$rebate <- input$rebate / 100; p$gross <- input$gross
    p$att9 <- switch(input$effect, est = inp$att$estimate, lo = inp$att$ci_low, hi = inp$att$ci_high); p })
  run <- reactive(bia_run(params()))
  output$pmpm <- renderText(sprintf("$%.2f", run()$total$pmpm_net))
  output$net5 <- renderText(usdm(run()$total$five_year_net))
  output$gross5 <- renderText(usdm(run()$total$five_year_gross))
  output$peruser <- renderText(usd(run()$total$net_cost_per_user_year))
  output$percont <- renderText(usd(run()$total$net_cost_per_member_year_continuous))
  output$annual <- renderTable({ a <- run()$annual
    data.frame(Year = a$year, `Incremental prescriptions` = formatC(round(a$prescriptions), format = "d", big.mark = ","), `Gross cost` = usd(a$gross), `Net cost` = usd(a$net), `Net PMPM` = sprintf("$%.2f", a$pmpm_net),
               `Users` = formatC(round(a$treated_members), format = "d", big.mark = ","), `Eligible pool` = formatC(round(a$eligible_pool), format = "d", big.mark = ","), check.names = FALSE) }, striped = TRUE)
  output$tornado <- renderPlot({
    p0 <- params(); b0 <- bia_run(p0)$total$five_year_net
    mod <- function(...) { p <- p0; a <- list(...); for (n in names(a)) p[[n]] <- a[[n]]; p }
    f <- function(p) bia_run(p)$total$five_year_net
    d <- data.frame(parameter = c("Module C effect (95% CI)", "Prior authorization (0.5 tight to 1.25 loose)", "Years 3-5 (decline to growth)", "Gross cost per prescription", "Rebate (23.1% to implied by $245)", "Uptake multiplier (0.75 to 1.25)"),
      lo = c(f(mod(att9 = inp$att$ci_low)), f(mod(pa_mult = 0.5)), f(mod(y35 = "decline")), f(mod(gross = inp$gross$low)), f(mod(price = "rebate", rebate = inp$rebate$high)), f(mod(uptake_mult = 0.75))),
      hi = c(f(mod(att9 = inp$att$ci_high)), f(mod(pa_mult = 1.25)), f(mod(y35 = "growth")), f(mod(gross = inp$gross$high)), f(mod(price = "rebate", rebate = inp$rebate$low)), f(mod(uptake_mult = 1.25))))
    d$span <- abs(d$hi - d$lo); d <- d[order(d$span), ]; d$parameter <- factor(d$parameter, levels = d$parameter)
    ggplot(d, aes(y = parameter)) + geom_segment(aes(x = lo / 1e6, xend = hi / 1e6, yend = parameter), colour = col_treated, linewidth = 6, alpha = 0.6) + geom_vline(xintercept = b0 / 1e6, colour = col_comparison, linetype = "dashed") +
      labs(x = "Five-year net cost (USD millions)", y = NULL) + theme_app() }, res = 110)
}
shinyApp(ui, server)
