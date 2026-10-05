# Module E static PDF (fallback for the app): summary page, central scenario by year, scenario table and the budget figures, with the project fonts and page numbers.
# Built only from saved Module E tables and figures: Quarto renders analysis/budget_pdf/budget_impact_scenarios.qmd to HTML and headless Chrome prints it to PDF (needs node and puppeteer-core on NODE_PATH).
qmd <- here::here("budget_pdf", "budget_impact_scenarios.qmd"); html <- sub("[.]qmd$", ".html", qmd); pdf <- here::here("outputs", "budget_impact_scenarios.pdf")
stopifnot(system2("quarto", c("render", shQuote(qmd))) == 0)
stopifnot(system2("node", c(shQuote(here::here("..", "scripts", "build", "html_to_pdf.js")), shQuote(html), shQuote(pdf), "--css-page")) == 0)
unlink(html); cat("wrote", pdf, "\n")
