# Number and content audit

Run: 2026-10-05. Key numbers: 180 rows.

## Numbers by document and class

| document | exact | rounded | allowed | UNMATCHED | STALE |
|---|---|---|---|---|---|
| deck_pdf | 115 | 0 |  3 | 0 | 0 |
| one_pager |  23 | 0 |  0 | 0 | 0 |
| readme |  37 | 0 |  4 | 0 | 0 |
| report | 476 | 1 | 66 | 8 | 0 |
| research_pack |  66 | 0 | 64 | 0 | 0 |
| website |  30 | 0 |  1 | 0 | 0 |

## Other checks

| check | result | detail |
|---|---|---|
| American spelling in public text (no programme, modelled, labelled, organisation, grey and similar) | PASS |  |
| '1 million enrollees' is used instead of '1,000,000 enrollees' in public text | PASS |  |
| no 'PhD' or 'Ph.D' in titles, bylines or any deliverable text | PASS |  |
| no Open Payments results in the deck, one-pager, website or notebooks (report-only numbers) | PASS |  |
| no NPI-level or named-clinician columns in any output table | PASS |  |
| no manufacturer named in the payments figure alt text or titles | PASS |  |
| no manufacturer named in the payments script titles | PASS |  |
| every source marked in_repo in docs/sources_index.csv has its saved copy in the repository | PASS |  |
| every document under docs/sources is listed in the index | PASS |  |
| no copyrighted third-party copy is tracked (index in_repo = no for KFF, ISPOR, Sawtooth, journal articles, Cornell LII) | PASS |  |
| external-fact key numbers (x_*) point to a saved government source or to a URL listed in the sources index | PASS |  |
| budget-model app is self-contained (no database, no paths outside app/) and has a Connect Cloud manifest | PASS |  |
| build counts match the dbt manifest (models, seeds, tests) | PASS | manifest: 54 models, 10 seeds, 126 tests |
| git status is clean | FAIL |  M README.md;  M analysis/R/theme.R;  M analysis/outputs/budget_impact_scenarios.pdf;  M analysis/outputs/deviations.md;  M analysis/outputs/figures/01_coverage_timing_map.png |
| git ls-files shows no raw/interim data, credentials or caches | PASS |  |
| no tracked file over 50 MB | PASS |  |

## Needs review (unmatched or stale numbers)

- report: `17.9` (UNMATCHED)
- report: `1.96` (UNMATCHED)
- report: `75.7` (UNMATCHED)
- report: `95.5` (UNMATCHED)
- report: `26.0` (UNMATCHED)
- report: `51.0` (UNMATCHED)
- report: `347` (UNMATCHED)
