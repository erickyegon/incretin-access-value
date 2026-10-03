"""Step 5.11: ICD-10-CM value sets from the CMS code-description file (tabular order), current fiscal year (FY2027, found on
https://www.cms.gov/medicare/coding-billing/icd-10-codes). Codes and descriptions come from the CMS order file, never typed.
Output data/reference/icd10_value_sets.csv: value_set, code (dotted), description, source_version (+ code_nodot, billable)."""
import re
import zipfile

import pandas as pd

from common import REF, RAW, download, get_logger, manifest_add, request, sha256_file

log = get_logger("19_icd10")
PAGE = "https://www.cms.gov/medicare/coding-billing/icd-10-codes"
SETS = {"type2_diabetes_E11": r"E11", "obesity_E66": r"E66", "bmi_z68": r"Z68"}


def main():
    h = request("GET", PAGE, log=log, timeout=200).text
    zips = [z for z in re.findall(r'href="([^"]+\.zip)"', h) if re.search(r"/\d{4}-code-descriptions-tabular-order\.zip$", z)]
    path = max(zips, key=lambda z: int(re.search(r"/(\d{4})-code", z).group(1)))  # highest fiscal year listed (FY2027 = current)
    fy = re.search(r"(\d{4})-code-descriptions", path).group(1)
    url = "https://www.cms.gov" + path
    z = download(url, RAW / "icd10cm" / f"{fy}-code-descriptions-tabular-order.zip", "icd10cm_raw", log, release=f"ICD-10-CM FY{fy}", years=f"FY{fy}")
    with zipfile.ZipFile(z) as zf:
        order = next(n for n in zf.namelist() if re.search(r"icd10cm_order_\d{4}\.txt$", n))
        lines = zf.read(order).decode("latin-1").splitlines()
    rows = []
    for ln in lines:
        code, flag, short, long = ln[6:13].strip(), ln[14:15], ln[16:77].strip(), ln[77:].strip()
        rows.append((code, flag, short, long))
    allc = pd.DataFrame(rows, columns=["code_nodot", "billable", "short_description", "description"])
    out = []
    for name, pat in SETS.items():
        s = allc[allc.code_nodot.str.startswith(pat)].copy()
        s["value_set"] = name
        out.append(s)
    v = pd.concat(out)
    v["code"] = v.code_nodot.map(lambda c: c if len(c) <= 3 else c[:3] + "." + c[3:])
    v["source_version"] = f"ICD-10-CM FY{fy} (CMS {path.split('/')[-1]}, {order})"
    v = v[["value_set", "code", "description", "source_version", "code_nodot", "billable"]]
    ph = pd.DataFrame([dict(value_set="comorbidities_PLACEHOLDER", code="", description="to be defined later (hypertension, dyslipidemia, OSA, CVD, etc.); no codes entered from memory",
                            source_version=v.source_version.iloc[0], code_nodot="", billable="")])
    v = pd.concat([v, ph], ignore_index=True)
    f = REF / "icd10_value_sets.csv"
    v.to_csv(f, index=False, encoding="utf-8")
    manifest_add(dataset="reference", file_name=f.name, source_url=url, release_or_version=f"ICD-10-CM FY{fy}", years_covered=f"FY{fy}",
                 bytes=f.stat().st_size, sha256=sha256_file(f), row_count=len(v), notes="from CMS tabular-order file; billable flag = CMS valid-for-submission flag")
    print(v.groupby("value_set").agg(n=("code", "size"), billable=("billable", lambda s: (s == "1").sum())).to_string())
    print(v.head(4)[["value_set", "code", "description"]].to_string(index=False))
    print("total codes in CMS file:", len(allc), "| source:", v.source_version.iloc[0])


if __name__ == "__main__":
    main()
