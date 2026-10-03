"""Step 4a (part 3): build data/reference/product_map.csv from FDA NDC directory + RxNorm (incl. historical NDCs).

ndc11 format: 11 digits, no dashes, 5-4-2 (labeler-product-package). FDA 4-4-2 / 5-3-2 / 5-4-1 codes are
zero-padded in the short segment to reach 5-4-2.
label_group is assigned from the FDA label indications text (openFDA, looked up by product NDC),
falling back to the same brand's classified labels; nothing is assigned from memory.
"""
import json
import re
import time
from collections import Counter, defaultdict

import duckdb
import pandas as pd
import requests

from common import RAW, REF, get_logger, manifest_add, request, sha256_file

log = get_logger("02_build_product_map")
IN_SCOPE = ["semaglutide", "tirzepatide", "liraglutide", "dulaglutide", "exenatide", "lixisenatide", "orforglipron"]
CANDIDATES = ["albiglutide"]  # found via RxNorm class; listed, not added
LABEL_DIR = RAW / "openfda_label" / "by_product_ndc"
OBES = re.compile(r"excess body weight|chronic weight management|weight reduction|reduce.{0,40}body weight", re.I)
DIAB = re.compile(r"glycemic control", re.I)


def ndc11(code):
    a, b, c = code.split("-")
    return a.zfill(5) + b.zfill(4) + c.zfill(2)


def ingredient_of(text):
    t = (text or "").lower()
    hits = [i for i in IN_SCOPE + CANDIDATES if i in t]
    return hits


def classify(text):
    """Return label_group from indications text. Only the indications section is read."""
    head = re.split(r"limitations of use", text, flags=re.I)[0]
    o, d = bool(OBES.search(head)), bool(DIAB.search(head))
    if o and d:
        return "both"
    return "obesity" if o else "diabetes" if d else None


def label_for_product(product_ndc):
    f = LABEL_DIR / f"{product_ndc}.json"
    if not f.exists():
        LABEL_DIR.mkdir(parents=True, exist_ok=True)
        try:
            j = request("GET", "https://api.fda.gov/drug/label.json", log=log, timeout=45,
                        params={"search": f'openfda.product_ndc:"{product_ndc}"', "limit": 5}).json()
        except requests.HTTPError as e:
            if e.response is None or e.response.status_code != 404:
                raise  # transient failure: do not cache
            j = {"results": []}  # openFDA returns 404 when there is no match
        f.write_text(json.dumps(j), encoding="utf-8")
        time.sleep(0.3)
    j = json.loads(f.read_text(encoding="utf-8"))
    res = [r for r in j.get("results", []) if r.get("indications_and_usage")]
    if not res:
        return None
    r = sorted(res, key=lambda x: x.get("effective_time", ""), reverse=True)[0]
    text = " ".join(r["indications_and_usage"])
    return {"group": classify(text), "eff": r.get("effective_time"), "set_id": r.get("set_id"),
            "mfr": (r["openfda"].get("manufacturer_name") or [""])[0]}


