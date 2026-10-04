"""Retrieve state Medicaid utilization-management documents (prior authorization criteria, provider notices) that the coverage table cites but earlier passes did not
save. Each document is downloaded to data/raw/coverage_sources/<STATE>/ (gitignored), a text copy is made with pdftotext (PDF) or tag stripping (HTML), and a row is
appended to data/raw/coverage_sources/_sources_log.csv (state, source_url, snapshot_timestamp, date_accessed, saved_as, chars). Idempotent.
Usage: python scripts/fetch/30_state_um_docs.py  (documents listed in DOCS below)"""
import csv, html, re, subprocess, urllib.request
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "data" / "raw" / "coverage_sources"
LOG = BASE / "_sources_log.csv"
DOCS = [  # (state, name, url)
    ("TN", "tenncare_provider_notice_obesity_mgmt_2025-08-01", "https://contenthub-aem.optumrx.com/content/dam/contenthub/onboarding/assets/Tenncare/Provider-Notice-Obesity-Management-Agents-08-01-25.pdf"),
    ("TN", "tenncare_pac_packet_2025-11-06", "https://contenthub-aem.optumrx.com/content/dam/contenthub/onboarding/assets/Tenncare/PAC-Packet-11-06-25.pdf"),
    ("TN", "tenncare_pa_form_obesity_management_agents", "https://contenthub-aem.optumrx.com/content/dam/contenthub/onboarding/assets/Tenncare/Obesity-Management-Agents-PA-Form.pdf"),
    ("MI", "mdhhs_mhp_common_formulary_pa_criteria_2025-09-01", "https://www.michigan.gov/mdhhs/-/media/Project/Websites/mdhhs/Assistance-Programs/Medicaid-BPHASA/MHP-Common-Formulary-PDL-PA-Criteria.pdf"),
    ("VA", "dmas_service_authorization_form_anti_obesity", "https://www.virginiamedicaidpharmacyservices.com/provider/external/medicaid/vamps/doc/en-us/VAMPS_SAform_Anti_Obesity.pdf"),
    ("VA", "dmas_service_authorization_form_weight_loss_management", "https://www.virginiamedicaidpharmacyservices.com/provider/external/medicaid/vamps/doc/en-us/VAMPS_SAform_Weight_Loss_Management.pdf"),
    ("WI", "forwardhealth_update_2025-16_july_2025_pdl", "https://www.forwardhealth.wi.gov/kw/pdf/2025-16.pdf"),
    ("WI", "forwardhealth_update_2024-16_july_2024_pdl", "https://www.forwardhealth.wi.gov/kw/pdf/2024-16.pdf"),
    ("WI", "dhs_f00163_1125", "https://www.dhs.wisconsin.gov/forms/f00163-1125.pdf"),
    ("RI", "eohhs_dur_board_minutes_2024-06-04", "https://eohhs.ri.gov/sites/g/files/xkgbur226/files/2024-06/dur_jun_24.pdf"),
    ("MO", "mo_healthnet_glp1_obesity_pdl_edit_2026", "https://dss.mo.gov/media/file/glucagon-peptide-1-glp-1-receptor-agonists-indicated-obesity-pdl-edit"),
    ("DE", "delaware_medicaid_publication_entry1398", "https://medicaidpublications.dhss.delaware.gov/docs/DesktopModules/Bring2mind/DMX/API/Entries/Download?Command=Core_Download&EntryId=1398&PortalId=0&TabId=94&language=en-US"),
]


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (research; incretin-access-value)"})
    return urllib.request.urlopen(req, timeout=120).read()


def main():
    rows = list(csv.DictReader(open(LOG, encoding="utf-8"))) if LOG.exists() else []
    have = {r["source_url"] for r in rows}
    for st, name, url in DOCS:
        d = BASE / st
        d.mkdir(exist_ok=True)
        is_pdf = url.lower().split("?")[0].endswith(".pdf")
        f = d / (name + (".pdf" if is_pdf else ".html"))
        if not f.exists() and not is_pdf and (d / (name + ".pdf")).exists():
            f = d / (name + ".pdf"); is_pdf = True
        if not f.exists():
            try:
                data = fetch(url)
                if data[:4] == b"%PDF":
                    is_pdf = True; f = d / (name + ".pdf")
                f.write_bytes(data)
            except Exception as e:
                print("FAILED", st, url, str(e)[:80])
                continue
        txt = d / (name + ".txt")
        if is_pdf:
            subprocess.run(["pdftotext", "-layout", str(f), str(txt)], check=False)
            t = txt.read_text(encoding="utf-8", errors="ignore") if txt.exists() else ""
        else:
            raw = f.read_bytes().decode("utf-8", errors="ignore")
            raw = re.sub(r"(?s)<script.*?</script>|<style.*?</style>", " ", raw)
            t = re.sub(r"[ \t]+", " ", html.unescape(re.sub(r"<[^>]+>", "\n", raw)))
            txt.write_text(t, encoding="utf-8")
        print(st, name, len(t), "chars")
        if url not in have:
            rows.append(dict(state=st, source_url=url, snapshot_timestamp="", date_accessed=str(date.today()), saved_as=f"{st}/{txt.name}", chars=len(t)))
            have.add(url)
    with open(LOG, "w", newline="", encoding="utf-8") as g:
        w = csv.DictWriter(g, fieldnames=["state", "source_url", "snapshot_timestamp", "date_accessed", "saved_as", "chars"])
        w.writeheader()
        w.writerows(rows)


if __name__ == "__main__":
    main()
