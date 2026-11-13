"""Funcionários sentados (vistos de frente, por trás da mesa) — 20x24, 8 variações.
Mesmo traço do técnico (cabeça 3/4, luz do alto-esquerda), sem headset, braços sobre a mesa.
Saída: assets/sprites/employees.png (folha horizontal, 8 quadros) + cadeira.
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "_lib"))
from pixelstudio import Sprite

OUT = "#181425"
SKINS = [("#e8b796", "#c28569"), ("#e4a672", "#b86f50"), ("#b86f50", "#733e39"), ("#c28569", "#733e39")]
HAIRS = [("#3e2731", "#181425", "#733e39"), ("#feae34", "#d77643", "#fee761"),
         ("#733e39", "#3e2731", "#b86f50"), ("#5a6988", "#3a4466", "#8b9bb4"),
         ("#be4a2f", "#733e39", "#d77643")]
SHIRTS = [("#e43b44", "#a22633"), ("#63c74d", "#3e8948"), ("#feae34", "#d77643"),
          ("#b55088", "#68386c"), ("#c0cbdc", "#8b9bb4"), ("#f77622", "#be4a2f")]
# (pele, cabelo, camisa, cabelo comprido?)
LOOKS = [(0, 0, 0, False), (1, 1, 1, True), (2, 0, 2, False), (0, 2, 3, True),
         (3, 3, 4, False), (1, 4, 5, True), (2, 1, 3, False), (0, 4, 1, True)]


W, H = 22, 32
OX, OY = 1, 8          # deslocamento: espaço acima da cabeça para a mão levantada


def draw(s, skin, hair, shirt, long_hair, pose):
    """pose 0 = digitando; 1 e 2 = acenando (pedindo ajuda), com a boca aberta."""
    SK, SKD = skin
    H, HD, HL = hair
    SH, SHD = shirt
    R = lambda x0, y0, x1, y1, c, **k: s.rect(x0 + OX, y0 + OY, x1 + OX, y1 + OY, c, **k)
    P = lambda x, y, c: s.px(x + OX, y + OY, c)
    E = lambda x0, y0, x1, y1, c, **k: s.ellipse(x0 + OX, y0 + OY, x1 + OX, y1 + OY, c, **k)
    L = lambda x0, y0, x1, y1, c: s.line(x0 + OX, y0 + OY, x1 + OX, y1 + OY, c)
    if long_hair:
        R(4, 6, 15, 16, HD)
    R(4, 14, 15, 21, SH)
    R(12, 15, 15, 21, SHD)
    R(4, 20, 15, 21, SHD)
    R(3, 19, 7, 21, SH)
    R(6, 21, 8, 22, SK)                                   # mão esquerda no teclado
    if pose == 0:
        R(12, 19, 16, 21, SHD); R(11, 21, 13, 22, SKD)     # mão direita no teclado
    else:
        # braço direito levantado, acenando (mão balança entre os quadros)
        hx = 16 if pose == 1 else 18
        L(15, 15, hx, 6, SH)
        L(16, 15, hx + 1, 6, SHD)
        R(hx - 1, 2, hx + 1, 5, SK)
        P(hx + 1, 2, SKD)
    R(8, 14, 11, 14, SK); P(9, 15, SK); P(10, 15, SKD)    # decote
    E(4, 1, 15, 13, SKD)
    E(4, 1, 14, 12, SK, only="opaque")
    E(4, 1, 15, 8, HD, only="opaque")
    E(4, 1, 14, 7, H, only="opaque")
    R(4, 5, 5, 10 if long_hair else 8, H, only="opaque")
    R(14, 5, 15, 10 if long_hair else 7, HD, only="opaque")
    R(7, 7, 13, 11, SK, only="opaque")
    R(14, 8, 14, 11, SKD, only="opaque")
    P(8, 6, H); P(12, 6, H)
    L(6, 3, 9, 2, HL)
    if pose == 0:
        R(8, 8, 8, 9, OUT); R(11, 8, 11, 9, OUT)           # olhando a tela
        P(10, 11, SKD)
    else:
        R(9, 7, 9, 8, OUT); R(12, 7, 12, 8, OUT)           # olhando para cima (procurando o técnico)
        R(10, 10, 11, 11, "#a22633")                       # boca aberta: "Socorro!"
    s.outline(OUT, where="outside")


s = Sprite(W, H, palette="endesga32")
first = True
for pose in range(3):
    for i, (sk, hr, sh, lh) in enumerate(LOOKS):
        if not first:
            s.add_frame(copy=False)
        first = False
        draw(s, SKINS[sk], HAIRS[hr], SHIRTS[sh], lh, pose)
s.preview(os.path.join(HERE, "preview.png"), scale=6, cols=8)
s.stats()
s.save_spritesheet(os.path.join(HERE, "..", "..", "assets", "sprites", "employees.png"),
                   layout="horizontal", json_path=None)

# cadeira de escritório (encosto aparece atrás do funcionário)
c = Sprite(22, 26, palette="endesga32")
c.rect(4, 2, 17, 15, "#262b44")
c.rect(5, 3, 15, 13, "#3a4466", only="opaque")
c.rect(6, 4, 9, 6, "#5a6988", only="opaque")
c.rect(10, 16, 11, 21, "#262b44")
c.line(4, 23, 10, 21, "#262b44"); c.line(11, 21, 17, 23, "#262b44")
c.outline(OUT, where="outside")
c.save_png(os.path.join(HERE, "..", "..", "assets", "sprites", "chair.png"))
c.preview(os.path.join(HERE, "chair_preview.png"), scale=8)
print("ok")
