"""Build dbt seed label_events from the Drugs@FDA data files already downloaded (Phase 5). Nothing is typed from memory:
 - original approvals: earliest approved ORIG submission per application (Wegovy injection NDA 215256, Wegovy tablets NDA 218316, Zepbound 217806, Saxenda 206321);
 - indication supplements: for each approved supplement of Wegovy/Zepbound/Saxenda, the label PDF attached to THAT supplement (Drugs@FDA application docs, same
   SubmissionNo) is read; a supplement is an indication event when its indications text first contains 'cardiovascular' or 'sleep apnea'.
Every row carries the Drugs@FDA application number, supplement number and label URL."""
import io
import re
import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "fetch"))
from common import INTERIM, RAW, download, get_logger, manifest_add, sha256_file  # noqa: E402
from covtool import to_text  # noqa: E402

log = get_logger("build_label_events")
APPS = {"215256": "Wegovy", "218316": "Wegovy (tablets)", "217806": "Zepbound", "206321": "Saxenda", "220934": "Foundayo"}
O = INTERIM / "drugsatfda"
S = pd.read_parquet(O / "drugsatfda_submissions.parquet")
D = pd.read_parquet(O / "drugsatfda_application_docs.parquet")
for _df in (S, D):
    _df["SubmissionType"] = _df.SubmissionType.astype(str).str.strip()
    _df["SubmissionNo"] = _df.SubmissionNo.astype(str).str.replace(r"\.0$", "", regex=True)
S["d"] = pd.to_datetime(S.SubmissionStatusDate, errors="coerce")
rows = []
for appl, brand in APPS.items():
    s = S[S.ApplNo == appl]
    o = s[(s.SubmissionType == "ORIG") & (s.SubmissionStatus == "AP")].sort_values("d").head(1)
    for r in o.itertuples():
        rows.append(dict(brand=brand, event="original_approval", event_date=str(r.d.date()), application_number=appl, submission_type="ORIG", submission_no=r.SubmissionNo,
                         evidence=f"Drugs@FDA Submissions: approved ORIG submission {r.SubmissionNo}", label_url=""))
    sup = s[(s.SubmissionType == "SUPPL") & (s.SubmissionStatus == "AP")].sort_values("d")
    seen = {"cardiovascular": False, "sleep apnea": False}
    for r in sup.itertuples():
        docs = D[(D.ApplNo == appl) & (D.SubmissionType == "SUPPL") & (D.SubmissionNo == r.SubmissionNo) & D.ApplicationDocsURL.str.contains(r"/label/.*\.pdf", case=False, na=False)]
        if not len(docs):
            continue
        url = docs.sort_values("ApplicationDocsDate").iloc[-1].ApplicationDocsURL.replace("http://", "https://")
        url = re.sub(r"#page=\d+", "", url)
        try:
            p = download(url, RAW / "fda_labels" / "supplements" / f"{appl}_s{r.SubmissionNo}_{Path(url).name}", "fda_labels_suppl", log, release=f"Drugs@FDA supplement {r.SubmissionNo} label", years=str(r.d.year), notes=f"ApplNo {appl}")
            t, _ = to_text(type("R", (), {"content": p.read_bytes(), "text": ""})())
        except Exception as e:
            log.warning("%s s%s: %s", appl, r.SubmissionNo, str(e)[:80]); continue
        tt = re.sub(r"\s+", " ", t)
        m = re.search(r"INDICATIONS AND USAGE(.*?)DOSAGE AND ADMINISTRATION", tt)   # highlights indications text only
        ind = (m.group(1)[:2500] if m else "").lower()
        PAT = {"cardiovascular": (r"reduce the risk of (major adverse )?cardiovascular", "indication_cardiovascular"),
               "sleep apnea": (r"(treat|treatment of)[^.]{0,60}obstructive sleep apnea", "indication_obstructive_sleep_apnea")}
        for key, (rx, ev) in PAT.items():
            if re.search(rx, ind) and not seen[key]:
                seen[key] = True
                rows.append(dict(brand=brand, event=ev, event_date=str(r.d.date()), application_number=appl, submission_type="SUPPL", submission_no=r.SubmissionNo,
                                 evidence=f"first label whose INDICATIONS text states an indication matching /{rx}/ (supplement {r.SubmissionNo}, class {r.SubmissionClassCodeDescription})", label_url=url))
df = pd.DataFrame(rows).sort_values(["brand", "event_date"])
f = ROOT / "dbt" / "seeds" / "label_events.csv"
df.to_csv(f, index=False, encoding="utf-8")
manifest_add(dataset="seeds", file_name="label_events.csv", source_url="Drugs@FDA data files (data/interim/drugsatfda) + supplement label PDFs", release_or_version="dbt seed", years_covered="2014-2026",
             bytes=f.stat().st_size, sha256=sha256_file(f), row_count=len(df), notes="original approvals and CV / sleep apnea indication supplements, each with application and supplement number")
print(df[["brand", "event", "event_date", "application_number", "submission_no"]].to_string(index=False))
