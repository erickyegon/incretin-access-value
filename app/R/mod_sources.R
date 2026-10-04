# Tab 6: assumptions (each labeled measured, sourced or assumed, with a link), methods in plain language, limitations, disclaimer, AI-use statement and links.
badge <- function(type) shiny::span(class = paste("badge", switch(type, Measured = "badge-measured", Sourced = "badge-sourced", "badge-assumed")), type)
mod_sources_ui <- function(id) {
  ns <- shiny::NS(id)
  rows <- lapply(seq_len(nrow(ASSUMP)), function(i) { a <- ASSUMP[i, ]; shiny::tags$tr(shiny::tags$td(shiny::strong(a$parameter)), shiny::tags$td(a$value_or_range), shiny::tags$td(badge(a$basis_type)), shiny::tags$td(a$basis), shiny::tags$td(shiny::tags$a(href = a$source_url, target = "_blank", a$source_label))) })
  shiny::tagList(
    bslib::card(bslib::card_header("Assumptions: measured, sourced or assumed"), bslib::card_body(shiny::div(class = "table-responsive", shiny::tags$table(class = "table table-sm align-middle",
      shiny::tags$thead(shiny::tags$tr(shiny::tags$th("Parameter"), shiny::tags$th("Value or range"), shiny::tags$th("Basis"), shiny::tags$th("Description"), shiny::tags$th("Source"))), shiny::tags$tbody(rows)))),
      bslib::card_footer(src_line("Measured = from the project's data; Sourced = a published or official source; Assumed = a scenario range, because no source gives the value. Full table: analysis/outputs/tables/moduleE_assumptions.csv."))),
    bslib::layout_columns(col_widths = bslib::breakpoints(sm = 12, lg = c(6, 6)), class = "mt-3",
      bslib::card(bslib::card_header("Methods in plain language"), bslib::card_body(shiny::tags$ul(
        shiny::tags$li(shiny::strong("Budget impact, not cost-effectiveness."), " The model follows the ISPOR principles of good practice for budget impact analysis: a payer perspective (state Medicaid), a five-year quarterly horizon, and costs incremental to no coverage."),
        shiny::tags$li(shiny::strong("Uptake comes from observed prescriptions."), " The estimated extra prescriptions per 1,000 enrollees (difference-in-differences across 10 covering and 34 never-covering jurisdictions) are scaled to the plan and priced. Because they are filled prescriptions, real-world discontinuation is already embedded; no extra persistence is added."),
        shiny::tags$li(shiny::strong("Gross versus net."), " Gross cost is the Medicaid amount reimbursed per prescription (before rebates). Net applies a rebate between the statutory minimum and the rate implied by the announced $245 price; actual net prices are confidential."),
        shiny::tags$li(shiny::strong("No medical offsets in the base case."), " No published source supporting a five-year offset was retrieved, so none is included."),
        shiny::tags$li(shiny::strong("A commercial plan would differ"), ": different prior authorization, price and population; these inputs are the levers to change."))) ),
      bslib::card(bslib::card_header("Limitations, disclaimer and AI-use statement"), bslib::card_body(shiny::tags$ul(
        shiny::tags$li("Scenarios, not forecasts. The effect comes from ten states and may not carry over to other states or later years; part of its growth reflects national market growth."),
        shiny::tags$li("Amounts from State Drug Utilization Data are gross of rebates; eligibility is a lower bound; years 3 to 5, prior authorization and rebates are assumptions."),
        shiny::tags$li(shiny::strong("Disclaimer."), " Public aggregate data; no company affiliation or endorsement; not patient-level claims; scenarios are not effects of any company's promotion."),
        shiny::tags$li(shiny::strong("AI-use statement."), " I used AI tools to help write code and documentation. The study design, methods and conclusions are my own, and I verified all results.")))) ),
    bslib::card(class = "mt-3", bslib::card_header("Project links"), bslib::card_body(shiny::p(class = "mb-0",
      shiny::tags$a(href = SITE, target = "_blank", "Project site"), " · ", shiny::tags$a(href = paste0(SITE, "report.html"), target = "_blank", "Report"), " · ", shiny::tags$a(href = paste0(SITE, "deck.pdf"), target = "_blank", "Insight deck (PDF)"), " · ",
      shiny::tags$a(href = paste0(SITE, "one_page_summary.pdf"), target = "_blank", "One-page summary"), " · ", shiny::tags$a(href = paste0(SITE, "research_pack.pdf"), target = "_blank", "Research design pack"), " · ", shiny::tags$a(href = REPO, target = "_blank", "Code and data dictionary"))))
  )
}
mod_sources_server <- function(id) shiny::moduleServer(id, function(input, output, session) NULL)
