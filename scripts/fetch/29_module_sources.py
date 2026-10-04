"""Save the external source documents that Modules B, D and E cite (no figure is taken from memory): each document is downloaded, saved under
docs/sources/ (original file plus a plain-text copy) and logged in docs/sources/sources_log.csv with URL, access date and sha256. Idempotent.
The CMS Medicare GLP-1 Bridge pages were retrieved earlier (data/raw/policy_documents) and are copied in with their original access date."""
import csv
import hashlib
import html
import re
import shutil
from datetime import date
from pathlib import Path

from common import RAW, ROOT, get_logger, request

log = get_logger("29_module_sources")
OUT = ROOT / "docs" / "sources"
OUT.mkdir(parents=True, exist_ok=True)

SOURCES = [
    # (file stem, url, what it is used for)
    ("kff_poll_glp1_current_use_2025-11", "https://www.kff.org/public-opinion/poll-1-in-8-adults-say-they-are-currently-taking-a-glp-1-drug-for-weight-loss-diabetes-or-another-condition-even-as-half-say-the-drugs-are-difficult-to-afford/", "B3 current GLP-1 use among adults (question wording, date, margin of error)"),
    ("kff_poll_glp1_topline_2026-03", "https://files.kff.org/attachment/topline-kff-health-tracking-poll-march-2026.pdf", "B3 check for a more recent KFF GLP-1 use question"),
    ("nchs_data_brief_511_hypertension", "https://www.cdc.gov/nchs/data/databriefs/db511.pdf", "B2 hypertension definition used by NCHS (measured BP or medication)"),
    ("uscode_42_1396r8_medicaid_drug_rebate", "https://www.law.cornell.edu/uscode/text/42/1396r-8", "E1 statutory Medicaid basic rebate for brand (single source / innovator multiple source) drugs (Social Security Act section 1927)"),
    ("ispor_budget_impact_good_practice_II", "https://www.ispor.org/heor-resources/good-practices/article/principles-of-good-practice-for-budget-impact-analysis-ii", "E1 ISPOR budget impact analysis guideline (Sullivan et al., Value Health 2014;17:5-14)"),
    ("whitehouse_fact_sheet_mfn_2025-11", "https://www.whitehouse.gov/fact-sheets/2025/11/fact-sheet-president-donald-j-trump-announces-major-developments-in-bringing-most-favored-nation-pricing-to-american-patients/", "B4/E1 announced public-programme GLP-1 prices (Medicare and Medicaid)"),
    ("cms_medicare_glp1_bridge_faqs", "https://www.cms.gov/files/document/medicare-glp-1-bridge-expectations-faqs.pdf", "B4 Medicare GLP-1 Bridge FAQs"),
]
COPY_FROM_RAW = [("cms_medicare_glp1_bridge_page", "cms_medicare_glp1_bridge_page", "https://www.cms.gov/medicare/coverage/prescription-drug-coverage/medicare-glp-1-bridge", "B4 Medicare GLP-1 Bridge: dates, copay, criteria"),
                 ("cms_medicare_glp1_bridge_launch_press_release", "cms_medicare_glp1_bridge_launch_press_release", "https://www.cms.gov/newsroom/press-releases/cms-launches-medicare-glp-1-bridge-expanding-access-glp-1-medications", "B4 Bridge launch 2026-07-01"),
                 ("cms_medicare_glp1_bridge_prescribers", "cms_medicare_glp1_bridge_prescribers", "https://www.cms.gov/medicare/coverage/prescription-drug-coverage/medicare-glp-1-bridge", "B4 Bridge clinical criteria for prescribers")]


def to_text(path, content_type):
    if path.suffix.lower() == ".pdf":
        import pypdf
        return "\n".join((p.extract_text() or "") for p in pypdf.PdfReader(path).pages)
    t = path.read_text(encoding="utf-8", errors="ignore")
    t = re.sub(r"<script.*?</script>|<style.*?</style>", "", t, flags=re.S)
    return re.sub(r"[ \t]+", " ", html.unescape(re.sub(r"<[^>]+>", "\n", t)))


def main():
    logf = OUT / "sources_log.csv"
    rows = {}
    if logf.exists():
        rows = {r["file"]: r for r in csv.DictReader(open(logf, encoding="utf-8"))}
    for stem, url, use in SOURCES:
        ext = ".pdf" if url.lower().endswith(".pdf") else ".html"
        f = OUT / f"{stem}{ext}"
        if not f.exists():
            try:
                r = request("GET", url, log=log, timeout=120)
            except Exception as e:
                print("FAILED", stem, url, e)
                continue
            f.write_bytes(r.content)
        (OUT / f"{stem}.txt").write_text(to_text(f, ext), encoding="utf-8")
        rows[f.name] = dict(file=f.name, url=url, access_date=rows.get(f.name, {}).get("access_date", str(date.today())), sha256=hashlib.sha256(f.read_bytes()).hexdigest(), used_for=use)
    for stem, rawstem, url, use in COPY_FROM_RAW:
        for ext in (".html", ".pdf", ".txt"):
            src = RAW / "policy_documents" / f"{rawstem}{ext}"
            if src.exists():
                shutil.copy(src, OUT / src.name)
                rows[src.name] = dict(file=src.name, url=url, access_date="2026-10-03", sha256=hashlib.sha256(src.read_bytes()).hexdigest(), used_for=use)
    with open(logf, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=["file", "url", "access_date", "sha256", "used_for"])
        w.writeheader()
        w.writerows(rows.values())
    print(len(rows), "files logged")


if __name__ == "__main__":
    main()
