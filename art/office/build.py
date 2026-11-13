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


# ================================================================ escritório (inspiração: escritório de vendas)
def auto(fw, fd, h, extra=0):
    """Canvas que cabe uma peça de pegada fw x fd e altura h; devolve (sprite, ax, ay)."""
    hw = (fw + fd) / 8
    w = int(hw * 2) + 6
    hgt = int((fw + fd) / 8 + h + extra) + 6
    return canvas(w, hgt), round(hw + 3), round((fw + fd) / 16 + h + extra + 3)


def chair_piece(s, ax, ay, ox, oy, back_side):
    """Cadeira de escritório: assento + encosto (back_side: 'n' ou 's')."""
    iso_box(s, ax, ay, 26, 26, 8, METAL[1], METAL[0], METAL[0], ox=ox, oy=oy)
    boy = oy - 12 if back_side == "n" else oy + 12
    iso_box(s, ax, ay, 26, 5, 10, METAL[1], METAL[0], METAL[0], z0=8, ox=ox, oy=boy)


def conference_table():
    s, ax, ay = auto(256 + 80, 128 + 80, 22)
    for x in (-90, -30, 30, 90):
        chair_piece(s, ax, ay, x, -88, "n")
    iso_box(s, ax, ay, 24, 24, 12, METAL[0], METAL[0], METAL[0], ox=-80)
    iso_box(s, ax, ay, 24, 24, 12, METAL[0], METAL[0], METAL[0], ox=80)
    iso_box(s, ax, ay, 256, 128, 4, WOOD[2], WOOD[1], WOOD[0], z0=12)
    a = iso(ax, ay, -100, -20, 16); b = iso(ax, ay, 60, -20, 16)
    s.line(a[0], a[1], b[0], b[1], WOOD[1])
    # papéis e um telefone de conferência no meio
    iso_box(s, ax, ay, 26, 20, 1, "#ffffff", "#c0cbdc", "#c0cbdc", z0=16, ox=-70, oy=10, outline=False)
    iso_box(s, ax, ay, 26, 20, 1, "#ffffff", "#c0cbdc", "#c0cbdc", z0=16, ox=50, oy=-20, outline=False)
    iso_box(s, ax, ay, 20, 20, 3, "#262b44", "#181425", "#181425", z0=16)
    for x in (-90, -30, 30, 90):
        chair_piece(s, ax, ay, x, 88, "s")
    save(s, "conference_table", (ax, ay))


def vending():
    s, ax, ay = auto(56, 48, 46)
    iso_box(s, ax, ay, 56, 48, 46, "#e43b44", "#a22633", "#68386c")
    # vitrine na face sul com fileiras de lanches coloridos
    for row in range(4):
        z = 12 + row * 8
        a = iso(ax, ay, -22, 24, z); b = iso(ax, ay, 14, 24, z)
        s.line(a[0], a[1], b[0], b[1], "#c0cbdc")
        for k, col in enumerate(("#feae34", "#63c74d", "#0099db", "#f6757a")):
            p = iso(ax, ay, -18 + k * 9, 24, z + 3)
            s.px(p[0], p[1], col)
    p = iso(ax, ay, 22, 24, 30); s.px(p[0], p[1], "#fee761")       # moedeiro
    save(s, "vending", (ax, ay))


def fridge():
    s, ax, ay = auto(48, 44, 48)
    iso_box(s, ax, ay, 48, 44, 48, "#ffffff", "#c0cbdc", "#8b9bb4")
    a = iso(ax, ay, -24, 22, 32); b = iso(ax, ay, 24, 22, 32)
    s.line(a[0], a[1], b[0], b[1], "#8b9bb4")                       # divisão do freezer
    for z0, z1 in ((36, 44), (14, 28)):
        p = iso(ax, ay, 18, 22, z0); q = iso(ax, ay, 18, 22, z1)
        s.line(p[0], p[1], q[0], q[1], "#5a6988")                    # puxadores
    save(s, "fridge", (ax, ay))


