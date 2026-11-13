"""Mobília e pisos isométricos do escritório (projeção do jogo: 64 un. de mundo = losango 32x16 px).

Cada objeto é desenhado a partir da pegada (footprint) em unidades de mundo, para casar
com a colisão. O ponto de ancoragem (centro da pegada no chão) vai para anchors.json.
Rode: python3 build.py
"""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "_lib"))
from pixelstudio import Sprite

OUTDIR = os.path.join(HERE, "..", "..", "assets", "sprites")
OUT = "#181425"
WOOD = ("#733e39", "#b86f50", "#e4a672")          # escuro, médio, claro
METAL = ("#262b44", "#3a4466", "#5a6988")
ANCHORS = {}


def iso(ax, ay, dx, dy, z=0):
    """mundo (dx, dy) relativo à âncora → pixel; z = altura em pixels."""
    return (round(ax + (dx - dy) / 4), round(ay + (dx + dy) / 8 - z))


def iso_box(s, ax, ay, fw, fd, h, top, left, right, z0=0, outline=True, ox=0, oy=0):
    """Caixa com pegada fw x fd (mundo), altura h (px), apoiada em z0. ox/oy desloca no mundo."""
    hw, hd = fw / 2, fd / 2
    N = (ox - hw, oy - hd); E = (ox + hw, oy - hd); S = (ox + hw, oy + hd); W = (ox - hw, oy + hd)
    p = lambda c, z: iso(ax, ay, c[0], c[1], z)
    zt = z0 + h
    s.polygon([p(W, z0), p(S, z0), p(S, zt), p(W, zt)], left)       # face sul (esquerda na tela)
    s.polygon([p(S, z0), p(E, z0), p(E, zt), p(S, zt)], right)      # face leste (direita na tela)
    s.polygon([p(N, zt), p(E, zt), p(S, zt), p(W, zt)], top)        # tampo
    if outline:
        for a, b in ((p(W, z0), p(S, z0)), (p(S, z0), p(E, z0)), (p(W, z0), p(W, zt)),
                     (p(E, z0), p(E, zt)), (p(N, zt), p(E, zt)), (p(E, zt), p(S, zt)),
                     (p(S, zt), p(W, zt)), (p(W, zt), p(N, zt))):
            s.line(a[0], a[1], b[0], b[1], OUT)
        s.line(*p(S, z0), *p(S, zt), OUT)
    return p


def save(s, name, anchor):
    s.save_png(os.path.join(OUTDIR, name + ".png"))
    ANCHORS[name] = list(anchor)


def canvas(w, h):
    return Sprite(w, h, palette="endesga32")


# ---------------------------------------------------------------- mesa (160 x 60 mundo)
def desk(alert):
    s = canvas(60, 46)
    ax, ay = 30, 32
    # tampo de madeira apoiado em 2 gaveteiros
    iso_box(s, ax, ay, 30, 50, 12, METAL[2], METAL[1], METAL[0], ox=-60)
    iso_box(s, ax, ay, 30, 50, 12, METAL[2], METAL[1], METAL[0], ox=60)
    iso_box(s, ax, ay, 160, 60, 3, WOOD[2], WOOD[1], WOOD[0], z0=12)
    # veio da madeira no tampo
    a = iso(ax, ay, -50, -10, 15); b = iso(ax, ay, 30, -10, 15)
    s.line(a[0], a[1], b[0], b[1], WOOD[1])
    # monitor visto por trás (tela voltada para o funcionário, ao norte)
    # monitor no canto esquerdo da mesa (o funcionário senta à direita dele)
    MX = -44
    iso_box(s, ax, ay, 44, 6, 15, METAL[1], METAL[0], METAL[0], z0=18, ox=MX, oy=-14)
    iso_box(s, ax, ay, 8, 8, 4, METAL[0], METAL[0], METAL[0], z0=15, ox=MX, oy=-14)
    led = iso(ax, ay, MX + 14, -10, 23)
    s.px(led[0], led[1], "#e43b44" if alert else "#63c74d")
    glow = "#e43b44" if alert else "#0099db"
    g1 = iso(ax, ay, MX - 20, -18, 33); g2 = iso(ax, ay, MX + 20, -18, 33)
    s.line(g1[0], g1[1], g2[0], g2[1], glow)
    # teclado, papéis e caneca
    iso_box(s, ax, ay, 40, 14, 1, "#c0cbdc", "#8b9bb4", "#8b9bb4", z0=15, ox=-8, oy=8, outline=False)
    iso_box(s, ax, ay, 26, 20, 1, "#ffffff", "#c0cbdc", "#c0cbdc", z0=15, ox=40, oy=4, outline=False)
    iso_box(s, ax, ay, 8, 8, 4, "#ffffff", "#c0cbdc", "#8b9bb4", z0=15, ox=62, oy=12, outline=False)
    save(s, "desk_alert" if alert else "desk", (ax, ay))
    return s


