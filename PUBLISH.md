# Publishing checklist (nothing here has been run)

No remote exists and nothing has been pushed. These are the exact steps to publish `erickyegon/incretin-access-value`. Run them only when you approve.

## 0. Pre-flight (local)

```bash
cd incretin-access-value
Rscript audit/check_numbers.R          # must end with "None." under "Needs review", and every check PASS
python audit/size_check.py             # size of what would be pushed
git status --short                     # must be empty
git branch --show-current              # main
```

**Size check at the time of writing:** 412 tracked files, 35.0 MB in the working tree, about 18 MiB of packed history (what a push sends); the largest file is 6.6 MB (GitHub's limit is 100 MB per file). No raw or interim data, credentials, caches or `profiles.yml` are tracked (`git ls-files` checked in the audit); a search of tracked files for passwords, keys and tokens found only environment-variable names and placeholders.

## 1. Create the public repository and push

Needs the GitHub CLI signed in as `erickyegon` (`gh auth status`).

```bash
gh repo create erickyegon/incretin-access-value --public --source=. --remote=origin --description "Access and value of obesity drugs in Medicaid: coverage effect, eligibility, prescribers and budget impact (public data, dbt, R, Quarto, Shiny)"
git push -u origin main
```

## 2. Enable GitHub Pages (website in `site/`)

The workflow `.github/workflows/pages.yml` publishes the `site/` folder (Pages itself only serves the repository root or `docs/`, so the workflow is used instead).

```bash
gh api -X POST repos/erickyegon/incretin-access-value/pages -f build_type=workflow
gh workflow run "Deploy site to GitHub Pages"
```

The site will be at `https://erickyegon.github.io/incretin-access-value/`. If you change anything in the report, deck or numbers, rebuild first: `quarto render report`, `quarto render deck`, `node deck/make_pdf.js deck/deck.html deck/deck.pdf`, `quarto render deck/one_page_summary.qmd`, `Rscript analysis/scripts/50_key_numbers.R`, `python scripts/build/build_readme.py`, `python site/build_site.py`, then rerun the audit and commit.

## 3. Deploy the Shiny budget model

Details and options are in `app/DEPLOY.md`. Shortest path (shinyapps.io; sign in on the website, copy your own token from the account page, never commit it):

```r
install.packages("rsconnect")
rsconnect::setAccountInfo(name = "<account>", token = "<token>", secret = "<secret>")
rsconnect::deployApp("app", appName = "incretin-budget-impact")
```

The app needs only `app/` (it includes `bia.R` and `data/*.rds`; no database). Then put the app URL on the website: change the "Budget model (PDF)" button in `site/build_site.py` to the app URL (keep the PDF link in the Budget model section), run `python site/build_site.py`, commit, push.

## 4. Links

- The oncology site link (`https://erickyegon.github.io/oncology-rwe-nsclc/`) is set in the website strip and the README.
- The website "Budget model (PDF)" button points to `budget_impact_scenarios.pdf` until the Shiny app is deployed.
- GitHub links inside the report, deck and one-pager name `erickyegon/incretin-access-value`; they work once the repository is public.

## 5. After publishing

Check the Pages URL on a phone width and in dark mode; confirm `report.html`, `deck.pdf`, `one_page_summary.pdf` and `research_pack.pdf` open from the buttons; run `gh repo view erickyegon/incretin-access-value --web`.
