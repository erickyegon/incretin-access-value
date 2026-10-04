"""Writes docs/sources_index.csv: every saved source document, whether its copy is kept in the repository or only locally.
Inputs (local): docs/sources_local/sources_log.csv (log of the saved documents under docs/sources and docs/sources_local), data/raw/coverage_sources/_sources_log.csv
(state policy documents, local only) and data/manifest.csv. Copies of copyrighted third-party pages and documents (KFF, ISPOR, Sawtooth, journal articles, Cornell LII)
are kept only in docs/sources_local/ (gitignored); U.S. government documents and open-licence package manuals are kept in docs/sources/.
Run: python scripts/build/build_sources_index.py"""
import csv, hashlib, pathlib, re, urllib.parse
root = pathlib.Path(__file__).resolve().parents[2]
src, loc = root / "docs" / "sources", root / "docs" / "sources_local"
META = {  # stem: (title, publisher, keep in repo?, reason)
 "kff_poll_glp1_current_use_2025-11": ("KFF Health Tracking Poll: 1 in 8 adults say they are currently taking a GLP-1 drug (Nov 2025 poll)", "KFF", False, "copyrighted third-party publication"),
 "kff_poll_glp1_topline_2026-03": ("KFF Health Tracking Poll topline, March 2026", "KFF", False, "copyrighted third-party publication"),
 "nchs_data_brief_511_hypertension": ("NCHS Data Brief No. 511, October 2024", "National Center for Health Statistics (CDC)", True, "U.S. government document"),
 "uscode_42_1396r8_medicaid_drug_rebate": ("42 U.S.C. 1396r-8, Payment for covered outpatient drugs (Cornell LII copy)", "Legal Information Institute, Cornell Law School", False, "third-party site copy of the statute"),
 "ispor_budget_impact_good_practice_II": ("Principles of Good Practice for Budget Impact Analysis II (ISPOR Task Force)", "ISPOR", False, "copyrighted third-party publication"),
 "whitehouse_fact_sheet_mfn_2025-11": ("Fact Sheet: President Donald J. Trump announces major developments in bringing most-favored-nation pricing (November 2025)", "The White House", True, "U.S. government document"),
 "cms_medicare_glp1_bridge_faqs": ("Medicare GLP-1 Bridge Expectations and FAQs", "Centers for Medicare & Medicaid Services", True, "U.S. government document"),
 "cms_medicare_glp1_bridge_page": ("Medicare GLP-1 Bridge (CMS web page)", "Centers for Medicare & Medicaid Services", True, "U.S. government document"),
 "cms_medicare_glp1_bridge_launch_press_release": ("CMS launches Medicare GLP-1 Bridge, expanding access to GLP-1 medications (press release)", "Centers for Medicare & Medicaid Services", True, "U.S. government document"),
 "cms_medicare_glp1_bridge_prescribers": ("Medicare GLP-1 Bridge: information for prescribers (June 2026)", "Centers for Medicare & Medicaid Services", True, "U.S. government document"),
 "sawtooth_sample_size_rules_of_thumb": ("Sample size rule of thumb for a choice-based conjoint (CBC) study", "Sawtooth Software", False, "copyrighted third-party publication"),
 "debekkergrob_dce_sample_size_2015": ("Sample size requirements for discrete-choice experiments in healthcare: a practical guide (de Bekker-Grob et al., 2015)", "The Patient (Springer), via PubMed Central", False, "copyrighted journal article"),
 "cran_idefix": ("idefix: Efficient Designs for Discrete Choice Experiments (R package manual)", "CRAN (package author F. Traets)", True, "open-licence R package manual"),
 "cran_AlgDesign": ("AlgDesign: Algorithmic Experimental Design (R package manual)", "CRAN (package author B. Wheeler)", True, "open-licence R package manual"),
}
URL_FIX = {"cms_medicare_glp1_bridge_prescribers": "https://www.cms.gov/files/document/glp-1-prescribers-c-1.pdf"}
TOKEN = re.compile(rb"pk\.eyJ[A-Za-z0-9._-]+")
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
rows, seen_urls = [], set()
log = {}
for r in csv.DictReader(open(loc / "sources_log.csv", encoding="utf-8")):
    log[pathlib.Path(r["file"]).stem] = r | {"file": r["file"]}
stems = {}
for r in csv.DictReader(open(loc / "sources_log.csv", encoding="utf-8")):
    stems.setdefault(pathlib.Path(r["file"]).stem, []).append(r)
