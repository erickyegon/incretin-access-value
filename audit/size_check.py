"""Size check of what a push would send: tracked files (working-tree sizes) and the packed git history. Run: python audit/size_check.py"""
import os, subprocess, pathlib
root = pathlib.Path(__file__).resolve().parents[1]
files = [f for f in subprocess.run(["git", "-C", str(root), "ls-files"], capture_output=True, text=True).stdout.split("\n") if f]
sz = sorted(((os.path.getsize(root / f), f) for f in files if (root / f).exists()), reverse=True)
print(f"{len(sz)} tracked files, {sum(s for s, _ in sz) / 1e6:.1f} MB in the working tree")
print("largest:"); [print(f"  {s / 1e6:6.2f} MB  {f}") for s, f in sz[:6]]
subprocess.run(["git", "-C", str(root), "gc", "-q"])
out = subprocess.run(["git", "-C", str(root), "count-objects", "-vH"], capture_output=True, text=True).stdout
print([l for l in out.split("\n") if l.startswith("size-pack")][0].replace("size-pack", "packed history (what a push sends, approx.)"))
print("largest file limit on GitHub: 100 MB per file (none close).")
