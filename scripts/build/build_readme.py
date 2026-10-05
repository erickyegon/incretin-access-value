"""Writes README.md from analysis/outputs/key_numbers.csv so that every number in the README is the same number as in the report, deck and website.
Run: python scripts/build/build_readme.py"""
import csv, pathlib
root = pathlib.Path(__file__).resolve().parents[2]
kn = {r["id"]: r for r in csv.DictReader(open(root / "analysis" / "outputs" / "key_numbers.csv", encoding="utf-8"))}
d = lambda i: kn[i]["display"]
ci = lambda i: kn[i]["ci_or_range"]
holds = d("c_spec_holds").split(" of "); HOLDS = f"all {holds[1]} estimable" if holds[0] == holds[1] else f"{d('c_spec_holds')} estimable"
SITE = "https://erickyegon.github.io/incretin-access-value/"; APP = "https://erickyegon.github.io/incretin-access-value/budget-model.html"
text = f"""# Access and value of obesity drugs in Medicaid

When state Medicaid programs covered Wegovy and Zepbound, prescriptions rose by an estimated {d("c_att_overall")} per 1,000 enrollees per quarter; covering them for a 1-million-enrollee program would cost about ${d("e_net5")} million net over five years. A public-data study with a tested warehouse (PostgreSQL, dbt), an R analysis, a Quarto report and an interactive budget model.

**[Project site]({SITE})** · **[Report]({SITE}report.html)** · **[Interactive budget model]({APP})** · [Insight deck (PDF)]({SITE}deck.pdf) · [One-page summary (PDF)]({SITE}one_page_summary.pdf) · [Research design pack (PDF)]({SITE}research_pack.pdf) · [Code](https://github.com/erickyegon/incretin-access-value)

![Estimated effect of coverage on prescriptions by quarter since coverage began](docs/figures/readme/hero_event_study.png)

| Project site | Report | Interactive budget model |
|---|---|---|
| [![Project site]](docs/figures/readme/site.png) | [![Report]](docs/figures/readme/report.png) | [![Budget model app]](docs/figures/readme/app.png) |

**Author:** Erick Kiprotich Yegon, epidemiologist and data scientist.

> Public aggregate data; no company affiliation or endorsement; not patient-level claims; gross of rebates unless stated; associations and scenarios, not effects of any company's promotion.

## Headline findings

All numbers come from [`analysis/outputs/key_numbers.csv`](analysis/outputs/key_numbers.csv), which links each one to its output file and row.

- **Coverage was associated with more prescriptions.** An estimated {d("c_att_overall")} additional Wegovy and Zepbound prescriptions per 1,000 Medicaid enrollees per quarter ({ci("c_att_overall")}), comparing {d("c_states_primary")} covering states with {d("c_states_never")} never-covering jurisdictions. The effect rose from {d("c_es_e0")} in the first quarter to {d("c_es_e8")} after eight (part of the growth is national market growth), and it holds in {HOLDS} alternative analyses. A placebo gives {d("c_placebo")} ({ci("c_placebo")}).
- **Eligible adults.** {d("b_eligible")} million U.S. adults meet the FDA label criteria (lower bound; {ci("b_eligible")} million), including {d("b_medicaid_elig")} million with Medicaid ({ci("b_medicaid_elig")} million).
- **Prescribers.** Primary care physicians wrote {d("d_share_pcp")}% and nurse practitioners and physician assistants {d("d_share_nppa")}% of Part D incretin claims in 2024; Part D reflects diabetes and other covered uses, not obesity-brand adoption.
- **Budget impact** for a program of 1 million enrollees: a net cost of about ${d("e_net5")} million over five years in the central case (${d("e_pmpm")} per enrollee per month), with a scenario range of ${d("e_scen_min")} to ${d("e_scen_max")} million. The rebate is assumed ({d("e_rebate_central")}% is the midpoint of {d("e_rebate_low")}% and {d("e_rebate_high")}%); at the announced ${d("x_price_245")} price the central case is ${d("e_announced5")} million.

## Deliverables

| What | Live | In the repository |
|---|---|---|
| Project site | [{SITE}]({SITE}) | `site/` |
| Study report (Quarto HTML) | [report]({SITE}report.html) | `report/report.html` |
| Interactive budget model (Shiny decision tool) | [app]({APP}) | `app/` |
| Insight deck (PDF) | [deck.pdf]({SITE}deck.pdf) | `deck/deck.pdf` |
| One-page summary (PDF) | [one_page_summary.pdf]({SITE}one_page_summary.pdf) | `deck/one_page_summary.pdf` |
| Research design pack (Module F, PDF) | [research_pack.pdf]({SITE}research_pack.pdf) | `research_pack/research_pack.pdf` |
| Budget impact scenarios (PDF) | [budget_impact_scenarios.pdf]({SITE}budget_impact_scenarios.pdf) | `analysis/outputs/budget_impact_scenarios.pdf` |
| Exploration notebooks, one per module A to E (HTML) | [notebooks]({SITE}notebooks/C_coverage_study.html) | `notebooks/` |
| Coverage criteria table for the 17 covering states (prior authorization, BMI, comorbidity, step therapy) | [CSV]({SITE}data/coverage_um_criteria.csv) | `analysis/outputs/tables/coverage_um_criteria.csv` |
| Trial efficacy inputs (STEP 1, SURMOUNT-1, SURMOUNT-5, ATTAIN-1) and value-context table | | `data/reference/trial_inputs.csv`, `analysis/outputs/tables/moduleE_value_context.csv` |
| Data dictionary (NDC not HCPCS, units, suppression) and generated mart dictionary | | `docs/data_dictionary.md`, `docs/data_dictionary_marts.md` |
| Pre-specified plans, deviations, summaries | | `analysis/plan_module*.md`, `analysis/analysis_plan_moduleC.md`, `analysis/outputs/deviations.md`, `analysis/outputs/module*_summary.md` |

## Interactive decision tool

[Open the app]({APP}): evidence, budget model, uncertainty, scenario comparison and sources, built around the unchanged budget impact engine. The defaults equal the numbers in this README. Tests: `app/tests/` (testthat) and `scripts/test/test_app.js` (browser).

| Overview | Evidence | Budget model |
|---|---|---|
| ![Overview](docs/figures/app/overview.png) | ![Evidence](docs/figures/app/evidence.png) | ![Budget model](docs/figures/app/budget.png) |
| **Uncertainty** | **Compare** | **Sources** |
| ![Uncertainty](docs/figures/app/uncertainty.png) | ![Compare](docs/figures/app/compare.png) | ![Sources](docs/figures/app/sources.png) |

## Related project

This is the second of two portfolio projects. The first, **Evidence**, is a real-world oncology study (NSCLC): <https://erickyegon.github.io/oncology-rwe-nsclc/>. This one is **Access & Value** (incretin drugs in Medicaid).

## Reproduce

Raw and interim data are not committed; the scripts download them and record their checksums in `data/manifest.csv`.

1. **Load.** `pip install -r requirements.txt`; run the scripts in `scripts/fetch` (in numeric order), then `scripts/load` to load the interim files into PostgreSQL (database `incretin`).
2. **Build.** `cd dbt && dbt deps && dbt seed && dbt build` (staging, intermediate and marts; the tests run with the build). Then `python scripts/build/build_counts.py`.
3. **Analyze.** `cd analysis` and `Rscript run_all.R` (packages pinned in `analysis/renv.lock`; R 4.6), then `Rscript scripts/50_key_numbers.R`. Figures use the project style system (`analysis/R/fig_style.R`: bundled IBM Plex Sans and Source Serif 4, report, deck and web variants).
4. **Render.** `quarto render report`, `quarto render deck` (then `node deck/make_pdf.js deck/deck.html deck/deck.pdf`), `quarto render research_pack` and `python site/build_site.py`. Run the Shiny app with `shiny::runApp("app")`.
5. **Audit.** `Rscript audit/check_numbers.R` checks that every public number matches `key_numbers.csv`; `Rscript audit/check_figures.R` checks every figure (type scale, clipping, overlap, alt text); `python audit/check_links.py` checks the links.

## Repository map

- `scripts/fetch`, `scripts/load`, `scripts/build`, `scripts/qa`, `scripts/test`: acquisition, loading, build, QA and test helpers.
- `dbt/`: staging, intermediate and marts models, seeds and tests ({d("build_models")} models, {d("build_seeds")} seeds, {d("build_tests")} tests, counted from the dbt manifest). Lineage: `docs/figures/dbt_lineage.png`.
- `analysis/`: R project (renv), scripts by module (B, C, D, E), outputs (`tables`, `figures`, summaries), `key_numbers.csv`.
- `app/`: Shiny budget impact model. `report/`, `deck/`, `site/`, `research_pack/`: the deliverables above.
- `docs/`: data dictionary, warehouse notes and every source (`docs/sources_index.csv` lists URL, access date and checksum for all of them; U.S. government documents and open-license manuals are kept in `docs/sources`, copyrighted third-party copies are kept locally only).
- `audit/`: the number audit, figure QA and link check.

## Data sources

All were accessed between 2026-10-03 and 2026-10-04 (per-file dates, URLs and checksums in `data/manifest.csv`; all sources, kept or not, in `docs/sources_index.csv`). They are U.S. federal public data released for public use, and each agency's terms of use apply; the KFF poll results are cited from KFF's published pages.

- CMS Medicaid State Drug Utilization Data, Medicaid enrollment, NADAC, spending by drug (data.medicaid.gov, data.cms.gov)
- CMS Medicare Part D Prescribers by Provider and Drug; CMS Open Payments (general payments); NPPES; NUCC taxonomy
- NCHS NHANES 2021-2023 and 2017-March 2020; AHRQ MEPS 2023-2024
- FDA NDC directory, openFDA and Drugs@FDA labels; NLM RxNorm; CMS ICD-10-CM value sets; ClinicalTrials.gov
- State Medicaid policy documents and CMS approvals (`data/reference/medicaid_obesity_coverage.csv`); KFF Health Tracking Polls; CMS Medicare GLP-1 Bridge pages; White House fact sheet (November 2025); 42 U.S.C. 1396r-8

## Limitations

SDUD amounts are gross of rebates and the rebate range is an assumption; the coverage effect comes from {d("c_states_primary")} states and may not carry over; eligibility is a lower bound; Part D is not obesity use; suppressed cells are imputed; the budget model has no medical cost offsets; the prescriber analyses are descriptive associations; the forecast and budget model are scenarios, not forecasts. See the report for details.

## AI-use statement

I used AI tools to help write code and documentation. The study design, methods and conclusions are my own, and I verified all results.

## Contact

Erick Kiprotich Yegon, epidemiologist and data scientist · [LinkedIn](https://linkedin.com/in/erickyegon) · [keyegon@gmail.com](mailto:keyegon@gmail.com)
"""
text = text.replace("[![Project site]](docs/figures/readme/site.png)", "[![Project site](docs/figures/readme/site.png)]({})".format(SITE)).replace("[![Report]](docs/figures/readme/report.png)", "[![Report](docs/figures/readme/report.png)]({}report.html)".format(SITE)).replace("[![Budget model app]](docs/figures/readme/app.png)", "[![Budget model app](docs/figures/readme/app.png)]({})".format(APP))
(root / "README.md").write_text(text, encoding="utf-8")
print("README.md written")