def counter():
    s, ax, ay = auto(192, 48, 30)
    iso_box(s, ax, ay, 192, 48, 14, "#c0cbdc", "#8b9bb4", "#5a6988")
    iso_box(s, ax, ay, 40, 26, 1, "#3a4466", "#262b44", "#262b44", z0=14, ox=-40, outline=False)   # pia
    iso_box(s, ax, ay, 40, 30, 12, "#ffffff", "#c0cbdc", "#8b9bb4", z0=14, ox=55)                  # micro-ondas
    p = iso(ax, ay, 40, 15, 22); q = iso(ax, ay, 66, 15, 22)
    s.line(p[0], p[1], q[0], q[1], "#262b44")
    iso_box(s, ax, ay, 12, 12, 8, "#f6757a", "#b55088", "#68386c", z0=14, ox=10, oy=6)            # cafeteira
    save(s, "counter", (ax, ay))


def kitchen_table():
    s, ax, ay = auto(64 + 40, 64 + 40, 16)
    chair_piece(s, ax, ay, 0, -46, "n")
    iso_box(s, ax, ay, 10, 10, 12, METAL[0], METAL[0], METAL[0])
    iso_box(s, ax, ay, 64, 64, 3, "#ffffff", "#c0cbdc", "#8b9bb4", z0=12)
    iso_box(s, ax, ay, 10, 10, 4, "#e43b44", "#a22633", "#a22633", z0=15, ox=10, oy=-6, outline=False)  # caneca
    chair_piece(s, ax, ay, 0, 46, "s")
    save(s, "kitchen_table", (ax, ay))


def filing():
    s, ax, ay = auto(40, 32, 26)
    iso_box(s, ax, ay, 40, 32, 26, "#c0cbdc", "#8b9bb4", "#5a6988")
    for z in (8, 16, 24):
        a = iso(ax, ay, -20, 16, z); b = iso(ax, ay, 20, 16, z)
        s.line(a[0], a[1], b[0], b[1], "#5a6988")
        p = iso(ax, ay, 0, 16, z - 4); s.px(p[0], p[1], "#262b44")
    save(s, "filing", (ax, ay))


def copier():
    s, ax, ay = auto(72, 52, 28)
    iso_box(s, ax, ay, 72, 52, 18, "#c0cbdc", "#8b9bb4", "#5a6988")
    iso_box(s, ax, ay, 60, 44, 3, "#3a4466", "#262b44", "#262b44", z0=18)                # tampa
    iso_box(s, ax, ay, 22, 14, 3, "#ffffff", "#c0cbdc", "#c0cbdc", z0=10, ox=42, outline=False)  # bandeja
    p = iso(ax, ay, 26, -16, 21); s.px(p[0], p[1], "#63c74d"); s.px(p[0] + 1, p[1], "#0099db")
    save(s, "copier", (ax, ay))


def reception():
    s, ax, ay = auto(192, 56, 22)
    iso_box(s, ax, ay, 192, 56, 18, WOOD[1], WOOD[0], "#3e2731")
    iso_box(s, ax, ay, 192, 20, 3, WOOD[2], WOOD[1], WOOD[0], z0=18, oy=18)   # balcão alto
    a = iso(ax, ay, -96, 28, 9); b = iso(ax, ay, 96, 28, 9)
    s.line(a[0], a[1], b[0], b[1], WOOD[2])                                      # friso
    iso_box(s, ax, ay, 40, 6, 14, METAL[1], METAL[0], METAL[0], z0=18, ox=-40, oy=-14)  # monitor
    save(s, "reception", (ax, ay))


def sofa():
    s, ax, ay = auto(128, 48, 22)
    iso_box(s, ax, ay, 128, 14, 20, "#5a6988", "#3a4466", "#262b44", oy=-17)        # encosto
    iso_box(s, ax, ay, 128, 34, 9, "#8b9bb4", "#5a6988", "#3a4466", oy=7)           # assento
    iso_box(s, ax, ay, 14, 48, 14, "#5a6988", "#3a4466", "#262b44", ox=-57)          # braços
    iso_box(s, ax, ay, 14, 48, 14, "#5a6988", "#3a4466", "#262b44", ox=57)
    save(s, "sofa", (ax, ay))


