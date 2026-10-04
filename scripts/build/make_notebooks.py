"""Writes the five short exploration notebooks (notebooks/A_... to E_...qmd). Each is built only from existing exploratory outputs (tables and figures under analysis/outputs);
no new analysis is run. Render with: quarto render notebooks/<file>.qmd (R_LIBS pointing at the renv library). Run: python scripts/build/make_notebooks.py"""
import pathlib
root = pathlib.Path(__file__).resolve().parents[2]
nb = root / "notebooks"; nb.mkdir(exist_ok=True)
HEAD = '''---
title: "{title}"
subtitle: "Exploration notebook, module {mod}: existing outputs only, no new analysis"
format:
  html:
    toc: true
    embed-resources: true
    theme: cosmo
execute: {{ echo: false, warning: false, message: false }}
---

```{{r setup}}
source("../analysis/R/kn.R")
tb <- function(f, n = 12) knitr::kable(utils::head(read.csv(file.path("../analysis/outputs/tables", f), check.names = FALSE, stringsAsFactors = FALSE), n))
al <- read.csv("../analysis/outputs/figures/alt_text.csv", stringsAsFactors = FALSE)
fig <- function(name, cap) {{ a <- al$alt_text[al$figure == name]; stopifnot(length(a) == 1)
  cat(sprintf("![%s](../analysis/outputs/figures/%s.png){{fig-alt=\\"%s\\" width=100%%}}\\n\\n", cap, name, gsub("\\"", "'", a))) }}
```

{intro}
'''
NOTE = "\n*Part of the project report; every number comes from `analysis/outputs/key_numbers.csv`. Public aggregate data; no company affiliation or endorsement.*\n"
def section(h, text="", tables=(), figs=()):
    out = f"\n## {h}\n\n{text}\n" if text else f"\n## {h}\n"
    for t, n in tables: out += f"\n```{{r}}\ntb(\"{t}\", {n})\n```\n"
    for f, c in figs: out += f"\n```{{r}}\n#| results: asis\nfig(\"{f}\", \"{c}\")\n```\n"
    return out
