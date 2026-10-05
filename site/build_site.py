"""Builds the project website into site/ (static, GitHub Pages ready): fills index.html from analysis/outputs/key_numbers.csv, copies the report, deck PDF,
one-page summary, research pack and the web variant of the event-study figure, and writes the social preview image (1200 x 630) and the app landing page.
Run: python site/build_site.py   (the social image needs node and puppeteer-core: set NODE_PATH; it is skipped with a message otherwise)"""
import csv, html, os, pathlib, shutil, subprocess
root = pathlib.Path(__file__).resolve().parents[1]
site = root / "site"
SITE_URL = "https://erickyegon.github.io/incretin-access-value/"
APP_URL = "https://01a108a8-ecde-397c-5353-39196812b10c.share.connect.posit.cloud/"
kn = {r["id"]: r for r in csv.DictReader(open(root / "analysis" / "outputs" / "key_numbers.csv", encoding="utf-8"))}
d = lambda i: html.escape(kn[i]["display"])
ci = lambda i: html.escape(kn[i]["ci_or_range"])
holds = kn["c_spec_holds"]["display"].split(" of ")          # "15 of 15" -> "all 15 estimable"
HOLDS = f"all {holds[1]} estimable" if holds[0] == holds[1] else f"{kn['c_spec_holds']['display']} estimable"
alt = {r["figure"]: r["alt_text"] for r in csv.DictReader(open(root / "analysis" / "outputs" / "figures" / "alt_text.csv", encoding="utf-8"))}
(site / "assets").mkdir(exist_ok=True)
fig = root / "analysis" / "outputs" / "figures"
copies = {root / "report" / "report.html": site / "report.html", root / "deck" / "deck.pdf": site / "deck.pdf", root / "deck" / "one_page_summary.pdf": site / "one_page_summary.pdf",
          root / "research_pack" / "research_pack.pdf": site / "research_pack.pdf", root / "analysis" / "outputs" / "budget_impact_scenarios.pdf": site / "budget_impact_scenarios.pdf",
          fig / "10_event_study_primary_web.png": site / "assets" / "event_study.png"}
(site / "data").mkdir(exist_ok=True); (site / "notebooks").mkdir(exist_ok=True)
copies[root / "analysis" / "outputs" / "tables" / "coverage_um_criteria.csv"] = site / "data" / "coverage_um_criteria.csv"
copies[root / "analysis" / "outputs" / "key_numbers.csv"] = site / "data" / "key_numbers.csv"
for nbf in sorted((root / "notebooks").glob("*.html")): copies[nbf] = site / "notebooks" / nbf.name
for s, t in copies.items():
    if s.exists(): shutil.copyfile(s, t)
    else: print("MISSING", s)
rep = site / "report.html"
if rep.exists():   # the report links to ../notebooks/ in the repository; on the site the notebooks sit beside it
    rep.write_text(rep.read_text(encoding="utf-8").replace("../notebooks/", "notebooks/"), encoding="utf-8")

