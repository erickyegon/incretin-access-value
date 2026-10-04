"""Writes README.md from analysis/outputs/key_numbers.csv so that every number in the README is the same number as in the report, deck and website.
Run: python scripts/build/build_readme.py"""
import csv, pathlib
root = pathlib.Path(__file__).resolve().parents[2]
kn = {r["id"]: r for r in csv.DictReader(open(root / "analysis" / "outputs" / "key_numbers.csv", encoding="utf-8"))}
d = lambda i: kn[i]["display"]
ci = lambda i: kn[i]["ci_or_range"]
text = f"""# Access and value of obesity drugs in Medicaid

A public-data study of Medicaid coverage of Wegovy and Zepbound for obesity: what coverage did to prescriptions, how many adults are eligible, who prescribes, and what coverage could cost a state programme. It is built as a tested warehouse (PostgreSQL and dbt), an R analysis (renv), a Quarto report, deck and website, and a Shiny budget model.

**Author:** Erick Kiprotich Yegon, epidemiologist and data scientist.

> Public aggregate data; no company affiliation or endorsement; not patient-level claims; gross of rebates unless stated; associations and scenarios, not effects of any company's promotion.

## Headline findings

All numbers come from [`analysis/outputs/key_numbers.csv`](analysis/outputs/key_numbers.csv), which links each one to its output file and row.

- **Coverage raised prescriptions.** About {d("c_att_overall")} extra Wegovy and Zepbound prescriptions per 1,000 Medicaid enrollees per quarter ({ci("c_att_overall")}), comparing {d("c_states_primary")} covering states with {d("c_states_never")} never-covering jurisdictions. The effect rose from {d("c_es_e0")} in the first quarter to {d("c_es_e8")} after eight (part of the growth is national market growth). A placebo gives {d("c_placebo")} ({ci("c_placebo")}).
- **Eligible adults.** {d("b_eligible")} million U.S. adults meet the FDA label criteria (lower bound; {ci("b_eligible")} million), including {d("b_medicaid_elig")} million with Medicaid ({ci("b_medicaid_elig")} million).
- **Prescribers.** Primary care physicians wrote {d("d_share_pcp")}% and nurse practitioners and physician assistants {d("d_share_nppa")}% of Part D incretin claims in 2024; Part D reflects diabetes and other covered uses, not obesity-brand adoption.
- **Budget impact** for a programme of 1,000,000 enrollees: ${d("e_net5")} million net over five years in the central case (${d("e_pmpm")} per enrollee per month), with a scenario range of ${d("e_scen_min")} to ${d("e_scen_max")} million. The rebate is assumed ({d("e_rebate_central")}% is the midpoint of {d("e_rebate_low")}% and {d("e_rebate_high")}%); at the announced ${d("x_price_245")} price the central case is ${d("e_announced5")} million.

## Related project

This is the second of two portfolio projects. The first, **Evidence**, is a real-world oncology study (NSCLC): <https://erickyegon.github.io/oncology-rwe-nsclc/>. This one is **Access & Value** (incretin drugs in Medicaid).

## Deliverables

| What | Where |
|---|---|
| Study report (Quarto HTML) | `report/report.html` |
| Insight deck (PDF) | `deck/deck.pdf` |
| One-page summary (PDF) | `deck/one_page_summary.pdf` |
| Project website (built, not published) | `site/` |
| Research design pack (Module F, PDF) | `research_pack/research_pack.pdf` |
| Budget model (Shiny, runs locally) and static PDF | `app/`, `analysis/outputs/budget_impact_scenarios.pdf` |
| Pre-specified plans, deviations, summaries | `analysis/plan_module*.md`, `analysis/analysis_plan_moduleC.md`, `analysis/outputs/deviations.md`, `analysis/outputs/module*_summary.md` |

## Reproduce

Raw and interim data are not committed; the scripts download them and record their checksums in `data/manifest.csv`.

1. **Load.** `pip install -r requirements.txt`; run the scripts in `scripts/fetch` (in numeric order), then `scripts/load` to load the interim files into PostgreSQL (database `incretin`).
2. **Build.** `cd dbt && dbt deps && dbt seed && dbt build` (staging, intermediate and marts; the tests run with the build). Then `python scripts/build/build_counts.py`.
3. **Analyse.** `cd analysis` and `Rscript run_all.R` (packages pinned in `analysis/renv.lock`; R 4.6), then `Rscript scripts/50_key_numbers.R`.
4. **Render.** `quarto render report`, `quarto render deck` (then `node deck/make_pdf.js deck/deck.html deck/deck.pdf`), `quarto render research_pack` and `python site/build_site.py`. Run the Shiny app with `shiny::runApp("app")`.
5. **Audit.** `Rscript audit/check_numbers.R` checks that every public number matches `key_numbers.csv`.

## Repository map

- `scripts/fetch`, `scripts/load`, `scripts/build`: acquisition, loading and build helpers.
- `dbt/`: staging, intermediate and marts models, seeds and tests ({d("build_models")} models, {d("build_seeds")} seeds, {d("build_tests")} tests, counted from the dbt manifest). Lineage: `docs/figures/dbt_lineage.png`.
- `analysis/`: R project (renv), scripts by module (B, C, D, E), outputs (`tables`, `figures`, summaries), `key_numbers.csv`.
- `app/`: Shiny budget impact model. `report/`, `deck/`, `site/`, `research_pack/`: the deliverables above.
- `docs/`: data dictionary, warehouse notes and every saved source document (`docs/sources`, with `sources_log.csv`).
- `audit/`: the number audit and its allow-list.

## Data sources

All were accessed between 2026-10-03 and 2026-10-04 (per-file dates, URLs and checksums in `data/manifest.csv`; saved policy and source documents in `docs/sources/sources_log.csv`). They are U.S. federal public data released for public use, and each agency's terms of use apply; the KFF poll results are cited from KFF's published pages.

- CMS Medicaid State Drug Utilization Data, Medicaid enrollment, NADAC, spending by drug (data.medicaid.gov, data.cms.gov)
- CMS Medicare Part D Prescribers by Provider and Drug; CMS Open Payments (general payments); NPPES; NUCC taxonomy
- NCHS NHANES 2021-2023 and 2017-March 2020; AHRQ MEPS 2023-2024
- FDA NDC directory, openFDA and Drugs@FDA labels; NLM RxNorm; CMS ICD-10-CM value sets; ClinicalTrials.gov
- State Medicaid policy documents and CMS approvals (`data/reference/medicaid_obesity_coverage.csv`); KFF Health Tracking Polls; CMS Medicare GLP-1 Bridge pages; White House fact sheet (November 2025); 42 U.S.C. 1396r-8

## Limitations

SDUD amounts are gross of rebates and the rebate range is an assumption; the coverage effect comes from {d("c_states_primary")} states and may not carry over; eligibility is a lower bound; Part D is not obesity use; suppressed cells are imputed; the budget model has no medical cost offsets; prescriber payment results are associations; the forecast and budget model are scenarios, not forecasts. See the report for details.

## AI-use statement

I used AI tools to help write code and documentation. The study design, methods and conclusions are my own, and I verified all results.

## Contact

Erick Kiprotich Yegon, epidemiologist and data scientist. Contact through the GitHub profile `erickyegon`.
"""
(root / "README.md").write_text(text, encoding="utf-8")
print("README.md written")