NB = {
 "A_data_layer": ("Module A: the data and coding layer", "A", "A tested warehouse (`r kn(\"build_models\")` dbt models, `r kn(\"build_seeds\")` seeds, `r kn(\"build_tests\")` tests) sits behind every number. This notebook looks at what the data layer shows before any model: reporting completeness, spending, the timeline of events and the pipeline.",
   [section("Reporting completeness and suppression", "`r kn(\"m_rep_both\")`% of state-quarters have both fee-for-service and managed-care rows and `r kn(\"m_wz_suppressed_share\")`% of Wegovy and Zepbound rows are suppressed (counts under 11).", [("moduleA_sdud_reporting_status_counts.csv", 6), ("moduleA_sdud_reporting_summary.csv", 8)], [("52_sdud_reporting_suppression", "SDUD reporting and suppression by state and quarter")]),
    section("Spending by brand", "Gross of rebates: Part D `r kn(\"m_spend_partd_2020\")` to `r kn(\"m_spend_partd_2024\")` billion dollars (2020 to 2024); Medicaid `r kn(\"m_spend_medicaid_2020\")` to `r kn(\"m_spend_medicaid_2024\")` billion.", [("moduleA_spending_totals.csv", 12)], [("50_spending_trend", "Gross spending by brand")]),
    section("Timeline and pipeline", "Registered studies of the in-scope ingredients: `r kn(\"p_obesity_studies\")` list obesity, `r kn(\"p_obesity_phase3_ongoing\")` are ongoing Phase 3.", [("moduleA_pipeline_by_phase.csv", 8), ("moduleA_pipeline_summary.csv", 10)], [("51_timeline", "Timeline of approvals, coverage and federal events")]),
    section("Coverage criteria completeness", "Prior authorization is documented for `r kn(\"um_pa\")` of 17 states, BMI thresholds for `r kn(\"um_bmi\")`, comorbidity rules for `r kn(\"um_comorb\")` and step therapy for `r kn(\"um_step\")`.", [("coverage_um_completeness.csv", 6)], [("53_rate_map_2025Q3", "Prescriptions per 1,000 Medicaid enrollees, 2025 Q3")])]),
 "B_eligible_population": ("Module B: eligible population, funnel and forecast", "B", "About `r kn(\"b_eligible\")` million adults meet the label criteria (lower bound), including `r kn(\"b_medicaid_elig\")` million with Medicaid; about `r kn(\"b_glp1_all\")` million currently use a GLP-1 drug.",
   [section("Funnel", "", [("moduleB_funnel.csv", 12)], [("20_funnel", "Eligible-population funnel")]), section("Survey estimates (excerpt)", "NHANES 2021-2023 design-based estimates.", [("moduleB_survey_estimates.csv", 12)]),
    section("Forecast", "Median `r kn(\"b_fc_2030\")` million GLP-1 users without diagnosed diabetes by 2030.", [("moduleB_forecast_year_end.csv", 12)], [("21_forecast_fan", "Forecast fan chart")])]),
 "C_coverage_study": ("Module C: the coverage study", "C", "Coverage added `r kn(\"c_att_overall\")` prescriptions per 1,000 enrollees per quarter (`r kn_ci(\"c_att_overall\")`).",
   [section("Coverage and timing", "", [("coverage_um_criteria.csv", 17)], [("01_coverage_timing_map", "Coverage timing map")]), section("Estimates", "", [("overall_att.csv", 8), ("event_study_primary.csv", 12), ("estimator_reconciliation.csv", 8)], [("10_event_study_primary", "Event study"), ("11_specification_chart", "Specification chart"), ("12_honestdid", "HonestDiD")]),
    section("Withdrawals (preliminary)", "", [("withdrawal_change_2025Q4_to_2026Q1.csv", 8)], [("05_withdrawal_descriptive", "Coverage withdrawals")])]),
 "D_prescribers": ("Module D: prescribers", "D", "Part D reflects diabetes and other covered uses, not obesity-brand adoption. Primary care wrote `r kn(\"d_share_pcp\")`% of 2024 claims.",
   [section("Volume, specialty, concentration", "", [("moduleD_specialty_mix_by_year.csv", 10), ("moduleD_concentration_by_year.csv", 8)], [("31_partd_specialty_mix", "Specialty mix"), ("32_partd_concentration", "Concentration")]),
    section("Adoption", "", [("moduleD_tirzepatide_adoption_by_specialty.csv", 15)], [("33_partd_tirzepatide_adoption", "Tirzepatide adoption"), ("34_partd_wegovy_vs_ozempic_specialty", "Wegovy and Ozempic by specialty")]),
    section("Segments (exploratory)", "The pre-specified rule gave a two-segment split of new versus continuing prescribers; the five-segment solution is exploratory, with stability beside each segment.", [("moduleD_segment_profiles_k5.csv", 6)], [("35_partd_segments_k5", "Exploratory segments")])]),
 "E_budget_impact": ("Module E: budget impact", "E", "Central five-year net cost $`r kn(\"e_net5\")` million ($`r kn(\"e_pmpm\")` per enrollee per month) for 1 million enrollees, rebate `r kn(\"e_rebate_central\")`% assumed.",
   [section("Scenarios", "", [("moduleE_scenario_results.csv", 12), ("moduleE_pa_scenarios.csv", 4), ("moduleE_central_annual.csv", 5)], [("42_cost_by_scenario", "Cost by scenario")]),
    section("Sensitivity", "", [("moduleE_tornado.csv", 8), ("moduleE_psa_summary.csv", 3)], [("40_tornado", "Tornado"), ("41_waterfall_pmpm", "Waterfall"), ("43_psa_distribution", "PSA distribution")]),
    section("Value context", "Trial weight loss next to net cost per user per year; context only, no cost-effectiveness claim.", [("moduleE_value_context.csv", 9)])]),
}
for stem, (title, mod, intro, secs) in NB.items():
    text = HEAD.format(title=title, mod=mod, intro=intro) + "".join(secs) + NOTE
    (nb / f"{stem}.qmd").write_text(text, encoding="utf-8")
print("wrote", len(NB), "notebooks")
