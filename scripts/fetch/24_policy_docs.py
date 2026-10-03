"""Step 5.12 (part 4): policy documents saved with URL and access date (reference documents, not data), plus the empty trial-inputs template."""
import csv
import re

from common import RAW, REF, download, get_logger, manifest_add, sha256_file, request
from covtool import to_text

log = get_logger("24_policy_docs")
DOCS = {
    "cms_medicare_glp1_bridge_page.html": "https://www.cms.gov/medicare/coverage/prescription-drug-coverage/medicare-glp-1-bridge",
    "cms_medicare_glp1_bridge_prescribers.pdf": "https://www.cms.gov/files/document/glp-1-prescribers-c-1.pdf",
    "cms_medicare_glp1_bridge_launch_press_release.html": "https://www.cms.gov/newsroom/press-releases/cms-launches-medicare-glp-1-bridge-expanding-access-glp-1-medications",
    "kff_medicaid_coverage_and_spending_glp1_2026-01-16.html": "https://www.kff.org/medicaid/medicaid-coverage-of-and-spending-on-glp-1s/",
}


def main():
    d = RAW / "policy_documents"
    for fn, url in DOCS.items():
        p = download(url, d / fn, "policy_documents", log, release="reference document (not data)", years="2026", notes="saved as published; access date in manifest")
        raw = p.read_bytes()
        t = to_text(type("R", (), {"content": raw, "text": raw.decode("utf-8", "replace")})())[0]
        (d / (fn.rsplit(".", 1)[0] + ".txt")).write_text(t, encoding="utf-8")
        tt = re.sub(r"\s+", " ", t)
        print(fn, len(tt), "| $50:", "$50" in tt, "| July 1, 2026:", "July 1, 2026" in tt, "| Dec 31, 2027:", "December 31, 2027" in tt)
    cols = ["trial", "drug", "dose", "population", "duration_weeks", "outcome", "value", "uncertainty", "source_citation", "doi", "page_or_table"]
    f = REF / "trial_inputs.csv"
    if not f.exists():
        with open(f, "w", newline="", encoding="utf-8") as fh:
            csv.writer(fh).writerow(cols)
    manifest_add(dataset="reference", file_name=f.name, source_url="template (efficacy inputs to be extracted by hand from published papers)", release_or_version="empty template",
                 years_covered="n/a", bytes=f.stat().st_size, sha256=sha256_file(f), row_count=0, notes="SURMOUNT-1, SURMOUNT-5, STEP-1 and others to be added later")


if __name__ == "__main__":
    main()
