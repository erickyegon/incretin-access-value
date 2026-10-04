"""Fills data/reference/trial_inputs.csv (and the dbt seed copy) from the PubMed abstracts of the pivotal trials, saved locally under docs/sources_local/pubmed_*.xml
(retrieved with NCBI E-utilities efetch; abstracts only). Each value and interval is checked against the abstract text before it is written, and the citation, DOI,
PMID and NCT number are read from the PubMed record, never typed from memory. Run: python scripts/build/build_trial_inputs.py"""
import csv, html, pathlib, re, shutil
root = pathlib.Path(__file__).resolve().parents[2]
loc = root / "docs" / "sources_local"
XML = {"STEP 1": "pubmed_step1_wilding_2021.xml", "SURMOUNT-1": "pubmed_surmount1_jastreboff_2022.xml", "SURMOUNT-5": "pubmed_surmount5_aronne_2025.xml", "ATTAIN-1": "pubmed_attain1_orforglipron_2025.xml"}
POP = {"STEP 1": "adults with BMI >=30 (>=27 with >=1 weight-related coexisting condition) without diabetes; lifestyle intervention in both arms",
       "SURMOUNT-1": "adults with BMI >=30, or >=27 with >=1 weight-related complication, excluding diabetes",
       "SURMOUNT-5": "adults with obesity but without type 2 diabetes (open-label, head-to-head)", "ATTAIN-1": "adults with obesity without diabetes (oral drug)"}
WEEKS = {"STEP 1": 68, "SURMOUNT-1": 72, "SURMOUNT-5": 72, "ATTAIN-1": 72}
N = {"STEP 1": 1961, "SURMOUNT-1": 2539, "SURMOUNT-5": 751, "ATTAIN-1": 3127}
# (trial, arm, drug, dose, value, ci_low, ci_high); value = mean percent change in body weight from baseline to the end of treatment (treatment-regimen/primary estimand as in the abstract)
ROWS = [("STEP 1", "semaglutide", "semaglutide", "2.4 mg once weekly (subcutaneous)", -14.9, None, None), ("STEP 1", "placebo", "placebo", "", -2.4, None, None),
        ("STEP 1", "difference (semaglutide minus placebo)", "semaglutide", "2.4 mg once weekly", -12.4, -13.4, -11.5),
        ("SURMOUNT-1", "tirzepatide 5 mg", "tirzepatide", "5 mg once weekly (subcutaneous)", -15.0, -15.9, -14.2), ("SURMOUNT-1", "tirzepatide 10 mg", "tirzepatide", "10 mg once weekly", -19.5, -20.4, -18.5),
        ("SURMOUNT-1", "tirzepatide 15 mg", "tirzepatide", "15 mg once weekly", -20.9, -21.8, -19.9), ("SURMOUNT-1", "placebo", "placebo", "", -3.1, -4.3, -1.9),
        ("SURMOUNT-5", "tirzepatide", "tirzepatide", "maximum tolerated dose (10 mg or 15 mg) once weekly", -20.2, -21.4, -19.1), ("SURMOUNT-5", "semaglutide", "semaglutide", "maximum tolerated dose (1.7 mg or 2.4 mg) once weekly", -13.7, -14.9, -12.6),
        ("ATTAIN-1", "orforglipron 6 mg", "orforglipron", "6 mg once daily (oral)", -7.5, -8.2, -6.8), ("ATTAIN-1", "orforglipron 12 mg", "orforglipron", "12 mg once daily", -8.4, -9.1, -7.7),
        ("ATTAIN-1", "orforglipron 36 mg", "orforglipron", "36 mg once daily", -11.2, -12.0, -10.4), ("ATTAIN-1", "placebo", "placebo", "", -2.1, -2.8, -1.4)]


def rec(trial):
    t = (loc / XML[trial]).read_text(encoding="utf-8")
    ab = html.unescape(" ".join(re.sub(r"<[^>]+>", "", x) for x in re.findall(r"<AbstractText[^>]*>(.*?)</AbstractText>", t, re.S)))
    ab = ab.replace("−", "-").replace("–", "-")
    au = re.findall(r"<Author [^>]*>.*?<LastName>(.*?)</LastName>.*?<Initials>(.*?)</Initials>", t, re.S)
    jt = re.search(r"<ISOAbbreviation>(.*?)</ISOAbbreviation>", t).group(1)
    vol = re.search(r"<Volume>(.*?)</Volume>", t).group(1); pg = re.search(r"<MedlinePgn>(.*?)</MedlinePgn>", t).group(1)
    yr = re.search(r"<PubDate>.*?<Year>(\d{4})</Year>", t, re.S).group(1)
    doi = re.search(r'<ArticleId IdType="doi">(.*?)</ArticleId>', t).group(1); pmid = re.search(r"<PMID[^>]*>(\d+)</PMID>", t).group(1)
    nct = re.search(r"(NCT\d{8})", ab).group(1)
    title = html.unescape(re.sub(r"<[^>]+>", "", re.search(r"<ArticleTitle>(.*?)</ArticleTitle>", t, re.S).group(1)))
    cite = f"{au[0][0]} {au[0][1]} et al. {title} {jt}. {yr};{vol}:{pg}"
    return dict(ab=ab, cite=cite, doi=doi, pmid=pmid, nct=nct)


def check(ab, v, lo, hi):   # each number must appear in the abstract text
    for x in (v, lo, hi):
        if x is not None:
            s = f"{x:.1f}".replace("-", "")
            assert re.search(r"(?<![\d.])" + re.escape(s) + r"(?!\d)", ab), (x, "not in abstract")


recs = {t: rec(t) for t in XML}
out = []
for trial, arm, drug, dose, v, lo, hi in ROWS:
    r = recs[trial]; check(r["ab"], v, lo, hi)
    unc = "95% CI" if lo is not None else "arm-level CI not stated in the abstract"
    out.append(dict(trial=trial, arm=arm, drug=drug, dose=dose, population=POP[trial], duration_weeks=WEEKS[trial], outcome="mean percent change in body weight from baseline to end of treatment (primary end point)" if "difference" not in arm else "estimated treatment difference in percent change in body weight (percentage points)",
                    value=v, uncertainty=unc, ci_low="" if lo is None else lo, ci_high="" if hi is None else hi, n_randomised=N[trial], source_citation=r["cite"], doi=r["doi"], pmid=r["pmid"], nct_id=r["nct"], page_or_table="abstract (PubMed " + r["pmid"] + ")"))
ref = root / "data" / "reference" / "trial_inputs.csv"
with open(ref, "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=list(out[0].keys())); w.writeheader(); w.writerows(out)
shutil.copyfile(ref, root / "dbt" / "seeds" / "trial_inputs.csv")
print(len(out), "rows written;", {t: r["cite"][:70] for t, r in recs.items()})
