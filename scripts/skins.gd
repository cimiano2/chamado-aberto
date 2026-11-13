class_name Skins
extends RefCounted
## Personalização do técnico: troca as cores do sprite (pele, cabelo, camisa) em tempo de execução.
## As cores de origem são as do art/technician/build.py.

const SRC_SKIN := [Color("e8b796"), Color("c28569")]
const SRC_HAIR := [Color("b86f50"), Color("733e39"), Color("3e2731")]
const SRC_SHIRT := [Color("2ce8f5"), Color("0099db"), Color("124e89")]

const SKIN := [
	{"name": "Clara", "c": [Color("e8b796"), Color("c28569")]},
	{"name": "Média", "c": [Color("e4a672"), Color("b86f50")]},
	{"name": "Morena", "c": [Color("b86f50"), Color("733e39")]},
	{"name": "Escura", "c": [Color("733e39"), Color("3e2731")]},
]
const HAIR := [
	{"name": "Castanho", "c": [Color("b86f50"), Color("733e39"), Color("3e2731")]},
	{"name": "Preto", "c": [Color("5a6988"), Color("262b44"), Color("181425")]},
	{"name": "Loiro", "c": [Color("fee761"), Color("feae34"), Color("d77643")]},
	{"name": "Ruivo", "c": [Color("f77622"), Color("be4a2f"), Color("733e39")]},
	{"name": "Grisalho", "c": [Color("ffffff"), Color("c0cbdc"), Color("8b9bb4")]},
	{"name": "Rosa", "c": [Color("f6757a"), Color("b55088"), Color("68386c")]},
]
const SHIRT := [
	{"name": "Azul", "c": [Color("2ce8f5"), Color("0099db"), Color("124e89")]},
	{"name": "Verde", "c": [Color("63c74d"), Color("3e8948"), Color("265c42")]},
	{"name": "Vermelha", "c": [Color("f77622"), Color("e43b44"), Color("a22633")]},
	{"name": "Roxa", "c": [Color("f6757a"), Color("b55088"), Color("68386c")]},
	{"name": "Laranja", "c": [Color("feae34"), Color("f77622"), Color("be4a2f")]},
	{"name": "Cinza", "c": [Color("ffffff"), Color("c0cbdc"), Color("8b9bb4")]},
	{"name": "Preta", "c": [Color("5a6988"), Color("3a4466"), Color("262b44")]},
	{"name": "Amarela", "c": [Color("fee761"), Color("feae34"), Color("d77643")]},
]

static var _cache := {}


## Textura do técnico com a skin escolhida.
static func texture(skin: int, hair: int, shirt: int) -> Texture2D:
	var key := "%d-%d-%d" % [skin, hair, shirt]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(image(skin, hair, shirt))
	return _cache[key]


## Imagem do técnico recolorida (pixel a pixel).
static func image(skin: int, hair: int, shirt: int) -> Image:
	# importado como Image (não textura): os pixels ficam sempre disponíveis na memória
	var img: Image = (load("res://assets/sprites/technician.png") as Image).duplicate()
	img.convert(Image.FORMAT_RGBA8)
	var pairs: Array = []   # [cor de origem, cor nova]
	for i in SRC_SKIN.size():
		pairs.append([SRC_SKIN[i], SKIN[skin].c[i]])
	for i in SRC_HAIR.size():
		pairs.append([SRC_HAIR[i], HAIR[hair].c[i]])
	for i in SRC_SHIRT.size():
		pairs.append([SRC_SHIRT[i], SHIRT[shirt].c[i]])
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			for p in pairs:
				var s: Color = p[0]
				# tolerância pequena: a textura importada pode variar 1-2 níveis por canal
				if absf(c.r - s.r) + absf(c.g - s.g) + absf(c.b - s.b) < 0.03:
					img.set_pixel(x, y, Color(p[1], c.a))
					break
	return img
