"""Técnico de TI — 20x34, visão 3/4 isométrica (frente = sudeste, costas = nordeste).
Saída: spritesheet 8 quadros (frente idle,w1..w3 | costas idle,w1..w3) para o Godot.
Rode:  python3 build.py   (gera preview.png para revisão e ../../assets/sprites/technician.png)
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "_lib"))
from pixelstudio import Sprite

W, H = 20, 34
# cores (todas da endesga32)
OUT = "#181425"
SKIN, SKIN_D, SKIN_L = "#e8b796", "#c28569", "#ead4aa"
HAIR, HAIR_D, HAIR_L = "#733e39", "#3e2731", "#b86f50"
SHIRT, SHIRT_D, SHIRT_L = "#0099db", "#124e89", "#2ce8f5"
PANTS, PANTS_D = "#3a4466", "#262b44"
SHOE = "#181425"
SET, SET_L = "#262b44", "#5a6988"
WHITE, LANYARD = "#ffffff", "#feae34"
LED = "#63c74d"
CHEEK = "#f6757a"

# deslocamentos por quadro de caminhada: (bob do corpo, perna esq dy, perna dir dy, braço esq dy, braço dir dy)
WALK = [
    (0, 0, 0, 0, 0),     # parado
    (0, 1, -1, -1, 1),   # contato: perna esq à frente
    (-1, 0, 0, 0, 0),    # passagem (corpo sobe)
    (0, -1, 1, 1, -1),   # contato: perna dir à frente
]


def legs(s, back, l_dy, r_dy):
    # perna esquerda (x 6..9, iluminada) e direita (x 10..13, na sombra); dy>0 = à frente
    for x0, dy, base, edge in ((6, l_dy, PANTS, PANTS_D), (10, r_dy, PANTS_D, PANTS_D)):
        top, bot = 24, 29 + dy
        s.rect(x0, top, x0 + 3, bot, base)
        s.rect(x0 + 3, top + 1, x0 + 3, bot, edge)
        s.rect(x0, bot + 1, x0 + 3 + (0 if back else 1), bot + 2, SHOE)


def torso(s, back, bob, la, ra):
    y = 14 + bob
    # braços (o esquerdo fica no lado iluminado)
    s.rect(3, y + 1 + la, 5, y + 7 + la, SHIRT)
    s.rect(3, y + 8 + la, 5, y + 9 + la, SKIN)
    s.rect(14, y + 1 + ra, 16, y + 7 + ra, SHIRT_D)
    s.rect(14, y + 8 + ra, 16, y + 9 + ra, SKIN_D)
    # tronco: base clara, sombra só no lado direito e embaixo (luz do alto-esquerda)
    s.rect(5, y, 14, y + 9, SHIRT)
    s.rect(12, y + 1, 14, y + 9, SHIRT_D)
    s.rect(5, y + 8, 14, y + 8, SHIRT_D)
    s.line(4, y + 1, 6, y, SHIRT_L)                     # ombro iluminado
    if not back:
        # gola polo branca
        s.rect(8, y, 11, y, WHITE)
        s.px(8, y + 1, WHITE); s.px(11, y + 1, WHITE)
        s.px(9, y + 1, SKIN); s.px(10, y + 1, SKIN_D)
        # cordão + crachá 3x4 com faixa azul
        s.line(8, y + 2, 9, y + 4, LANYARD)
        s.rect(9, y + 5, 11, y + 7, WHITE)
        s.rect(9, y + 5, 11, y + 5, SHIRT_D)
    # cinto
    s.rect(5, y + 9, 14, y + 9, PANTS_D)


def head(s, back, bob):
    y = bob
    # cabeça pela receita de forma deslocada: sombra cheia, luz deslocada p/ cima-esquerda
    s.ellipse(4, y + 1, 15, y + 13, SKIN_D)
    s.ellipse(4, y + 1, 14, y + 12, SKIN, only="opaque")
    if back:
        s.ellipse(4, y + 1, 15, y + 12, HAIR_D, only="opaque")
        s.ellipse(4, y + 1, 14, y + 11, HAIR, only="opaque")
        s.ellipse(5, y + 2, 10, y + 6, HAIR_L, only=HAIR)
        s.rect(7, y + 12, 12, y + 13, SKIN_D)           # nuca
    else:
        # cabelo: calota + lateral esquerda (atrás da orelha)
        s.ellipse(4, y + 1, 15, y + 9, HAIR_D, only="opaque")
        s.ellipse(4, y + 1, 14, y + 8, HAIR, only="opaque")
        s.rect(4, y + 6, 6, y + 11, HAIR_D, only="opaque")
        s.rect(4, y + 6, 5, y + 10, HAIR, only="opaque")
        # testa/rosto devolvidos (rosto virado para a direita)
        s.rect(7, y + 7, 14, y + 11, SKIN, only="opaque")
        s.rect(15, y + 7, 15, y + 11, SKIN_D, only="opaque")
        s.rect(7, y + 12, 14, y + 12, SKIN_D, only="opaque")
        # franja em mechas
        s.px(8, y + 7, HAIR); s.px(11, y + 7, HAIR); s.px(12, y + 7, HAIR)
        s.line(6, y + 3, 9, y + 2, HAIR_L)              # brilho do cabelo
        s.px(7, y + 4, HAIR_L)
        # olhos + bochecha + boca
        s.rect(9, y + 8, 9, y + 9, OUT)
        s.rect(12, y + 8, 12, y + 9, OUT)
        s.px(13, y + 10, CHEEK)
        s.px(11, y + 11, SKIN_D)
    # headset: arco sobre o cabelo + concha na orelha esquerda
    s.line(5, y + 4, 8, y + 2, SET)
    s.line(9, y + 2, 12, y + 2, SET)
    s.line(13, y + 3, 14, y + 4, SET)
    s.rect(3, y + 7, 5, y + 10, SET)
    s.px(3, y + 7, SET_L); s.px(4, y + 7, SET_L)
    if not back:
        s.line(6, y + 11, 8, y + 12, SET)               # haste do microfone
        s.px(9, y + 12, LED)


def draw(s, back, step):
    bob, l_dy, r_dy, la, ra = WALK[step]
    legs(s, back, l_dy, r_dy)
    torso(s, back, bob, la, ra)
    head(s, back, bob)
    s.outline(OUT, where="outside")


s = Sprite(W, H, palette="endesga32")
first = True
for back in (False, True):
    for step in range(4):
        if not first:
            s.add_frame(copy=False)
        first = False
        draw(s, back, step)
s.set_duration(130, frames=list(range(1, 9)))
s.tag("frente", 1, 4)
s.tag("costas", 5, 8)

s.preview(os.path.join(HERE, "preview.png"), scale=8, cols=8)
s.save_silhouette(os.path.join(HERE, "silhouette.png"), frame=1)
s.stats()
out = os.path.join(HERE, "..", "..", "assets", "sprites", "technician.png")
s.save_spritesheet(out, layout="horizontal", padding=0, json_path=None)
s.save_png(os.path.join(HERE, "technician@6x.png"), frame=1, scale=6)
print("ok ->", os.path.normpath(out))
