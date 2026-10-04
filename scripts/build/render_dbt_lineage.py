"""Render dbt lineage images from dbt/target/manifest.json (run `dbt docs generate` first) with Graphviz.
  docs/figures/dbt_lineage.png            every seed, model and raw-source group of the project
  docs/figures/dbt_lineage_mart_did_panel.png   everything upstream of mart_did_panel
Raw sources are collapsed by family (sdud_state_2018..2026 -> one node) so the picture stays readable."""
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
manifest = json.loads((ROOT / "dbt" / "target" / "manifest.json").read_text(encoding="utf-8"))
OUT = ROOT / "docs" / "figures"
OUT.mkdir(parents=True, exist_ok=True)

COLORS = {"source": "#d9d9d9", "seed": "#fde9b6", "staging": "#cfe5f7", "intermediate": "#d6ecd2", "marts": "#f4c7c3"}


def family(name):
    f = re.sub(r"_(19|20)\d{2}(_p\d)?$", "", name)
    f = re.sub(r"^(nhanes_)(p_)?(.*?)(_l)?$", r"nhanes_\3", f) if f.startswith("nhanes_") else f
    return "raw." + f


nodes, edges = {}, set()
for uid, n in manifest["nodes"].items():
    if n["package_name"] != "incretin" or n["resource_type"] not in ("model", "seed"):
        continue
    layer = "seed" if n["resource_type"] == "seed" else n["path"].split("\\")[0].split("/")[0]
    nodes[uid] = (n["name"], layer)
for uid, s in manifest["sources"].items():
    nodes[uid] = (family(s["name"]), "source")


def label(uid):
    return nodes[uid][0]


for uid, n in manifest["nodes"].items():
    if uid not in nodes:
        continue
    for dep in n.get("depends_on", {}).get("nodes", []):
        if dep in nodes:
            edges.add((label(dep), label(uid)))
for uid, n in manifest["nodes"].items():
    pass
layer_of = {}
for uid, (name, layer) in nodes.items():
    layer_of[name] = layer


def render(keep, path):
    lines = ["digraph G {", "rankdir=LR; fontname=Helvetica; node [shape=box, style=filled, fontname=Helvetica, fontsize=10]; edge [color=\"#777777\"];"]
    for name in sorted(keep):
        lines.append(f'"{name}" [fillcolor="{COLORS[layer_of[name]]}"];')
    for a, b in sorted(edges):
        if a in keep and b in keep:
            lines.append(f'"{a}" -> "{b}";')
    legend = " ".join(f'<TD BGCOLOR="{c}">{l}</TD>' for l, c in COLORS.items())
    lines.append(f'legend [shape=none, style="", label=<<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0"><TR>{legend}</TR></TABLE>>];')
    lines.append("}")
    dot = path.with_suffix(".dot")
    dot.write_text("\n".join(lines), encoding="utf-8")
    subprocess.run(["dot", "-Tpng", "-Gdpi=110", str(dot), "-o", str(path)], check=True)
    dot.unlink()


render(set(layer_of), OUT / "dbt_lineage.png")
up, frontier = {"mart_did_panel"}, ["mart_did_panel"]
while frontier:
    cur = frontier.pop()
    for a, b in edges:
        if b == cur and a not in up:
            up.add(a)
            frontier.append(a)
render(up, OUT / "dbt_lineage_mart_did_panel.png")
print("nodes:", len(layer_of), "edges:", len(edges), "| mart_did_panel upstream nodes:", len(up))