def workbench():
    """Bancada de manutenção do suporte: gabinete aberto, monitor, peças e ferramentas."""
    s, ax, ay = auto(160, 56, 34)
    iso_box(s, ax, ay, 160, 56, 14, "#8b9bb4", "#5a6988", "#3a4466")
    iso_box(s, ax, ay, 150, 48, 2, "#c0cbdc", "#8b9bb4", "#8b9bb4", z0=14, outline=False)      # tampo
    iso_box(s, ax, ay, 30, 46, 22, "#3a4466", "#262b44", "#181425", z0=16, ox=-48)            # gabinete
    iso_box(s, ax, ay, 4, 34, 18, "#63c74d", "#3e8948", "#3e8948", z0=18, ox=-34, outline=False)  # placa-mãe à mostra
    iso_box(s, ax, ay, 40, 6, 16, METAL[1], METAL[0], METAL[0], z0=16, ox=10, oy=-16)          # monitor
    g1 = iso(ax, ay, -8, -20, 30); g2 = iso(ax, ay, 28, -20, 30)
    s.line(g1[0], g1[1], g2[0], g2[1], "#0099db")
    iso_box(s, ax, ay, 18, 10, 2, "#63c74d", "#3e8948", "#3e8948", z0=16, ox=48, oy=8, outline=False)   # pente de memória
    iso_box(s, ax, ay, 22, 6, 2, "#e43b44", "#a22633", "#a22633", z0=16, ox=60, oy=-6, outline=False)   # chave de fenda
    iso_box(s, ax, ay, 14, 14, 3, "#feae34", "#d77643", "#d77643", z0=16, ox=30, oy=12, outline=False)  # caixa de parafusos
    save(s, "workbench", (ax, ay))


def shelf():
    """Estante com caixas de equipamentos."""
    s, ax, ay = auto(96, 32, 44)
    iso_box(s, ax, ay, 96, 32, 44, METAL[2], METAL[1], METAL[0])
    for k, z in enumerate((4, 18, 32)):
        a = iso(ax, ay, -48, 16, z + 12); b = iso(ax, ay, 48, 16, z + 12)
        s.line(a[0], a[1], b[0], b[1], METAL[0])
        for j, col in enumerate((("#b86f50", "#733e39"), ("#c0cbdc", "#8b9bb4"), ("#feae34", "#d77643"))):
            if (j + k) % 3 == 2:
                continue
            iso_box(s, ax, ay, 24, 20, 9, col[0], col[1], col[1], z0=z + 1, ox=-30 + j * 30, oy=4, outline=False)
    save(s, "shelf", (ax, ay))


def ups():
    """Nobreak da sala de servidores."""
    s, ax, ay = auto(40, 48, 22)
    iso_box(s, ax, ay, 40, 48, 22, "#3a4466", "#262b44", "#181425")
    p = iso(ax, ay, -10, 24, 14); s.px(p[0], p[1], "#63c74d")
    p = iso(ax, ay, -2, 24, 14); s.px(p[0], p[1], "#feae34")
    save(s, "ups", (ax, ay))


# ---------------------------------------------------------------- blocos de parede (1 ladrilho = 64 x 64 mundo)
WALL_TOP, WALL_S, WALL_E = "#ead4aa", "#e4a672", "#c28569"


def wall_block(name, h, window=None):
    """Bloco de parede de 1 ladrilho, altura h (px). window: 's' (face sul) ou 'e' (face leste)."""
    s, ax, ay = auto(64, 64, h)
    iso_box(s, ax, ay, 64, 64, h, WALL_TOP, WALL_S, WALL_E)
    if window:
        if window == "s":
            q = [iso(ax, ay, -22, 32, 14), iso(ax, ay, 22, 32, 14), iso(ax, ay, 22, 32, 46), iso(ax, ay, -22, 32, 46)]
        else:
            q = [iso(ax, ay, 32, -22, 14), iso(ax, ay, 32, 22, 14), iso(ax, ay, 32, 22, 46), iso(ax, ay, 32, -22, 46)]
        s.polygon(q, "#0099db")
        for k in range(5):          # persiana
            t = 0.06 + k * 0.1
            a = (round(q[3][0] + (q[0][0] - q[3][0]) * t), round(q[3][1] + (q[0][1] - q[3][1]) * t))
            b = (round(q[2][0] + (q[1][0] - q[2][0]) * t), round(q[2][1] + (q[1][1] - q[2][1]) * t))
            s.line(a[0], a[1], b[0], b[1], "#f4f4f4")
        for i in range(4):
            s.line(q[i][0], q[i][1], q[(i + 1) % 4][0], q[(i + 1) % 4][1], OUT)
    save(s, name, (ax, ay))