# ---- social preview image (1200 x 630): title, the three key numbers, author -------------------------------------------------------------------------
card = f"""<!doctype html><meta charset="utf-8"><style>
@font-face {{ font-family: "Source Serif 4"; font-weight: 600; src: url("file:///{(root / 'analysis' / 'assets' / 'fonts' / 'SourceSerif4-Semibold.ttf').as_posix()}"); }}
@font-face {{ font-family: "IBM Plex Sans"; font-weight: 400; src: url("file:///{(root / 'analysis' / 'assets' / 'fonts' / 'IBMPlexSans-Regular.ttf').as_posix()}"); }}
@font-face {{ font-family: "IBM Plex Sans"; font-weight: 600; src: url("file:///{(root / 'analysis' / 'assets' / 'fonts' / 'IBMPlexSans-SemiBold.ttf').as_posix()}"); }}
body {{ margin: 0; width: 1200px; height: 630px; background: #fff; font-family: "IBM Plex Sans", sans-serif; color: #222; position: relative; overflow: hidden; }}
.bar {{ position: absolute; left: 0; top: 0; width: 18px; height: 630px; background: #D55E00; }}
.eyebrow {{ position: absolute; left: 70px; top: 52px; font-size: 22px; letter-spacing: .06em; text-transform: uppercase; color: #D55E00; font-weight: 600; }}
h1 {{ position: absolute; left: 70px; top: 96px; width: 1060px; margin: 0; font-family: "Source Serif 4", serif; font-weight: 600; font-size: 45px; line-height: 1.18; }}
.nums {{ position: absolute; left: 70px; top: 340px; display: flex; gap: 24px; }}
.n {{ box-sizing: border-box; width: 340px; background: #f6f6f6; border-left: 8px solid #D55E00; padding: 18px 22px; }}
.n b {{ display: block; font-family: "Source Serif 4", serif; font-size: 54px; color: #D55E00; line-height: 1.05; }}
.n span {{ display: block; margin-top: 8px; font-size: 21px; line-height: 1.3; color: #444; }}
.by {{ position: absolute; left: 70px; bottom: 44px; font-size: 24px; color: #444; }} .by b {{ color: #222; }}
.src {{ position: absolute; right: 60px; bottom: 44px; font-size: 20px; color: #595959; }}
</style><div class="bar"></div><div class="eyebrow">Access &amp; Value · incretin drugs in Medicaid</div>
<h1>When state Medicaid programs covered Wegovy and Zepbound, prescriptions rose by an estimated {kn['c_att_overall']['display']} per 1,000 enrollees per quarter</h1>
<div class="nums">
<div class="n"><b>{kn['c_att_overall']['display']}</b><span>additional prescriptions per 1,000 enrollees per quarter ({kn['c_att_overall']['ci_or_range']})</span></div>
<div class="n"><b>${kn['e_net5']['display']}M</b><span>five-year net cost for 1 million enrollees (central case)</span></div>
<div class="n"><b>${kn['e_pmpm']['display']}</b><span>per enrollee per month, net of an assumed rebate</span></div></div>
<div class="by"><b>Erick Kiprotich Yegon</b> · Epidemiologist and data scientist</div><div class="src">Public CMS, NHANES and MEPS data</div>"""
(site / "assets" / "social_card.html").write_text(card, encoding="utf-8")
shot = root / "scripts" / "build" / "make_social_card.js"
try:
    subprocess.run(["node", str(shot), str(site / "assets" / "social_card.html"), str(site / "assets" / "social_preview.png")], check=True, env=os.environ)
except Exception as e:
    print("social preview not rebuilt (needs node and puppeteer-core):", e)
(site / "assets" / "social_card.html").unlink(missing_ok=True)

head = lambda title, desc, url, extra="": f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<meta name="description" content="{desc}">
<meta property="og:type" content="website"><meta property="og:title" content="{title}"><meta property="og:description" content="{desc}"><meta property="og:url" content="{url}">
<meta property="og:image" content="{SITE_URL}assets/social_preview.png"><meta property="og:image:width" content="1200"><meta property="og:image:height" content="630"><meta property="og:image:alt" content="Title card: {title}; three key numbers and the author">
<meta name="twitter:card" content="summary_large_image"><meta name="twitter:title" content="{title}"><meta name="twitter:description" content="{desc}"><meta name="twitter:image" content="{SITE_URL}assets/social_preview.png">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;500;600&family=Source+Serif+4:wght@500;600;700&display=swap">
<link rel="stylesheet" href="style.css">{extra}</head>"""

page = head("Access and Value: obesity drugs in Medicaid", "Public-data study of Medicaid coverage of Wegovy and Zepbound: coverage effect, eligible population, prescribers and budget impact.", SITE_URL) + f"""
<body id="top">
<header class="wrap">
  <p class="eyebrow">Access &amp; Value · incretin drugs in Medicaid</p>
  <h1>When state Medicaid programs covered Wegovy and Zepbound, prescriptions rose by an estimated {d("c_att_overall")} per 1,000 enrollees per quarter</h1>
  <p class="lede">Public aggregate data, a tested warehouse and scenario analysis: what coverage was associated with, who is eligible, who prescribes, and what it could cost a program of 1 million enrollees.</p>
  <p class="byline">Erick Kiprotich Yegon · Epidemiologist and data scientist · <a href="https://linkedin.com/in/erickyegon">LinkedIn</a> · <a href="mailto:keyegon@gmail.com">keyegon@gmail.com</a></p>
  <nav class="buttons" aria-label="Project links">
    <a class="btn primary" href="report.html">Read the report</a>
    <a class="btn primary" href="{APP_URL}">Interactive budget model</a>
    <a class="btn" href="deck.pdf">Insight deck (PDF)</a>
    <a class="btn" href="one_page_summary.pdf">One-page summary</a>
    <a class="btn" href="research_pack.pdf">Research design pack (PDF)</a>
    <a class="btn" href="budget_impact_scenarios.pdf">Budget model (PDF)</a>
    <a class="btn" href="https://github.com/erickyegon/incretin-access-value">Code</a>
  </nav>
