"""Step 5.2: Medicaid enrollment denominators (data.medicaid.gov; datasets found by title in the metastore).

 1. PI dataset "State Medicaid and CHIP Applications, Eligibility Determinations, and Enrollment Data":
    monthly total Medicaid / CHIP enrollment by state (P = preliminary and U = updated rows both kept).
 2. "Managed Care Enrollment Summary" (datastore API, all years): yearly total Medicaid enrollees and managed care counts.
 3. "Managed Care Information for Medicaid and CHIP Beneficiaries by Month" / "by Year": managed care enrollment by
    participation type (comprehensive MCO, PCCM, MLTSS, ...), with the CMS data-usability flag (dunusable).
"""
import json
import re

import pandas as pd

from common import INTERIM, RAW, download, get_logger, manifest_add, medicaid_catalog, request, sha256_file

log = get_logger("04_enrollment")
RAWD, OUT = RAW / "enrollment", INTERIM / "enrollment"
TITLES = {
    "pi": "State Medicaid and CHIP Applications, Eligibility Determinations, and Enrollment Data",
    "mc_summary": "Managed Care Enrollment Summary",
    "mc_month": "Managed Care Information for Medicaid and CHIP Beneficiaries by Month",
    "mc_year": "Managed Care Information for Medicaid and CHIP Beneficiaries by Year",
}


def num(s):
    """'1,234' -> 1234.0; blanks and non-numeric ('--', 'N/A') -> NaN (never 0)."""
    return pd.to_numeric(s.astype(str).str.replace(",", "").str.strip(), errors="coerce")


def main():
    RAWD.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    cat = {i["title"]: i for i in medicaid_catalog(log)}
    ds = {}
    for k, t in TITLES.items():
        ds[k] = cat[t]
        log.info("%s -> %s modified %s", k, ds[k]["identifier"], ds[k]["modified"])

    def dl(k):
        i = ds[k]
        url = i["distribution"][0]["data"]["downloadURL"]
        return download(url, RAWD / url.rsplit("/", 1)[1], f"enrollment_{k}", log,
                        release=f"dataset {i['identifier']} modified {i['modified']}", years="see notes")

    # 1. PI monthly
    pi = pd.read_csv(dl("pi"), dtype=str)
    keep = ["State Abbreviation", "State Name", "Reporting Period", "State Expanded Medicaid", "Preliminary or Updated",
            "Final Report", "Total Medicaid and CHIP Enrollment", "Total Medicaid Enrollment", "Total CHIP Enrollment",
            "Total Adult Medicaid Enrollment", "Medicaid and CHIP Child Enrollment"]
    keep += [c + " - footnotes" for c in keep[6:]]
    p = pi[keep].copy()
    p.columns = [re.sub(r"\W+", "_", c.lower()).strip("_") for c in p.columns]
    for c in p.columns:
        if c.startswith("total_") and not c.endswith("footnotes") or c == "medicaid_and_chip_child_enrollment":
            p[c] = num(p[c])
    # CMS reports 0 (with a footnote such as "Unable to Provide Data due to System Limitations") when a state could not
    # report; a Medicaid program does not have 0 enrollees, so a 0 total is missing data -> NULL, flagged.
    tot = ["total_medicaid_and_chip_enrollment", "total_medicaid_enrollment", "total_chip_enrollment"]
    p["enrollment_zero_set_null"] = (p[tot] == 0).any(axis=1)
    for c in tot:
        p.loc[p[c] == 0, c] = float("nan")
    p["month"] = pd.to_datetime(p.reporting_period, format="%Y%m")
    p.to_parquet(OUT / "medicaid_chip_enrollment_monthly.parquet", index=False)

    # 2. managed care summary (datastore, paginated)
    rows, off = [], 0
    mid = ds["mc_summary"]["identifier"]
    while True:
        r = request("GET", f"https://data.medicaid.gov/api/1/datastore/query/{mid}/0", log=log,
                    params={"limit": 500, "offset": off, "count": "true"}).json()
        rows += r["results"]
        off += 500
        if off >= r["count"]:
            break
    s = pd.DataFrame(rows)
    s["state_clean"] = s.state.str.replace(r"\d+$", "", regex=True).str.strip()
    for c in s.columns:
        if c.startswith(("total_", "medicaid_")):
            s[c + "_n"] = num(s[c])
    s.to_parquet(OUT / "managed_care_enrollment_summary_yearly.parquet", index=False)
    (RAWD / "managed_care_enrollment_summary_datastore.json").write_text(json.dumps(rows), encoding="utf-8")

    # 3. managed care by month / year
    m = pd.read_csv(dl("mc_month"), dtype=str)
    m["count_enrolled_n"] = num(m.CountEnrolled)
    m.to_parquet(OUT / "managed_care_enrollment_monthly_by_type.parquet", index=False)
    y = pd.read_csv(dl("mc_year"), dtype=str)
    for c in ("CountEverEnrolled", "CountLastMonthEnrollment", "AverageEnrollmentPerMonth"):
        y[c + "_n"] = num(y[c])
    y.to_parquet(OUT / "managed_care_enrollment_yearly_by_type.parquet", index=False)

    for f, n, yrs in [("medicaid_chip_enrollment_monthly.parquet", len(p), f"{p.reporting_period.min()}-{p.reporting_period.max()}"),
                      ("managed_care_enrollment_summary_yearly.parquet", len(s), f"{s.year.min()}-{s.year.max()}"),
                      ("managed_care_enrollment_monthly_by_type.parquet", len(m), f"{m.Month.min()}-{m.Month.max()}"),
                      ("managed_care_enrollment_yearly_by_type.parquet", len(y), f"{y.Year.min()}-{y.Year.max()}")]:
        pth = OUT / f
        manifest_add(dataset="enrollment", file_name=f, source_url="data.medicaid.gov (see enrollment_* raw rows)",
                     release_or_version="see raw rows", years_covered=yrs, bytes=pth.stat().st_size,
                     sha256=sha256_file(pth), row_count=n, notes="parsed to Parquet; blanks/non-numeric -> NULL")
    log.info("done")


if __name__ == "__main__":
    main()