def glass_block():
    """Parede de vidro: rodapé baixo + painel translúcido (alfa) com reflexo."""
    s, ax, ay = auto(64, 64, 40)
    iso_box(s, ax, ay, 64, 64, 6, WALL_TOP, WALL_S, WALL_E)
    W_ = (-32, 32); S_ = (32, 32); N_ = (-32, -32); E_ = (32, -32)
    pane = [iso(ax, ay, *W_, 6), iso(ax, ay, *S_, 6), iso(ax, ay, *S_, 40), iso(ax, ay, *W_, 40)]
    s.polygon(pane, (191, 235, 255, 72))
    for a, b in ((iso(ax, ay, *W_, 40), iso(ax, ay, *S_, 40)), (iso(ax, ay, *N_, 40), iso(ax, ay, *E_, 40)),
                 (iso(ax, ay, *S_, 6), iso(ax, ay, *S_, 40))):
        s.line(a[0], a[1], b[0], b[1], "#5a6988")
    r1 = iso(ax, ay, -19, 32, 12); r2 = iso(ax, ay, -3, 32, 34)
    s.line(r1[0], r1[1], r2[0], r2[1], (255, 255, 255, 150))
    save(s, "wall_glass", (ax, ay))


def carpet_tile(name, dark, light, speck):
    s = canvas(32, 16)
    s.polygon([(16, 0), (31, 7), (16, 15), (0, 7)], dark)
    s.noise(0, 0, 31, 15, speck, density=0.18, seed=len(name), only=dark)
    s.line(16, 0, 31, 7, light); s.line(16, 0, 0, 7, light)
    save(s, "floor_" + name, (16, 8))


def flat_tile(name, color, edge):
    s = canvas(32, 16)
    s.polygon([(16, 0), (31, 7), (16, 15), (0, 7)], edge)
    s.polygon([(16, 1), (29, 7), (16, 13), (2, 7)], color)
    save(s, "floor_" + name, (16, 8))


desk(False); desk(True)
rack(False); rack(True)
plant(); cooler()
alert("alert", "#feae34", "#fee761")
alert("alert_high", "#b55088", "#f6757a")
alert("alert_urgent", "#e43b44", "#f77622")
conference_table(); vending(); fridge(); counter(); kitchen_table(); workbench(); shelf(); ups()
wall_block("wall_back", 56); wall_block("wall_back_win_s", 56, "s"); wall_block("wall_back_win_e", 56, "e")
wall_block("wall_low", 14); wall_block("wall_front", 8); glass_block()
filing(); copier(); reception(); sofa()
carpet_tile("carpete", "#5a6988", "#8b9bb4", "#3a4466")        # área de vendas
carpet_tile("gerente", "#68386c", "#b55088", "#3e2731")        # sala do gerente
carpet_tile("reuniao", "#3a4466", "#5a6988", "#262b44")        # sala de reunião
carpet_tile("anexo", "#265c42", "#3e8948", "#193c3e")          # contabilidade
carpet_tile("rh", "#b86f50", "#e4a672", "#733e39")
carpet_tile("ti", "#124e89", "#0099db", "#193c3e")
flat_tile("copa_a", "#ffffff", "#c0cbdc")                       # piso xadrez da copa
flat_tile("copa_b", "#8b9bb4", "#5a6988")
flat_tile("servidores", "#3a4466", "#262b44")
flat_tile("corredor", "#c0cbdc", "#8b9bb4")

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
