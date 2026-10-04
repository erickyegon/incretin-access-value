# Item 1 of the plan reconciliation: the utilization-management (UM) criteria table for the 17 states of the coverage study, from the curated reference file
# data/reference/medicaid_obesity_um_criteria.csv (built by scripts/build/build_um_table.py from state documents; "not found in sourced documents" = no document states it).
source(here::here("R", "theme.R"))
suppressPackageStartupMessages(library(gt))
um <- readr::read_csv(here::here("..", "data", "reference", "medicaid_obesity_um_criteria.csv"), show_col_types = FALSE, progress = FALSE)
nf <- "not found in sourced documents"
pub <- um |> transmute(State = state, `Analysis group` = analysis_group, `Delivery system` = delivery_system, Products = products_covered, `Prior authorization` = prior_authorization, `BMI threshold` = bmi_threshold,
                       `Comorbidity requirement` = comorbidity_requirement, `Step therapy` = step_therapy, `Other requirements` = other_requirements, `Criteria version (document)` = criteria_version, `Source type` = source_type,
                       `Source URL` = source_url, `Supporting URL` = supporting_source_url, `Date accessed` = date_accessed)
save_table(pub, "coverage_um_criteria")
cell_nf <- function(x) grepl(nf, x, fixed = TRUE)
summ <- tibble::tibble(field = c("Prior authorization", "BMI threshold", "Comorbidity requirement", "Step therapy"),
                       documented = c(sum(!cell_nf(um$prior_authorization)), sum(!cell_nf(um$bmi_threshold)), sum(!cell_nf(um$comorbidity_requirement)), sum(!cell_nf(um$step_therapy))),
                       not_found = c(sum(cell_nf(um$prior_authorization)), sum(cell_nf(um$bmi_threshold)), sum(cell_nf(um$comorbidity_requirement)), sum(cell_nf(um$step_therapy))), states = nrow(um))
save_table(summ, "coverage_um_completeness")
g <- gt(pub |> select(State, `Delivery system`, `Prior authorization`, `BMI threshold`, `Comorbidity requirement`, `Step therapy`, `Criteria version (document)`)) |>
  tab_header(title = "Utilization-management criteria for obesity drugs in the 17 Medicaid programs that covered them", subtitle = "From state documents; a cell reading 'not found in sourced documents' means no document states it. Criteria differ by period.") |>
  tab_source_note("Sources: state Medicaid agency documents listed in docs/sources_index.csv and data/reference/medicaid_obesity_um_criteria.csv (URLs per state). SC criteria are as reported by a news outlet quoting the state agency.") |>
  tab_options(table.font.size = px(11), data_row.padding = px(3))
gt::gtsave(theme_gt_incretin(g), file.path(out_dir("tables"), "coverage_um_criteria.html"))
print(as.data.frame(summ))