</header>
<main class="wrap">
  <section class="cards" aria-label="Key numbers">
    <div class="card"><span class="num">{d("c_att_overall")}</span><span class="unit">estimated additional prescriptions per 1,000 enrollees per quarter</span><span class="ci">{ci("c_att_overall")}; {d("c_states_primary")} covering vs {d("c_states_never")} never-covering jurisdictions</span></div>
    <div class="card"><span class="num">{d("b_eligible")} million</span><span class="unit">U.S. adults meet the FDA label criteria (lower bound)</span><span class="ci">{ci("b_eligible")} million; NHANES 2021-2023</span></div>
    <div class="card"><span class="num">${d("e_net5")} million</span><span class="unit">five-year net cost, 1 million enrollees (central case)</span><span class="ci">${d("e_pmpm")} per enrollee per month; scenario range ${d("e_scen_min")} to ${d("e_scen_max")} million; rebate assumed</span></div>
  </section>
  <figure>
    <img src="assets/event_study.png" width="2475" height="1530" alt="{html.escape(alt['10_event_study_primary'])}" loading="eager">
    <figcaption><strong>Estimated coverage effect by quarter since coverage began.</strong> Source: CMS State Drug Utilization Data and Medicaid enrollment. Part of the growth is national market growth.</figcaption>
  </figure>
  <section>
    <h2>What I did</h2>
    <ol class="pipeline" aria-label="Pipeline">
      <li>Public data</li><li>PostgreSQL</li><li>dbt: {d("build_models")} models, {d("build_tests")} tests</li><li>R analysis</li><li>Quarto and Shiny</li>
    </ol>
    <p class="small">Sources: Medicaid State Drug Utilization Data and enrollment, Medicare Part D, NHANES, MEPS, Open Payments.</p>
  </section>
  <section>
    <h2>Methods shown</h2>
    <p>Causal inference (staggered difference-in-differences) · survey epidemiology · budget impact modeling with probabilistic sensitivity analysis · claims-derived data engineering (NDC, ICD-10, dbt) · market access insight.</p>
  </section>
  <section>
    <h2>What this shows</h2>
    <ul class="shows">
      <li>Coverage was associated with an estimated rise from {d("c_es_e0")} to {d("c_es_e8")} prescriptions per 1,000 enrollees per quarter over eight quarters; the estimate holds in {HOLDS} alternative analyses.</li>
      <li>About {d("b_medicaid_elig")} million adults with Medicaid, and {d("b_eligible")} million U.S. adults overall, meet the label criteria (lower bound).</li>
      <li>In 2024 cardiology wrote {d("d_wegovy_cardio")}% of Wegovy's Part D claims against {d("d_ozempic_cardio")}% of Ozempic's (<a href="report.html">details in the report</a>).</li>
      <li>Coverage works through managed care, in South Carolina and Rhode Island above all (<a href="report.html">see the report</a>).</li>
      <li>The rebate is the largest unknown in the budget: the central case uses {d("e_rebate_central")}%, between {d("e_rebate_low")}% and {d("e_rebate_high")}%.</li>
    </ul>
  </section>
  <section id="data"><h2>Data and notebooks</h2>
    <ul>
      <li><a href="data/coverage_um_criteria.csv">Coverage criteria table (CSV)</a>: prior authorization, BMI threshold, comorbidity requirement and step therapy for the 17 covering states, with sources.</li>
      <li><a href="data/key_numbers.csv">Key numbers (CSV)</a>: every number in the report, deck and this page, with its source file and row.</li>
      <li>Exploration notebooks: <a href="notebooks/A_data_layer.html">A data layer</a> · <a href="notebooks/B_eligible_population.html">B eligible population</a> · <a href="notebooks/C_coverage_study.html">C coverage study</a> · <a href="notebooks/D_prescribers.html">D prescribers</a> · <a href="notebooks/E_budget_impact.html">E budget impact</a>.</li>
    </ul></section>
  <section id="budget-model"><h2>Budget model</h2>
    <p>The <a href="{APP_URL}">interactive budget model</a> is a decision tool built around this project: set the plan size, uptake, prior authorization and price, then see the five-year net cost, its sensitivity drivers and a probabilistic range. Its defaults equal the numbers on this page. The scenarios are also in <a href="budget_impact_scenarios.pdf">a PDF</a>. The design pack for primary research is <a href="research_pack.pdf">here</a>.</p></section>
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