for stem, rs in stems.items():
    title, pub, keep, why = META[stem]
    prim = [r for r in rs if not r["file"].endswith(".txt")] or rs
    r = prim[0]; fname = r["file"]
    if keep:   # government documents and open-licence manuals are copied from the local archive into the repository folder
        src.mkdir(exist_ok=True)
        for r2 in rs:
            if (loc / r2["file"]).exists():
                b = (loc / r2["file"]).read_bytes()
                if r2["file"].endswith(".html"): b = TOKEN.sub(b"pk.REDACTED-third-party-public-token", b)   # the CMS pages embed a Mapbox public token that GitHub push protection flags
                (src / r2["file"]).write_bytes(b)
    if keep:   # keep an unredacted original in the local archive, then redact the embedded third-party token in the repository copy
        for r2 in rs:
            f2 = src / r2["file"]
            if f2.exists() and not (loc / r2["file"]).exists(): (loc / r2["file"]).write_bytes(f2.read_bytes())
            if f2.exists() and r2["file"].endswith(".html"): f2.write_bytes(TOKEN.sub(b"pk.REDACTED-third-party-public-token", f2.read_bytes()))
    here = (src if keep else loc) / fname
    url = URL_FIX.get(stem, r["url"])
    rows.append(dict(title=title, publisher=pub, url=url, date_accessed=r["access_date"], sha256_of_saved_copy=sha(here) if here.exists() else r["sha256"],
                     in_repo="yes" if keep else "no", saved_copy=("docs/sources/" + fname) if keep else ("docs/sources_local/" + fname + " (gitignored)"), reason=why + ("; an embedded third-party Mapbox public token is redacted in the repository copy, so its checksum differs from the original" if keep and fname.endswith(".html") and stem.startswith("cms_") else ""))); seen_urls.add(url)
def domain_pub(u): return urllib.parse.urlparse(u).netloc
cov = root / "data" / "raw" / "coverage_sources"
if (cov / "_sources_log.csv").exists():
    for r in csv.DictReader(open(cov / "_sources_log.csv", encoding="utf-8")):
        u = r["source_url"]
        if u in seen_urls: continue
        f = cov / r["saved_as"]; seen_urls.add(u)
        title = urllib.parse.unquote(u.rstrip("/").split("/")[-1].split("?")[0]) or u
        rows.append(dict(title=f"{title} (state policy document, {r['state']})", publisher=domain_pub(u), url=u, date_accessed=r["date_accessed"], sha256_of_saved_copy=sha(f) if f.exists() else "",
                         in_repo="no", saved_copy="data/raw/coverage_sources/" + r["saved_as"] + " (text extract, gitignored)", reason="saved locally only: data/raw is not tracked; the facts used are in data/reference/medicaid_obesity_coverage.csv"))
for r in csv.DictReader(open(root / "data" / "manifest.csv", encoding="utf-8")):
    if r["dataset"] in ("coverage_sources", "policy_documents") and r["source_url"] not in seen_urls and r["source_url"].startswith("http"):
        seen_urls.add(r["source_url"])
        rows.append(dict(title=r["file_name"], publisher=domain_pub(r["source_url"]), url=r["source_url"], date_accessed=r["date_accessed"], sha256_of_saved_copy=r["sha256"], in_repo="no",
                         saved_copy="data/raw/" + r["dataset"] + "/" + r["file_name"] + " (gitignored)", reason="saved locally only (third-party or raw data folder)"))
for t, p_, u, f_ in [("Once-Weekly Semaglutide in Adults with Overweight or Obesity (STEP 1; abstract)", "N Engl J Med via PubMed", "https://pubmed.ncbi.nlm.nih.gov/33567185/", "pubmed_step1_wilding_2021.xml"),
                     ("Tirzepatide Once Weekly for the Treatment of Obesity (SURMOUNT-1; abstract)", "N Engl J Med via PubMed", "https://pubmed.ncbi.nlm.nih.gov/35658024/", "pubmed_surmount1_jastreboff_2022.xml"),
                     ("Tirzepatide as Compared with Semaglutide for the Treatment of Obesity (SURMOUNT-5; abstract)", "N Engl J Med via PubMed", "https://pubmed.ncbi.nlm.nih.gov/40353578/", "pubmed_surmount5_aronne_2025.xml"),
                     ("Orforglipron, an Oral Small-Molecule GLP-1 Receptor Agonist for Obesity Treatment (ATTAIN-1; abstract)", "N Engl J Med via PubMed", "https://pubmed.ncbi.nlm.nih.gov/40960239/", "pubmed_attain1_orforglipron_2025.xml")]:
    if (loc / f_).exists():
        rows.append(dict(title=t, publisher=p_, url=u, date_accessed="2026-10-04", sha256_of_saved_copy=sha(loc / f_), in_repo="no", saved_copy="docs/sources_local/" + f_ + " (gitignored)", reason="copyrighted journal article (abstract record retrieved from PubMed by scripts/build/build_trial_inputs.py)"))
out = root / "docs" / "sources_index.csv"
with open(out, "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
print(len(rows), "sources;", sum(r["in_repo"] == "yes" for r in rows), "kept in the repository;", sum(r["in_repo"] == "no" for r in rows), "not in the repository")
