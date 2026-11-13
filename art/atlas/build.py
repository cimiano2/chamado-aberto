"""Junta os sprites do mundo num único atlas (assets/sprites/atlas.png + atlas.json).
Com uma só textura, a placa de vídeo desenha piso, paredes, móveis e funcionários em poucos lotes.
Rode depois dos outros builds de arte:  python3 art/atlas/build.py
"""
import json, os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SPRITES = os.path.join(HERE, "..", "..", "assets", "sprites")
SKIP = {"technician.png", "technician_f.png", "atlas.png"}   # o técnico é recolorido em tempo real
PAD = 2

files = sorted(f for f in os.listdir(SPRITES) if f.endswith(".png") and f not in SKIP)
ims = {f[:-4]: Image.open(os.path.join(SPRITES, f)).convert("RGBA") for f in files}
# empacotamento em prateleiras: do mais alto para o mais baixo
order = sorted(ims, key=lambda n: (-ims[n].height, -ims[n].width))
W = 1024
x = y = shelf_h = 0
rects = {}
for n in order:
    im = ims[n]
    if x + im.width + PAD > W:
        x, y, shelf_h = 0, y + shelf_h + PAD, 0
    rects[n] = [x, y, im.width, im.height]
    x += im.width + PAD
    shelf_h = max(shelf_h, im.height)
H = 1
while H < y + shelf_h:
    H *= 2
atlas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
for n, (ax, ay, w, h) in rects.items():
    atlas.paste(ims[n], (ax, ay))
atlas.save(os.path.join(SPRITES, "atlas.png"))
with open(os.path.join(SPRITES, "atlas.json"), "w") as f:
    json.dump(rects, f, indent=1, sort_keys=True)
print("atlas %dx%d com %d sprites" % (W, H, len(rects)))