def main():
    # ---------- FDA current directory ----------
    pat = "|".join(i.upper() for i in IN_SCOPE + CANDIDATES)
    prod = duckdb.sql(f"""select * from read_csv('{RAW}/fda_ndc/ndctext/product.txt', delim='\t', header=true,
        all_varchar=true, ignore_errors=true, quote='')
        where regexp_matches(upper(coalesce(SUBSTANCENAME,'')), '{pat}')""").df()
    pack = duckdb.sql(f"""select * from read_csv('{RAW}/fda_ndc/ndctext/package.txt', delim='\t', header=true,
        all_varchar=true, ignore_errors=true, quote='')""").df()
    lab_names = duckdb.sql(f"""select split_part(PRODUCTNDC,'-',1) lc, any_value(LABELERNAME) nm
        from read_csv('{RAW}/fda_ndc/ndctext/product.txt', delim='\t', header=true, all_varchar=true,
        ignore_errors=true, quote='') group by 1""").df()
    lab_by_code = {r.lc.zfill(5): r.nm for r in lab_names.itertuples()}
    pack = pack[pack.PRODUCTNDC.isin(prod.PRODUCTNDC)]
    log.info("FDA in-scope products %d, packages %d", len(prod), len(pack))

    rows = {}
    for p in prod.itertuples():
        hits = ingredient_of(p.SUBSTANCENAME)
        brand = (p.PROPRIETARYNAME or "").strip()
        generic = (p.NONPROPRIETARYNAME or "").strip()
        is_generic = brand.lower() == generic.lower() or not brand
        for pk in pack[pack.PRODUCTNDC == p.PRODUCTNDC].itertuples():
            n = ndc11(pk.NDCPACKAGECODE)
            rows[n] = dict(
                ndc11=n, product_ndc=p.PRODUCTNDC, ingredient=hits[0] if hits else None,
                ingredient_all=";".join(hits),
                is_combination="Y" if ";" in (p.SUBSTANCENAME or "") else "N",
                brand=None if is_generic else brand.title() if brand.isupper() else brand,
                dosage_form=p.DOSAGEFORMNAME, route=p.ROUTENAME,
                strength=f"{p.ACTIVE_NUMERATOR_STRENGTH} {p.ACTIVE_INGRED_UNIT}",
                labeler_name=p.LABELERNAME, marketing_category=p.MARKETINGCATEGORYNAME,
                application_number=p.APPLICATIONNUMBER,
                fda_start=pk.STARTMARKETINGDATE or p.STARTMARKETINGDATE, fda_end=pk.ENDMARKETINGDATE or p.ENDMARKETINGDATE,
                package_description=pk.PACKAGEDESCRIPTION, source="FDA_NDC_DIRECTORY")

    # ---------- RxNorm ----------
    rx = json.loads((RAW / "rxnorm" / "rxnorm_raw.json").read_text(encoding="utf-8"))
    concept_ing = {}
    for ing, ids in rx["ingredients"].items():
        for rxcui in ids:
            for g in rx["related"][rxcui]["allRelatedGroup"]["conceptGroup"]:
                if g["tty"] in ("SCD", "SBD", "GPCK", "BPCK"):
                    for c in g.get("conceptProperties", []):
                        concept_ing.setdefault(c["rxcui"], set()).add(ing)
    fda_set = set(rows)
    rx_dates = defaultdict(lambda: [None, None])
    cand_rows = {}
    for rxcui, h in rx["concept_history"].items():
        ings = concept_ing.get(rxcui, set())
        for t in (h["historical"].get("historicalNdcConcept") or {}).get("historicalNdcTime", []):
            for nt in t["ndcTime"]:
                for n in nt["ndc"]:
                    d = rx_dates[n]
                    d[0] = min(filter(None, [d[0], nt["startDate"]])) if nt.get("startDate") else d[0]
                    d[1] = max(filter(None, [d[1], nt["endDate"]])) if nt.get("endDate") else d[1]
                    st = rx["ndc_status"].get(n, {}).get("ndcStatus", {})
                    name = h["meta"]["name"]
                    m = re.search(r"\[(.+?)\]", name)
                    rec = dict(ndc11=n, ingredient=sorted(ings)[0] if ings else None,
                               ingredient_all=";".join(sorted(ings)), rxcui=st.get("rxcui") or rxcui,
                               rx_name=st.get("conceptName") or name, rx_status=st.get("status"),
                               brand_rx=m.group(1) if m else None)
                    if ings & set(CANDIDATES):
                        cand_rows[n] = rec
                    elif n in rows and n not in fda_set:
                        pass  # RxNorm-only NDC already recorded from an earlier concept
                    elif n in rows:
                        rows[n].update(rxcui=rec["rxcui"], rx_name=rec["rx_name"], rx_status=rec["rx_status"],
                                       source="FDA_NDC_DIRECTORY+RXNORM")
                    else:
                        rec.update(source="RXNORM_ONLY", is_combination="Y" if len(concept_ing.get(rxcui, [])) > 1 else "N")
                        rows[n] = rec
    df = pd.DataFrame(rows.values())
    # RxNorm lists some inner-unit NDCs (e.g. ...-01) that the FDA package file omits; inherit the FDA
    # product record via the 9-digit labeler+product key.
    prod["pkey"] = prod.PRODUCTNDC.map(lambda c: c.split("-")[0].zfill(5) + c.split("-")[1].zfill(4))
    pk = {r.pkey: r for r in prod.itertuples()}
    for i, r in df[df.source == "RXNORM_ONLY"].iterrows():
        p = pk.get(r.ndc11[:9])
        if p is None:
            continue
        brand, generic = (p.PROPRIETARYNAME or "").strip(), (p.NONPROPRIETARYNAME or "").strip()
        df.at[i, "product_ndc"] = p.PRODUCTNDC
        df.at[i, "brand"] = None if (brand.lower() == generic.lower() or not brand) else brand
        df.at[i, "dosage_form"], df.at[i, "route"] = p.DOSAGEFORMNAME, p.ROUTENAME
        df.at[i, "strength"] = f"{p.ACTIVE_NUMERATOR_STRENGTH} {p.ACTIVE_INGRED_UNIT}"
        df.at[i, "labeler_name"], df.at[i, "marketing_category"] = p.LABELERNAME, p.MARKETINGCATEGORYNAME
        df.at[i, "application_number"] = p.APPLICATIONNUMBER
        df.at[i, "source"] = "RXNORM+FDA_PRODUCT_9DIGIT"
    for c in ["brand", "dosage_form", "route", "strength", "labeler_name", "rx_name", "rx_status", "brand_rx",
              "rxcui", "marketing_category", "application_number", "product_ndc", "fda_start", "fda_end"]:
        if c not in df:
            df[c] = None
    df["brand"] = df["brand"].fillna(df["brand_rx"])
    df["brand"] = df["brand"].map(lambda b: re.sub(r"\s+\d+(\.\d+)?/\d+(\.\d+)?$", "", b).strip() if isinstance(b, str) else b)
    df["brand"] = df["brand"].map(lambda b: b.title() if isinstance(b, str) and b.isupper() else b)
    df["labeler_name"] = df["labeler_name"].fillna(df.ndc11.str[:5].map(lab_by_code))
    # remaining RxNorm-only rows (obsolete NDCs not in the FDA directory): parse form/route/strength from the
    # RxNorm concept name; route is derived (injectables -> SUBCUTANEOUS, "Oral" -> ORAL), documented in docs.
    def parse_form(n):
        n = re.sub(r"\[.*?\]", "", n or "")
        m = re.search(r"(Extended Release Injectable Suspension|Auto-Injector|Pen Injector|Prefilled Syringe|"
                      r"Injectable Solution|Oral Tablet|Injection|Cartridge)", n, re.I)
        return m.group(1) if m else None

    def parse_strength(n):
        m = re.findall(r"\d+(?:\.\d+)?\s*(?:MG|MCG|UNT)(?:/ML)?(?:\s*\|\s*)?", n or "", re.I)
        return " ".join(x.strip() for x in m) or None
    miss = df.dosage_form.isna()
    df.loc[miss, "dosage_form"] = df.loc[miss, "rx_name"].map(parse_form)
    df.loc[df.route.isna(), "route"] = df.loc[df.route.isna(), "rx_name"].map(
        lambda n: "ORAL" if re.search(r"Oral", n or "") else "SUBCUTANEOUS" if parse_form(n) else None)
    miss = df.strength.isna()
    df.loc[miss, "strength"] = df.loc[miss, "rx_name"].map(parse_strength)
    df["first_seen"] = df.ndc11.map(lambda n: rx_dates[n][0] if n in rx_dates else None)
    df["last_seen"] = df.ndc11.map(lambda n: rx_dates[n][1] if n in rx_dates else None)
    df["first_seen"] = df["first_seen"].fillna(df["fda_start"].str[:6])
    df["last_seen"] = df["last_seen"].fillna(df["fda_end"].str[:6])

    def status(r):
        if r.rx_status:
            return r.rx_status
        return "FDA_ONLY_ENDED" if r.fda_end else "FDA_ONLY_LISTED"
    df["ndc_status"] = df.apply(status, axis=1)

    # ---------- label_group from FDA label indications ----------
    lg, note = {}, {}
    pn = df.dropna(subset=["product_ndc"]).drop_duplicates("product_ndc")
    for r in pn.itertuples():
        info = label_for_product(r.product_ndc)
        if info and info["group"]:
            lg[r.product_ndc] = info["group"]
            note[r.product_ndc] = (f"openFDA label by product NDC; {info['mfr']}; label effective {info['eff']}; "
                                   f"set_id {info['set_id']}; classified from indications text")
    df["label_group"] = df.product_ndc.map(lg)
    df["label_note"] = df.product_ndc.map(note)
    df["label_verified"] = df.label_group.notna().map({True: "Y_product_label", False: None})
    # brand-level fallback: unique group among labelled rows of same brand+ingredient
    bg = df.dropna(subset=["label_group", "brand"]).groupby(["brand", "ingredient"]).label_group.agg(lambda s: set(s))
    for i, r in df[df.label_group.isna()].iterrows():
        key = (r.brand, r.ingredient)
        if r.brand and key in bg.index and len(bg[key]) == 1:
            df.at[i, "label_group"] = next(iter(bg[key]))
            df.at[i, "label_note"] = "no openFDA label for this product NDC; group inherited from same-brand labelled products"
            df.at[i, "label_verified"] = "Y_brand_label"
    # RxNorm-only brand rows whose brand never got a labelled product (e.g. obsolete brands): look up brand label
    brand_fb = {}
    for b in df[df.label_group.isna() & df.brand.notna()].brand.unique():
        f = RAW / "openfda_label" / f"{b.replace(' ', '_')}.json"
        groups = set()
        if f.exists():
            for r in json.loads(f.read_text(encoding="utf-8"))["results"]:
                if r.get("indications_and_usage"):
                    g = classify(" ".join(r["indications_and_usage"]))
                    if g:
                        groups.add(g)
        if len(groups) == 1:
            brand_fb[b] = groups.pop()
    for i, r in df[df.label_group.isna()].iterrows():
        if r.brand in brand_fb:
            df.at[i, "label_group"] = brand_fb[r.brand]
            df.at[i, "label_note"] = "group from openFDA brand-name label search (repackager/innovator label text)"
            df.at[i, "label_verified"] = "Y_brand_label"
    # Not verifiable from any current FDA label source (product discontinued, absent from FDA NDC directory,
    # openFDA and DailyMed). Group is the one expected in the project brief; flagged, re-check via Drugs@FDA.
    for i, r in df[df.label_group.isna() & (df.brand == "Bydureon")].iterrows():
        df.at[i, "label_group"] = "diabetes"
        df.at[i, "label_verified"] = "N_expected_unverified"
        df.at[i, "label_note"] = ("UNVERIFIED: no Bydureon label in openFDA/DailyMed/FDA NDC directory (discontinued); "
                                  "group = diabetes as expected in project brief; confirm via Drugs@FDA in phase 5")
    df["label_group"] = df["label_group"].fillna("unclassified")
    df["label_note"] = df["label_note"].fillna("no FDA label indication found; needs manual review")
    df["label_verified"] = df["label_verified"].fillna("N_unclassified")

    cols = ["ndc11", "ingredient", "brand", "dosage_form", "route", "strength", "labeler_name", "rxcui",
            "first_seen", "last_seen", "ndc_status", "label_group", "label_verified", "label_note", "source", "is_combination",
            "ingredient_all", "product_ndc", "marketing_category", "application_number", "rx_name",
            "package_description"]
    out = df[cols].sort_values(["ingredient", "brand", "ndc11"], na_position="last").reset_index(drop=True)
    out.to_csv(REF / "product_map.csv", index=False, encoding="utf-8")
    cand = pd.DataFrame(cand_rows.values())
    cand.to_csv(REF / "product_map_candidates_not_included.csv", index=False, encoding="utf-8")

    # ---------- validation ----------
    assert out.ndc11.str.fullmatch(r"\d{11}").all(), "ndc11 not 11 digits"
    assert not out.ndc11.duplicated().any(), "duplicate ndc11"
    assert out.ingredient.notna().all(), "NDC with no ingredient"
    print("rows", len(out), "| candidates not included:", len(cand))
    print(out.groupby(["ingredient", "brand"], dropna=False).agg(n=("ndc11", "size"), group=("label_group", lambda s: ",".join(sorted(set(s)))),
                                                                  active=("ndc_status", lambda s: (s == "ACTIVE").sum())).to_string())
    print(Counter(out.label_group))
    print(Counter(out.source))
    print(Counter(out.label_verified))
    print(out[out.label_group.isin(["unclassified", "both"]) | out.label_verified.str.startswith("N")][["ndc11", "ingredient", "brand", "labeler_name", "strength", "ndc_status", "label_group"]].to_string())
    f = REF / "product_map.csv"
    manifest_add(dataset="reference", file_name="product_map.csv", source_url="derived: FDA NDC Directory + RxNav + openFDA labels",
                 release_or_version="built " + time.strftime("%Y-%m-%d"), years_covered="current + historical NDCs",
                 bytes=f.stat().st_size, sha256=sha256_file(f), row_count=len(out), notes="see docs/data_sources.md")


if __name__ == "__main__":
    main()
