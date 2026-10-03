"""Step 4a (part 2): save current openFDA label JSON per in-scope brand; used to verify label_group.
Also reused by Phase 5 (5.12). Raw JSON -> data/raw/openfda_label/<brand>.json"""
import json

from common import RAW, get_logger, manifest_add, request, sha256_file

log = get_logger("01_openfda_labels")
# Brand names come from RxNorm BN concepts for in-scope ingredients (see 00_*), plus Adlyxin/Tanzeum
# which appear in the RxNorm class membership / FDA directory history.
BRANDS = ["Wegovy", "Ozempic", "Rybelsus", "Zepbound", "Mounjaro", "Saxenda", "Victoza", "Trulicity",
          "Byetta", "Bydureon", "Bydureon BCise", "Foundayo", "Adlyxin", "Soliqua", "Xultophy", "Tanzeum"]


def main():
    out = RAW / "openfda_label"
    out.mkdir(parents=True, exist_ok=True)
    for b in BRANDS:
        f = out / f"{b.replace(' ', '_')}.json"
        if f.exists():
            log.info("skip %s", b)
            continue
        try:
            r = request("GET", "https://api.fda.gov/drug/label.json", log=log, timeout=45,
                        params={"search": f'openfda.brand_name:"{b}"', "limit": 25})
            j = r.json()
        except Exception as e:
            log.warning("no label for %s: %s", b, e)
            f.write_text(json.dumps({"brand": b, "error": str(e), "results": []}), encoding="utf-8")
            continue
        f.write_text(json.dumps(j), encoding="utf-8")
        manifest_add(dataset="openfda_label", file_name=f.name,
                     source_url=f"https://api.fda.gov/drug/label.json?search=openfda.brand_name:\"{b}\"",
                     release_or_version=f"openFDA last_updated {j['meta'].get('last_updated')}",
                     years_covered="current label", bytes=f.stat().st_size, sha256=sha256_file(f),
                     row_count=len(j["results"]), notes="label JSON; indications_and_usage used for label_group")
        log.info("%s: %d label records", b, len(j["results"]))


if __name__ == "__main__":
    main()
