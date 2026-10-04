"""List NHANES variables with their NCHS codebook description, from the saved NCHS documentation pages (data/raw/nhanes/*_doc.htm).
Usage: python nhanes_codebook_check.py FILE:VAR[,VAR...] ...   e.g. DIQ_L:DIQ010,DIQ050 P_DIQ:DIQ010
Prints variable, SAS label, English text and the code table (value: description) so each variable can be checked before use."""
import html
import re
import sys
from pathlib import Path

RAW = Path(__file__).resolve().parents[2] / "data" / "raw" / "nhanes"


def text_of(stem):
    t = (RAW / f"{stem}_doc.htm").read_text(encoding="utf-8", errors="ignore")
    t = re.sub(r"<script.*?</script>|<style.*?</style>", "", t, flags=re.S)
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", t)))


def describe(stem, var):
    t = text_of(stem)
    m0 = re.search(rf"Variable Name: {var} SAS Label:", t, flags=re.I)
    if not m0:
        return None
    i = m0.start()
    j = t.find("Variable Name:", i + 20)
    blk = t[i: j if j > 0 else len(t)]
    label = re.search(r"SAS Label: (.*?) English Text:", blk)
    eng = re.search(r"English Text: (.*?) Target:", blk)
    k = blk.find("Code or Value")
    codes = re.sub(r"Value Description Count Cumulative Skip to Item ", "", blk[k + 14:k + 330]) if k >= 0 else ""
    return dict(var=var, label=label.group(1) if label else "", english=eng.group(1) if eng else blk[:200], codes=codes)


if __name__ == "__main__":
    for arg in sys.argv[1:]:
        stem, vs = arg.split(":")
        for v in vs.split(","):
            d = describe(stem, v)
            print(f"[{stem}] {v}: " + ("NOT FOUND in documentation" if d is None else f"{d['english']} | label: {d['label']} | codes: {d['codes']}"))
