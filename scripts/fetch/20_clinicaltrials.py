"""Step 5.12 (part 1): ClinicalTrials.gov API v2 studies with an in-scope intervention and a condition of obesity or type 2 diabetes.
One query per ingredient (query.intr), condition filter (obesity / overweight / type 2 diabetes), paginated by pageToken; results
de-duplicated by NCT ID. Keeps NCT ID, title, phase, status, start/completion dates, sponsor, enrollment, hasResults, interventions,
conditions. Raw pages saved. A study found under several ingredients lists all of them in `matched_ingredients`."""
import json

import pandas as pd

from common import INTERIM, RAW, get_logger, manifest_add, request, sha256_file

log = get_logger("20_clinicaltrials")
API = "https://clinicaltrials.gov/api/v2/studies"
INGR = ["semaglutide", "tirzepatide", "orforglipron", "liraglutide", "dulaglutide", "exenatide", "lixisenatide", "albiglutide"]
COND = "(obesity OR overweight OR \"type 2 diabetes\" OR \"diabetes mellitus, type 2\" OR \"weight management\")"
FIELDS = ("NCTId,BriefTitle,OfficialTitle,Phase,OverallStatus,StartDate,PrimaryCompletionDate,CompletionDate,LeadSponsorName,LeadSponsorClass,"
          "EnrollmentCount,EnrollmentType,HasResults,Condition,InterventionName,StudyType,LastUpdatePostDate,ResultsFirstPostDate")


def main():
    out, raw = INTERIM / "clinicaltrials", RAW / "clinicaltrials"
    out.mkdir(parents=True, exist_ok=True); raw.mkdir(parents=True, exist_ok=True)
    rows = {}
    for ing in INGR:
        tok, n = None, 0
        while True:
            p = {"query.intr": ing, "query.cond": COND, "pageSize": 1000, "fields": FIELDS, "countTotal": "true", "format": "json"}
            if tok:
                p["pageToken"] = tok
            j = request("GET", API, log=log, params=p, timeout=300).json()
            (raw / f"ctgov_{ing}_{n}.json").write_text(json.dumps(j), encoding="utf-8")
            for s in j.get("studies", []):
                ps = s["protocolSection"]
                idm, st, sp, de, cm, ar = (ps.get("identificationModule", {}), ps.get("statusModule", {}), ps.get("sponsorCollaboratorsModule", {}),
                                           ps.get("designModule", {}), ps.get("conditionsModule", {}), ps.get("armsInterventionsModule", {}))
                nid = idm.get("nctId")
                r = rows.setdefault(nid, dict(nct_id=nid, title=idm.get("briefTitle"), official_title=idm.get("officialTitle"),
                    phase=";".join(de.get("phases", [])), status=st.get("overallStatus"), start_date=st.get("startDateStruct", {}).get("date"),
                    primary_completion_date=st.get("primaryCompletionDateStruct", {}).get("date"), completion_date=st.get("completionDateStruct", {}).get("date"),
                    sponsor=sp.get("leadSponsor", {}).get("name"), sponsor_class=sp.get("leadSponsor", {}).get("class"),
                    enrollment=de.get("enrollmentInfo", {}).get("count"), enrollment_type=de.get("enrollmentInfo", {}).get("type"),
                    results_posted=bool(s.get("hasResults")), conditions=";".join(cm.get("conditions", [])),
                    interventions=";".join(i.get("name", "") for i in ar.get("interventions", [])), study_type=de.get("studyType"),
                    last_update=st.get("lastUpdatePostDateStruct", {}).get("date"), matched_ingredients=set()))
                r["matched_ingredients"].add(ing)
            n += 1
            tok = j.get("nextPageToken")
            log.info("%s page %d: %d studies so far (total reported %s)", ing, n, len(rows), j.get("totalCount"))
            if not tok:
                break
    df = pd.DataFrame(rows.values())
    df["matched_ingredients"] = df.matched_ingredients.map(lambda s: ";".join(sorted(s)))
    f = out / "clinicaltrials_inscope.parquet"
    df.to_parquet(f, index=False)
    df.to_csv(out / "clinicaltrials_inscope.csv", index=False, encoding="utf-8")
    manifest_add(dataset="clinicaltrials", file_name=f.name, source_url=API, release_or_version="API v2 accessed", years_covered="all registered",
                 bytes=f.stat().st_size, sha256=sha256_file(f), row_count=len(df), notes="query.intr per ingredient AND query.cond obesity/overweight/type 2 diabetes/weight management; de-duplicated by NCT ID")
    print(len(df), "studies;", "with results posted:", int(df.results_posted.sum()))
    print(df.groupby("matched_ingredients").size().sort_values(ascending=False).head(10).to_string())
    print(df.phase.value_counts().head(8).to_string()); print(df.status.value_counts().head(8).to_string())


if __name__ == "__main__":
    main()