# ---------------------------------------------------------------- rack (100 x 110 mundo)
def rack(alert):
    s = canvas(56, 72)
    ax, ay = 27, 58
    p = iso_box(s, ax, ay, 100, 110, 48, METAL[2], METAL[1], METAL[0])
    # gavetas de servidor na face sul e LEDs
    for k in range(6):
        z = 6 + k * 7
        a = iso(ax, ay, -46, 55, z); b = iso(ax, ay, 46, 55, z)
        s.line(a[0], a[1], b[0], b[1], METAL[2])
        led_on = "#e43b44" if alert and k % 2 == 0 else "#63c74d"
        l = iso(ax, ay, 36, 55, z + 3)
        s.px(l[0], l[1], led_on)
        l2 = iso(ax, ay, 26, 55, z + 3)
        s.px(l2[0], l2[1], "#feae34" if k % 3 == 0 else METAL[2])
    save(s, "rack_alert" if alert else "rack", (ax, ay))


# ---------------------------------------------------------------- planta
def plant():
    s = canvas(26, 34)
    ax, ay = 13, 29
    iso_box(s, ax, ay, 30, 30, 9, "#b86f50", "#be4a2f", "#733e39")
    # folhagem: massa escura + luz deslocada para o alto-esquerda
    for cx, cy, r in ((13, 13, 8), (7, 9, 5), (19, 8, 5), (12, 5, 5)):
        s.circle(cx, cy, r, "#265c42", fill=True)
    for cx, cy, r in ((12, 12, 6), (6, 8, 4), (18, 7, 4), (11, 4, 4)):
        s.circle(cx, cy, r, "#3e8948", fill=True, only="opaque")
    for cx, cy, r in ((10, 10, 3), (5, 6, 2), (16, 5, 2), (10, 3, 2)):
        s.circle(cx, cy, r, "#63c74d", fill=True, only="opaque")
    s.outline(OUT, where="outside")
    save(s, "plant", (ax, ay))


# ---------------------------------------------------------------- bebedouro (detalhe do corredor)
def cooler():
    s = canvas(18, 40)
    ax, ay = 9, 34
    iso_box(s, ax, ay, 24, 24, 18, "#c0cbdc", "#8b9bb4", "#5a6988")
    s.ellipse(4, 3, 13, 18, "#124e89")
    s.ellipse(4, 3, 12, 17, "#0099db", only="opaque")
    s.rect(6, 5, 7, 12, "#2ce8f5", only="opaque")
    s.outline(OUT, where="outside")
    save(s, "cooler", (ax, ay))


# ---------------------------------------------------------------- balões de alerta
ALERT = [
    "..kkkkkkk..",
    ".kyyyyyyyk.",
    "kyyyykyyyyk",
    "kyyyykyyyyk",
    "kyyyykyyyyk",
    "kyyyykyyyyk",
    "kyyyyyyyyyk",
    "kyyyykyyyyk",
    ".kyyyyyyyk.",
    "..kkkykkk..",
    "....kyk....",
    ".....k.....",
]


def alert(name, color, light):
    s = canvas(11, 12)
    for y, row in enumerate(ALERT):
        for x, ch in enumerate(row):
            if ch == "k":
                s.px(x, y, OUT)
            elif ch == "y":
                s.px(x, y, color)
    s.px(2, 2, light); s.px(2, 3, light)          # brilho no alto-esquerda
    save(s, name, (5, 11))


# ---------------------------------------------------------------- pisos (losango 32x16)
FLOORS = {
    "diretoria": ("#68386c", "#b55088"),
    "financeiro": ("#265c42", "#3e8948"),
    "rh": ("#b86f50", "#e4a672"),
    "suporte": ("#124e89", "#0099db"),
    "marketing": ("#a22633", "#e43b44"),
    "servidores": ("#3a4466", "#5a6988"),
    "corredor": ("#8b9bb4", "#c0cbdc"),
}


def tile(name, dark, light):
    s = canvas(32, 16)
    s.polygon([(16, 0), (31, 7), (16, 15), (0, 7)], light)
    s.polygon([(16, 1), (29, 7), (16, 13), (2, 7)], dark)
    s.polygon([(16, 2), (27, 7), (16, 12), (4, 7)], light)
    save(s, "floor_" + name, (16, 8))
    return s


desk(False); desk(True)
rack(False); rack(True)
plant(); cooler()
alert("alert", "#feae34", "#fee761")
alert("alert_high", "#b55088", "#f6757a")
alert("alert_urgent", "#e43b44", "#f77622")
for k, (d, l) in FLOORS.items():
    tile(k, d, l)

with open(os.path.join(OUTDIR, "anchors.json"), "w") as f:
    json.dump(ANCHORS, f, indent=1)

# folha de revisão (não é entregável): tudo lado a lado em 6x
from PIL import Image
names = list(ANCHORS)
ims = [Image.open(os.path.join(OUTDIR, n + ".png")) for n in names]
sc = 5
W = sum(i.width * sc + 10 for i in ims); H = max(i.height for i in ims) * sc
sheet = Image.new("RGBA", (W, H), (232, 228, 218, 255))
x = 0
for im in ims:
    sheet.paste(im.resize((im.width * sc, im.height * sc), Image.NEAREST), (x, H - im.height * sc), im.resize((im.width * sc, im.height * sc), Image.NEAREST))
    x += im.width * sc + 10
sheet.save(os.path.join(HERE, "preview.png"))
print("ok:", ", ".join(names))
