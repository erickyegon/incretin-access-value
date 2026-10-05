"""Renders every page of a PDF and tiles the pages into one contact-sheet PNG (for QA review).
Usage: python scripts/qa/pdf_contact_sheet.py in.pdf out.png [columns=4] [tile_width=420] [pages_dir]
With pages_dir, every page is also saved as page_NN.png at 110 dpi."""
import sys, pathlib, fitz
from PIL import Image, ImageDraw
pdf, out = sys.argv[1], sys.argv[2]
cols = int(sys.argv[3]) if len(sys.argv) > 3 else 4
tw = int(sys.argv[4]) if len(sys.argv) > 4 else 420
pages_dir = pathlib.Path(sys.argv[5]) if len(sys.argv) > 5 else None
doc = fitz.open(pdf); tiles = []
for i, pg in enumerate(doc):
    z = tw / pg.rect.width; pix = pg.get_pixmap(matrix=fitz.Matrix(z, z), alpha=False)
    im = Image.frombytes("RGB", (pix.width, pix.height), pix.samples); tiles.append(im)
    if pages_dir:
        pages_dir.mkdir(parents=True, exist_ok=True); z2 = 110 / 72; p2 = pg.get_pixmap(matrix=fitz.Matrix(z2, z2), alpha=False); p2.save(str(pages_dir / f"page_{i + 1:02d}.png"))
th = max(t.height for t in tiles); rows = (len(tiles) + cols - 1) // cols; pad = 14; lab = 18
sheet = Image.new("RGB", (cols * (tw + pad) + pad, rows * (th + pad + lab) + pad), "#e9e9e9"); d = ImageDraw.Draw(sheet)
for i, t in enumerate(tiles):
    x = pad + (i % cols) * (tw + pad); y = pad + (i // cols) * (th + pad + lab); d.text((x, y), f"page {i + 1}", fill="#333333"); sheet.paste(t, (x, y + lab))
sheet.save(out); print(f"{len(tiles)} pages -> {out}")