# ---- landing page for the interactive app (a link target with a preview, for LinkedIn and email) -------------------------------------------------------
landing = head("Interactive budget model: Medicaid coverage of Wegovy and Zepbound", "Decision tool for the five-year budget impact of Medicaid coverage of Wegovy and Zepbound, with the evidence, uncertainty and sources behind it.", SITE_URL + "budget-model.html") + f"""
<body><header class="wrap"><p class="eyebrow">Access &amp; Value · interactive budget model</p>
<h1>Five-year budget impact of Medicaid coverage of Wegovy and Zepbound: ${d("e_net5")} million net for 1 million enrollees</h1>
<p class="lede">Set the plan size, uptake, prior authorization and price, and see the cost, what drives it and how uncertain it is. Defaults equal the numbers in the report: ${d("e_pmpm")} per enrollee per month; scenario range ${d("e_scen_min")} to ${d("e_scen_max")} million.</p>
<nav class="buttons"><a class="btn primary" href="{APP_URL}" target="_blank" rel="noopener">Open in a new tab</a><a class="btn" href="budget_impact_scenarios.pdf">Scenarios (PDF)</a><a class="btn" href="index.html">Project site</a><a class="btn" href="report.html">Read the report</a></nav></header>
<main class="wrap">
<figure class="preview"><img src="assets/social_preview.png" width="1200" height="630" alt="Preview of the interactive budget model: title, the three key numbers and the author"></figure>
<section aria-label="Interactive budget model"><h2>Try it here</h2>
<div class="frame"><iframe src="{APP_URL}" title="Interactive budget model: Medicaid coverage of Wegovy and Zepbound" loading="lazy" allow="clipboard-write" referrerpolicy="no-referrer"></iframe></div>
<p class="small">The app loads in the frame above. If it does not appear, or you want more room, <a href="{APP_URL}" target="_blank" rel="noopener">open the interactive budget model in a new tab</a>. A static version of the scenarios is in <a href="budget_impact_scenarios.pdf">this PDF</a>.</p></section>
<p class="small">Public aggregate data; scenarios, not forecasts; gross of rebates unless stated. Erick Kiprotich Yegon · Epidemiologist and data scientist.</p></main></body></html>
"""
(site / "budget-model.html").write_text(landing, encoding="utf-8")
print("site built:", site / "index.html")
