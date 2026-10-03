"""Step 4a (part 1): download FDA NDC directory files and pull RxNorm ingredient/NDC data.
Outputs raw files in data/raw/fda_ndc and data/raw/rxnorm. Product map is built by 01_build_product_map.py."""
import json
import zipfile

from common import RAW, download, get_logger, request, manifest_add, sha256_file

log = get_logger("00_fda_ndc_rxnorm")
FDA = {
    "ndctext.zip": "https://www.accessdata.fda.gov/cder/ndctext.zip",
    "ndc_excluded.zip": "https://www.accessdata.fda.gov/cder/ndc_excluded.zip",
    "ndc_unfinished.zip": "https://www.accessdata.fda.gov/cder/ndc_unfinished.zip",
}
RX = "https://rxnav.nlm.nih.gov/REST"
INGREDIENTS = ["semaglutide", "tirzepatide", "liraglutide", "dulaglutide", "exenatide",
               "lixisenatide", "orforglipron",
               "albiglutide"]  # albiglutide: found in RxNorm class A10BJ; kept as a CANDIDATE only (not in product map)


def rx_json(path, **params):
    return request("GET", f"{RX}/{path}", log=log, params=params, headers={"Accept": "application/json"}).json()


def main():
    d = RAW / "fda_ndc"
    for name, url in FDA.items():
        p = download(url, d / name, "fda_ndc", log, release="current directory as downloaded",
                     years="current", notes="FDA NDC Directory file")
        with zipfile.ZipFile(p) as z:
            z.extractall(d / p.stem)
            log.info("extracted %s: %s", name, z.namelist())

    out = RAW / "rxnorm"
    out.mkdir(parents=True, exist_ok=True)
    # 1. ingredient RxCUIs (IN, MIN, PIN) by exact name
    ing = {}
    for name in INGREDIENTS:
        j = rx_json("rxcui.json", name=name, search=2)
        ids = j.get("idGroup", {}).get("rxnormId", [])
        ing[name] = ids
        log.info("ingredient %s -> %s", name, ids)
    # 2. everything related to each ingredient: SCD/SBD/SCDC/BN/etc. (allrelated)
    related = {}
    for name, ids in ing.items():
        for rxcui in ids:
            related[rxcui] = rx_json(f"rxcui/{rxcui}/allrelated.json")
    # 3. per concept: NDCs (current) + NDC status history (includes obsolete/historical NDCs)
    concepts = {}
    for rxcui, j in related.items():
        for grp in j["allRelatedGroup"]["conceptGroup"]:
            if grp["tty"] in ("SCD", "SBD", "GPCK", "BPCK"):
                for c in grp.get("conceptProperties", []):
                    concepts[c["rxcui"]] = {"name": c["name"], "tty": c["tty"]}
    log.info("%d SCD/SBD/pack concepts", len(concepts))
    history = {}
    for i, (rxcui, meta) in enumerate(concepts.items()):
        j = rx_json(f"rxcui/{rxcui}/allhistoricalndcs.json", history=1)
        history[rxcui] = {"meta": meta, "historical": j}
        if i % 25 == 0:
            log.info("ndc history %d/%d", i, len(concepts))
    # 3b. per-NDC status (ACTIVE/OBSOLETE/ALIEN/UNKNOWN) and current rxcui
    all_ndcs = sorted({n for h in history.values()
                       for t in (h["historical"].get("historicalNdcConcept") or {}).get("historicalNdcTime", [])
                       for nt in t["ndcTime"] for n in nt["ndc"]})
    log.info("%d distinct NDCs; fetching status", len(all_ndcs))
    ndc_status = {}
    for n in all_ndcs:
        ndc_status[n] = rx_json("ndcstatus.json", ndc=n)
    # 4. drug class: GLP-1 RA members from RxClass (ATC A10BJ = GLP-1 analogues)
    cls = rx_json("rxclass/classMembers.json", classId="A10BJ", relaSource="ATC")
    payload = {"ingredients": ing, "related": related, "concept_history": history, "ndc_status": ndc_status, "atc_A10BJ_members": cls}
    f = out / "rxnorm_raw.json"
    f.write_text(json.dumps(payload), encoding="utf-8")
    ver = request("GET", f"{RX}/version.json", log=log).json()
    manifest_add(dataset="rxnorm", file_name=f.name, source_url=RX, release_or_version=json.dumps(ver),
                 years_covered="historical to current", bytes=f.stat().st_size, sha256=sha256_file(f),
                 notes="RxNav REST: rxcui, allrelated, allhistoricalndcs, ndcstatus, rxclass ATC A10BJ")


if __name__ == "__main__":
    main()
