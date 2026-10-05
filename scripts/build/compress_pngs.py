"""Re-encodes the HTML-bound figure copies (*_report.png, *_web.png) as optimized 256-color PNGs (the figures use a handful of colors, so there is no visible loss),
which keeps the report, notebooks and site light on a phone. Run after the figure scripts: python scripts/build/compress_pngs.py"""
import pathlib
from PIL import Image
fd = pathlib.Path(__file__).resolve().parents[2] / "analysis" / "outputs" / "figures"
before = after = 0
for f in sorted(list(fd.glob("*_report.png")) + list(fd.glob("*_web.png"))):
    b = f.stat().st_size; im = Image.open(f).convert("RGB")
    q = im.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    q.save(f, optimize=True); before += b; after += f.stat().st_size
print(f"compressed {before/1e6:.1f} MB -> {after/1e6:.1f} MB")
