class_name Sprites
extends RefCounted
## Pixel art do jogo, definida como mapas de caracteres e convertida em texturas.
## Arte original: técnico com headset, funcionários, planta e balão de alerta.

const TECH_PALETTE := {
	"k": Color("1a1a28"), "h": Color("4a2c18"), "H": Color("6b4226"), "s": Color("f0c08a"),
	"S": Color("d49a62"), "e": Color("1a1a28"), "m": Color("2a2a33"), "c": Color("34e7e4"),
	"b": Color("2f74ff"), "B": Color("2156c4"), "w": Color("eef2ff"), "y": Color("ffd23f"),
	"i": Color("ffffff"), "p": Color("2b2f45"), "P": Color("1d2031"), "o": Color("121218"),
}

const HEAD_FRONT := [
	"....kkkkkk....",
	"...kHHhhhhk...",
	"..kHhhhhhhhhk.",
	"..khhhhhhhhhk.",
	".mkhsssssshkm.",
	".mksesssseskm.",
	".mkssssssssk..",
	"..ksssSSsssk..",
	"...kksssskc...",
]
const HEAD_BACK := [
	"....kkkkkk....",
	"...kHHhhhhk...",
	"..kHhhhhhhhhk.",
	"..khhhhhhhhhk.",
	".mkhhhhhhhhkm.",
	".mkhhhhhhhhkm.",
	".mkhhHHhhhhk..",
	"..khhhhhhhhk..",
	"...kksssskk...",
]
const BODY_FRONT := [
	"..kkbbwwbbkk..",
	".kbbbbwwbbbbk.",
	"kbbbybbbbbbbbk",
	"kbbbbybbbbbbbk",
	"ksbbbiibbbbbsk",
	"ksBbbiibbbbBsk",
	"kSBbbbbbbbbBSk",
	".kkBBBBBBBBkk.",
]
const BODY_BACK := [
	"..kkbbbbbbkk..",
	".kbbbbbbbbbbk.",
	"kbbbbbbbbbbbbk",
	"kbbbbbbbbbbbbk",
	"ksbbbbbbbbbbsk",
	"ksBbbbbbbbbBsk",
	"kSBbbbbbbbbBSk",
	".kkBBBBBBBBkk.",
]
const LEGS := [
	[  # parado
		"..kppppppppk..",
		"..kppppPpppk..",
		"..kpppk.pppk..",
		"..kpppk.pppk..",
		"..kPPPk.PPPk..",
		"..koook.oook..",
		"..kkkkk.kkkkk.",
	],
	[  # passo 1
		"..kppppppppk..",
		"..kppppPpppk..",
		"..kpppk.pppk..",
		"..kpppk.kook..",
		"..kPPPk.kkkk..",
		"..koook.......",
		"..kkkkk.......",
	],
	[  # passo 2
		"..kppppppppk..",
		"..kppppPpppk..",
		"..kpppk.pppk..",
		"..kook..pppk..",
		"..kkkk..PPPk..",
		"........oook..",
		"........kkkkk.",
	],
]

## Funcionário sentado (só tronco aparece atrás da mesa). h = cabelo, s = pele, b = camisa.
const SEATED := [
	"....kkkkkk....",
	"...khhhhhhk...",
	"..khhhhhhhhk..",
	"..khhhhhhhhk..",
	"..khsssssshk..",
	"..kksesseskk..",
	"...kssssssk...",
	"...kssDDssk...",
	"....kkssk.....",
	"..kkbbbbbbkk..",
	".kbbbbbbbbbbk.",
	"kbbbbbbbbbbbbk",
	"kbbbbbbbbbbbbk",
	"kbbbbbbbbbbbbk",
]

const PLANT := [
	"....kk..kk..",
	"...kgGk.kgk.",
	"..kgGGgkgGgk",
	".kgGgggGggk.",
	"kgGggGgggGgk",
	"kggGggggGggk",
	".kgggGggggk.",
	"..kgggggggk.",
	"...kkkgkkk..",
	"..kooooooook",
	"..kOoooooook",
	"..kOooooooo.",
	"...kOoooook.",
	"....kkkkkk..",
]
const PLANT_PALETTE := {"k": Color("173018"), "g": Color("3f9a4b"), "G": Color("6fcf5f"),
	"o": Color("c0703a"), "O": Color("8a4a24")}

const ALERT := [
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

static var _cache := {}


static func texture(rows: Array, palette: Dictionary) -> ImageTexture:
	var key := str(rows.hash()) + str(palette.hash())
	if _cache.has(key):
		return _cache[key]
	var w: int = rows[0].length()
	var img := Image.create(w, rows.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		var line: String = rows[y]
		assert(line.length() == w, "linha %d com largura errada" % y)
		for x in w:
			var ch := line[x]
			if palette.has(ch):
				img.set_pixel(x, y, palette[ch])
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Técnico: back = de costas; frame 0 = parado, 1/2 = passos.
static func technician(back: bool, frame: int) -> ImageTexture:
	var rows: Array = []
	rows.append_array(HEAD_BACK if back else HEAD_FRONT)
	rows.append_array(BODY_BACK if back else BODY_FRONT)
	rows.append_array(LEGS[frame])
	return texture(rows, TECH_PALETTE)


static func employee(look: Dictionary) -> ImageTexture:
	var pal := {"k": Color("1a1a28"), "h": look.hair, "s": look.skin, "D": look.skin.darkened(0.2),
		"e": Color("1a1a28"), "b": look.shirt}
	return texture(SEATED, pal)


static func plant() -> ImageTexture:
	return texture(PLANT, PLANT_PALETTE)


static func alert(color: Color) -> ImageTexture:
	return texture(ALERT, {"k": Color("1a1a28"), "y": color})
