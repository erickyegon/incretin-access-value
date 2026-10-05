"""Tiles PNGs into one image for review: python scripts/qa/montage.py out.png cols width a.png b.png ..."""
import sys
from PIL import Image
out, cols, w = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]); fs = sys.argv[4:]
ims = [Image.open(f).convert("RGB") for f in fs]; ims = [i.resize((w, int(i.height * w / i.width))) for i in ims]
rows = [ims[i:i + cols] for i in range(0, len(ims), cols)]; H = sum(max(i.height for i in r) + 8 for r in rows)
sh = Image.new("RGB", (cols * (w + 8), H), "#cccccc"); y = 0
for r in rows:
    for k, im in enumerate(r): sh.paste(im, (k * (w + 8), y))
    y += max(i.height for i in r) + 8
sh.save(out)
