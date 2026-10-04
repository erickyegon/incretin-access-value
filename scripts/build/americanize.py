"""Switches public text to American spelling (and '1,000,000 enrollees' to '1 million enrollees'). Safe by construction: in code (R scripts, code chunks of .qmd files) only string literals that contain a space
are touched, so identifiers, column names and argument names (colour =, normalised, theme_grey) never change. Plain text (markdown, README builder, site builder text) is changed everywhere.
Run: python scripts/build/americanize.py [--check]   (--check lists remaining British words without writing)"""
import pathlib, re, sys
root = pathlib.Path(__file__).resolve().parents[2]
WORDS = [("programmes", "programs"), ("programme", "program"), ("modelling", "modeling"), ("modelled", "modeled"), ("labelling", "labeling"), ("labelled", "labeled"), ("organisations", "organizations"), ("organisational", "organizational"),
         ("organisation", "organization"), ("normalised", "normalized"), ("normalisation", "normalization"), ("utilisation", "utilization"), ("analysed", "analyzed"), ("analysing", "analyzing"), ("analyse", "analyze"), ("summarised", "summarized"),
         ("summarise", "summarize"), ("emphasised", "emphasized"), ("emphasise", "emphasize"), ("centres", "centers"), ("centre", "center"), ("licences", "licenses"), ("licence", "license"), ("judgement", "judgment"), ("favour", "favor"),
         ("prioritised", "prioritized"), ("prioritise", "prioritize"), ("recognised", "recognized"), ("recognise", "recognize"), ("minimisation", "minimization"), ("minimised", "minimized"), ("maximised", "maximized"),
         ("standardised", "standardized"), ("randomised", "randomized"), ("characterised", "characterized"), ("catalogue", "catalog"), ("whilst", "while"), ("per cent", "percent"), ("enrolment", "enrollment"),
         ("behaviour", "behavior"), ("coloured", "colored"), ("greyed", "grayed"), ("grey", "gray"), ("colours", "colors"), ("colour", "color")]
CODE_UNSAFE = {"colour", "colours", "grey"}   # may be code arguments or colour names in plain text only; handled by the string-literal rule in code
def sub_words(text, skip=()):
    for a, b in WORDS:
        if a in skip: continue
        text = re.sub(r"\b" + a + r"\b", b, text); text = re.sub(r"\b" + a.capitalize() + r"\b", b.capitalize(), text)
    text = text.replace("1,000,000 enrollees", "1 million enrollees").replace("1,000,000-enrollee", "1-million-enrollee").replace("1,000,000 enrolees", "1 million enrollees")
    return text
LIT = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
def code_text(text):
    return LIT.sub(lambda m: '"' + (sub_words(m.group(1)) if " " in m.group(1) else m.group(1)) + '"', text)
def qmd(text):
    out, incode = [], False
    for line in text.split("\n"):
        if line.lstrip().startswith("```"): incode = not incode; out.append(line); continue
        out.append(code_text(line) if incode else sub_words(line))
    return "\n".join(out)
def md(text): return sub_words(text)
FILES = {"qmd": ["report/report.qmd", "deck/deck.qmd", "deck/one_page_summary.qmd", "research_pack/research_pack.qmd"],
         "md": ["analysis/outputs/moduleB_summary.md", "analysis/outputs/moduleC_summary.md", "analysis/outputs/moduleD_summary.md", "analysis/outputs/moduleE_summary.md", "docs/data_dictionary.md", "docs/warehouse.md", "app/DEPLOY.md", "PUBLISH.md"],
         "py": ["scripts/build/build_readme.py", "site/build_site.py", "scripts/build/make_notebooks.py"]}
code_files = sorted(str(p.relative_to(root)).replace("\\", "/") for p in list((root / "analysis" / "scripts").glob("*.R")) + list((root / "analysis" / "R").glob("*.R")) + [root / "app" / "app.R", root / "research_pack" / "dce_design.R"])
changed = []
for kind, fs in [("qmd", FILES["qmd"]), ("md", FILES["md"]), ("py", FILES["py"]), ("code", code_files)]:
    for f in fs:
        p = root / f
        if not p.exists(): continue
        s = open(p, encoding="utf-8", newline="").read().replace("\r\n", "\n")
        t = qmd(s) if kind == "qmd" else (md(s) if kind == "md" else (sub_words(s, skip=CODE_UNSAFE) if kind == "py" else code_text(s)))
        if kind == "py":   # py builders hold HTML/CSS and Python code: colour/grey words stay only in CSS comments, so leave them; text words changed above
            pass
        if t != s:
            changed.append(f)
            if "--check" not in sys.argv: open(p, "w", encoding="utf-8", newline="").write(t)
print(("would change" if "--check" in sys.argv else "changed"), len(changed), "files:", ", ".join(changed))
