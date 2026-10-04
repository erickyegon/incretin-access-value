# Number and content audit

Run: 2026-10-04. Key numbers: 117 rows.

## Numbers by document and class

| document | exact | rounded | allowed | UNMATCHED | STALE |
|---|---|---|---|---|---|
| deck_pdf |  73 | 0 |  4 | 0 | 0 |
| one_pager |  24 | 0 |  0 | 0 | 0 |
| readme |  33 | 0 |  6 | 0 | 0 |
| report | 276 | 2 | 42 | 0 | 0 |
| research_pack |  69 | 0 | 63 | 0 | 0 |
| website |  32 | 0 |  2 | 0 | 0 |

## Other checks

| check | result | detail |
|---|---|---|
| no 'PhD' or 'Ph.D' in titles, bylines or any deliverable text | PASS |  |
| no Open Payments results in the deck, one-pager or website (report-only numbers) | PASS |  |
| no NPI-level or named-clinician columns in any output table | PASS |  |
| no manufacturer named in the payments figure alt text or titles | PASS |  |
| no manufacturer named in the payments script titles | PASS |  |
| every row of docs/sources/sources_log.csv points to a saved file | PASS |  |
| external-fact key numbers (x_*) point to saved source files | PASS | whitehouse_fact_sheet_mfn_2025-11.txt, cms_medicare_glp1_bridge_page.txt, cms_medicare_glp1_bridge_page.txt, uscode_42_1396r8_medicaid_drug_rebate.txt |
| build counts match the dbt manifest (models, seeds, tests) | PASS | manifest: 54 models, 10 seeds, 126 tests |
| git status is clean | FAIL |  M audit/check_numbers.R; ?? PUBLISH.md |
| git ls-files shows no raw/interim data, credentials or caches | PASS |  |
| no tracked file over 50 MB | PASS |  |

## Needs review (unmatched or stale numbers)

None.
