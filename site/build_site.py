"""Builds the project website into site/ (static, GitHub Pages ready, NOT published): fills index.html from analysis/outputs/key_numbers.csv
and copies the report, deck PDF, one-page summary, research pack and the event-study figure. Run: python site/build_site.py"""
import csv, html, pathlib, shutil
root = pathlib.Path(__file__).resolve().parents[1]
site = root / "site"
kn = {r["id"]: r for r in csv.DictReader(open(root / "analysis" / "outputs" / "key_numbers.csv", encoding="utf-8"))}
d = lambda i: html.escape(kn[i]["display"])
ci = lambda i: html.escape(kn[i]["ci_or_range"])
alt = {r["figure"]: r["alt_text"] for r in csv.DictReader(open(root / "analysis" / "outputs" / "figures" / "alt_text.csv", encoding="utf-8"))}
(site / "assets").mkdir(exist_ok=True)
copies = {root / "report" / "report.html": site / "report.html", root / "deck" / "deck.pdf": site / "deck.pdf", root / "deck" / "one_page_summary.pdf": site / "one_page_summary.pdf",
          root / "research_pack" / "research_pack.pdf": site / "research_pack.pdf", root / "analysis" / "outputs" / "budget_impact_scenarios.pdf": site / "budget_impact_scenarios.pdf",
          root / "analysis" / "outputs" / "figures" / "10_event_study_primary.png": site / "assets" / "event_study.png"}
for s, t in copies.items():
    if s.exists(): shutil.copyfile(s, t)
    else: print("MISSING", s)
page = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Access and Value: obesity drugs in Medicaid</title>
<meta name="description" content="Public-data study of Medicaid coverage of Wegovy and Zepbound: coverage effect, eligible population, prescribers and budget impact.">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap">
<link rel="stylesheet" href="style.css"></head>
<body>
<header class="wrap">
  <p class="eyebrow">Access &amp; Value · incretin drugs in Medicaid</p>
  <h1>Medicaid coverage of Wegovy and Zepbound added about {d("c_att_overall")} prescriptions per 1,000 enrollees per quarter; covering 1,000,000 enrollees would net about ${d("e_net5")} million over five years</h1>
  <p class="lede">Public aggregate data, a tested warehouse and scenario analysis: what coverage did, who is eligible, who prescribes, and what it could cost.</p>
  <p class="byline">Erick Kiprotich Yegon · Epidemiologist and data scientist</p>
  <nav class="buttons" aria-label="Project links">
    <a class="btn primary" href="report.html">Read the report</a>
    <a class="btn" href="deck.pdf">Insight deck (PDF)</a>
    <a class="btn" href="one_page_summary.pdf">One-page summary</a>
    <a class="btn" href="budget_impact_scenarios.pdf">Budget model (PDF)</a>
    <a class="btn" href="https://github.com/erickyegon/incretin-access-value">Code</a>
  </nav>
</header>
<main class="wrap">
  <section class="cards" aria-label="Key numbers">
    <div class="card"><span class="num">{d("c_att_overall")}</span><span class="unit">extra prescriptions per 1,000 enrollees per quarter</span><span class="ci">{ci("c_att_overall")}; coverage effect, 10 covering vs 34 never-covering jurisdictions</span></div>
    <div class="card"><span class="num">{d("b_eligible")} million</span><span class="unit">U.S. adults meet the FDA label criteria (lower bound)</span><span class="ci">{ci("b_eligible")} million; NHANES 2021-2023</span></div>
    <div class="card"><span class="num">${d("e_net5")} million</span><span class="unit">five-year net cost, 1,000,000 enrollees, central case (${d("e_pmpm")} per enrollee per month)</span><span class="ci">scenario range ${d("e_scen_min")} to ${d("e_scen_max")} million; rebate assumed</span></div>
  </section>
  <figure>
    <img src="assets/event_study.png" alt="{html.escape(alt['10_event_study_primary'])}" loading="lazy">
    <figcaption>Coverage effect by quarter since coverage began. Source: CMS State Drug Utilization Data and Medicaid enrollment. Part of the growth is national market growth.</figcaption>
  </figure>
  <section>
    <h2>What I did</h2>
    <ol class="pipeline" aria-label="Pipeline">
      <li>Medicaid · Part D · NHANES · MEPS · Open Payments</li><li>PostgreSQL</li><li>dbt ({d("build_models")} models, {d("build_tests")} tests)</li><li>R</li><li>Quarto · Shiny</li>
    </ol>
  </section>
  <section>
    <h2>What this shows</h2>
    <ul>
      <li>Coverage raised prescriptions from {d("c_es_e0")} in the first quarter to {d("c_es_e8")} per 1,000 enrollees after eight quarters, and the result holds across estimators.</li>
      <li>About {d("b_medicaid_elig")} million adults with Medicaid meet the label criteria; {d("b_glp1_all")} million U.S. adults currently use a GLP-1 drug.</li>
      <li>Primary care physicians wrote {d("d_share_pcp")}% of Part D incretin claims in 2024, which reflect diabetes and other covered uses, not obesity use.</li>
      <li>The biggest unknown in the budget is the rebate: the central case uses {d("e_rebate_central")}%, the midpoint of {d("e_rebate_low")}% (statutory minimum) and {d("e_rebate_high")}% (implied by the announced ${d("x_price_245")} price).</li>
    </ul>
  </section>
  <section id="budget-model"><h2>Budget model</h2>
    <p>The budget impact scenarios are in <a href="budget_impact_scenarios.pdf">a PDF</a>. The interactive model is a Shiny app in the repository (run it locally with <code>shiny::runApp("app")</code>); it is not hosted yet. The design pack for primary research is <a href="research_pack.pdf">here</a>.</p></section>
  <section class="strip" aria-label="Portfolio"><h2>Two projects, one portfolio</h2>
    <div class="two"><a class="proj" href="https://erickyegon.github.io/oncology-rwe-nsclc/"><strong>Evidence</strong><span>Real-world oncology data (NSCLC): survival and outcomes</span></a>
    <a class="proj current" href="#top" aria-current="page"><strong>Access &amp; Value</strong><span>Incretin drugs in Medicaid: coverage, prescribers, budget impact</span></a></div>
</section>
</main>
<footer class="wrap small">
  <p><strong>Disclaimer.</strong> Public aggregate data; no company affiliation or endorsement; not patient-level claims; gross of rebates unless stated; associations and scenarios, not effects of any company's promotion.</p>
  <p>I used AI tools to help write code and documentation. The study design, methods and conclusions are my own, and I verified all results.</p>
</footer>
</body></html>
"""
(site / "index.html").write_text(page, encoding="utf-8")
print("site built:", site / "index.html")
