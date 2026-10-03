"""Step 5.12 (part 3): latest approved label PDF per in-scope NDA/BLA from Drugs@FDA (ApplicationDocs, label type), saved to
data/raw/fda_labels/<ApplNo>_<brand>_<date>.pdf, plus the indications text. Used to verify label_group (obesity vs diabetes) where
openFDA had no innovator label (Wegovy, Ozempic injection, Bydureon). openFDA label JSON per brand is already in data/raw/openfda_label."""
import re

import pandas as pd

from common import INTERIM, RAW, download, get_logger, manifest_add, sha256_file
from covtool import to_text
from common import request

log = get_logger("22_fda_labels")


def main():
    O = INTERIM / "drugsatfda"
    A = pd.read_parquet(O / "drugsatfda_applications.parquet")
    P = pd.read_parquet(O / "drugsatfda_products.parquet")
    D = pd.read_parquet(O / "drugsatfda_application_docs.parquet")
    names = P.groupby("ApplNo").DrugName.agg(lambda s: sorted(set(s))[0])
    lab = D[D.ApplicationDocsURL.str.contains(r"/label/.*\.pdf", case=False, na=False)].copy()
    lab["d"] = pd.to_datetime(lab.ApplicationDocsDate, errors="coerce")
    lab["url"] = lab.ApplicationDocsURL.str.replace("http://", "https://").str.replace(r"#page=\d+", "", regex=True)
    lat = lab.sort_values("d").groupby("ApplNo").tail(1)
    lat = lat[lat.ApplNo.isin(A[A.ApplType.isin(["NDA", "BLA"])].ApplNo)]
    out = RAW / "fda_labels"
    rows = []
    for r in lat.itertuples():
        brand = re.sub(r"\W+", "_", names.get(r.ApplNo, "x"))[:25]
        fn = f"{r.ApplNo}_{brand}_{r.d.date()}.pdf"
        try:
            p = download(r.url, out / fn, "fda_labels", log, release=f"Drugs@FDA label {r.d.date()}", years=str(r.d.year), notes=f"ApplNo {r.ApplNo}")
            t, _ = to_text(type("R", (), {"content": p.read_bytes(), "text": ""})())
        except Exception as e:
            log.warning("%s failed %s", r.ApplNo, str(e)[:80]); continue
        tt = re.sub(r"\s+", " ", t)
        m = re.search(r"INDICATIONS AND USAGE(.{0,900})", tt)
        ind = m.group(1) if m else ""
        glyc = bool(re.search(r"glycemic control", ind, re.I)); wt = bool(re.search(r"excess body weight|chronic weight management|weight reduction", ind, re.I))
        rows.append(dict(ApplNo=r.ApplNo, brand=names.get(r.ApplNo), label_date=str(r.d.date()), url=r.url, mentions_glycemic_control=glyc, mentions_weight_reduction=wt,
                         indications_excerpt=ind[:500]))
    df = pd.DataFrame(rows)
    df.to_csv(INTERIM / "drugsatfda" / "fda_label_indications_check.csv", index=False, encoding="utf-8")
    print(df[["ApplNo", "brand", "label_date", "mentions_glycemic_control", "mentions_weight_reduction"]].to_string(index=False))
    for a in ("209210", "022200"):
        x = df[df.ApplNo == a]
        if len(x):
            print("\n###", a, x.brand.iloc[0], x.label_date.iloc[0], "\n", x.indications_excerpt.iloc[0].encode("ascii", "replace").decode())


if __name__ == "__main__":
    main()
