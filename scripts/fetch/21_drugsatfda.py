"""Step 5.12 (part 2): Drugs@FDA data files (FDA page 'Drugs@FDA Data Files', link /media/89850/download).
In-scope applications = products whose ActiveIngredient contains an in-scope ingredient. Outputs: applications and products,
all submissions with action dates (original approvals and supplements, with submission class and type), label document links.
Original approval date = earliest ActionDate of an approved ORIG submission. Nothing is taken from memory."""
import io
import re
import zipfile

import pandas as pd

from common import INTERIM, RAW, download, get_logger, manifest_add, sha256_file

log = get_logger("21_drugsatfda")
URL = "https://www.fda.gov/media/89850/download?attachment"
ING = r"SEMAGLUTIDE|TIRZEPATIDE|ORFORGLIPRON|LIRAGLUTIDE|DULAGLUTIDE|EXENATIDE|LIXISENATIDE|ALBIGLUTIDE"


def main():
    out = INTERIM / "drugsatfda"
    out.mkdir(parents=True, exist_ok=True)
    z = download(URL, RAW / "drugsatfda" / "drugsatfda.zip", "drugsatfda_raw", log, release="Drugs@FDA data files (page dated 2026-10-02)", years="all")
    t = {}
    with zipfile.ZipFile(z) as zf:
        log.info("members: %s", zf.namelist())
        for n in zf.namelist():
            if n.lower().endswith(".txt"):
                t[n.rsplit("/", 1)[-1][:-4]] = pd.read_csv(io.BytesIO(zf.read(n)), sep="\t", dtype=str, encoding="latin-1", on_bad_lines="skip")
    prod = t["Products"]
    sel = prod[prod.ActiveIngredient.fillna("").str.upper().str.contains(ING)]
    appl = sorted(set(sel.ApplNo))
    A = t["Applications"][t["Applications"].ApplNo.isin(appl)]
    S = t["Submissions"][t["Submissions"].ApplNo.isin(appl)].copy()
    S["SubmissionStatusDate"] = pd.to_datetime(S.SubmissionStatusDate, errors="coerce")
    cls = t.get("SubmissionClass_Lookup")
    if cls is not None:
        S = S.merge(cls, on="SubmissionClassCodeID", how="left")
    D = t["ApplicationDocs"][t["ApplicationDocs"].ApplNo.isin(appl)].copy() if "ApplicationDocs" in t else pd.DataFrame()
    M = t["MarketingStatus"][t["MarketingStatus"].ApplNo.isin(appl)] if "MarketingStatus" in t else pd.DataFrame()
    ms = t.get("MarketingStatus_Lookup")
    if ms is not None and len(M):
        M = M.merge(ms, on="MarketingStatusID", how="left")
    for name, df in (("products", sel), ("applications", A), ("submissions", S), ("application_docs", D), ("marketing_status", M)):
        f = out / f"drugsatfda_{name}.parquet"
        df.to_parquet(f, index=False)
        manifest_add(dataset="drugsatfda", file_name=f.name, source_url=URL, release_or_version="Drugs@FDA data files 2026-10", years_covered="all",
                     bytes=f.stat().st_size, sha256=sha256_file(f), row_count=len(df), notes="filtered to in-scope active ingredients")
    # original approval dates
    orig = S[(S.SubmissionType == "ORIG") & (S.SubmissionStatus == "AP")].groupby("ApplNo").SubmissionStatusDate.min().rename("original_approval_date")
    sm = sel.groupby("ApplNo").agg(brands=("DrugName", lambda s: ";".join(sorted(set(s)))), ingredients=("ActiveIngredient", lambda s: ";".join(sorted(set(s)))),
                                   forms=("Form", lambda s: ";".join(sorted(set(s)))[:60])).join(orig)
    sm = sm.join(A.set_index("ApplNo")[["ApplType", "SponsorName"]])
    sm.to_csv(out / "inscope_applications_summary.csv", encoding="utf-8")
    print(len(appl), "in-scope applications")
    print(sm.sort_values("original_approval_date").to_string(max_colwidth=46))
    eff = S[(S.SubmissionType == "SUPPL") & (S.SubmissionStatus == "AP")]
    print("\napproved supplements:", len(eff), "| by class:", eff.get("SubmissionClassCodeDescription", pd.Series(dtype=str)).value_counts().head(8).to_dict())


if __name__ == "__main__":
    main()
