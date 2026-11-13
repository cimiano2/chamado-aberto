class_name OfficeMap
extends Node2D
## Andar da "Papéis Horizonte Ltda." em pixel art isométrica.
## A lógica (colisão, mesas, chamados) usa coordenadas de MUNDO (vista de cima);
## o desenho projeta tudo em isometria 2:1 (1 ladrilho = 64 unidades = losango de 32x16 px).

const TILE := 64.0
const COLS := 31
const ROWS := 20
const START := Vector2(1544, 290)       # sala do Suporte TI

const H_BACK := 56.0     # paredes do fundo (norte/oeste), com janelas
const H_GLASS := 40.0    # vidro da gerência e da reunião
const H_LOW := 14.0      # divisórias internas
const H_FRONT := 8.0     # bordas da frente (recortadas, estilo casa de bonecas)

## Salas em LADRILHOS: x, y, largura, altura.
var rooms: Array[Dictionary] = [
	{"name": "REUNIÃO", "tiles": Rect2i(1, 1, 6, 5), "floor": "reuniao", "color": Color("0099db")},
	{"name": "GERÊNCIA", "tiles": Rect2i(8, 1, 6, 5), "floor": "gerente", "color": Color("b55088")},
	{"name": "COPA", "tiles": Rect2i(15, 1, 5, 5), "floor": "copa", "color": Color("feae34")},
	{"name": "SUPORTE TI", "tiles": Rect2i(21, 1, 9, 5), "floor": "ti", "color": Color("2ce8f5")},
	{"name": "VENDAS", "tiles": Rect2i(1, 7, 17, 12), "floor": "carpete", "color": Color("c0cbdc")},
	{"name": "CORREDOR", "tiles": Rect2i(19, 7, 3, 12), "floor": "corredor", "color": Color("c0cbdc"), "plaque": false},
	{"name": "RH E CONTABILIDADE", "tiles": Rect2i(23, 7, 7, 6), "floor": "anexo", "color": Color("63c74d")},
	{"name": "SERVIDORES", "tiles": Rect2i(23, 14, 7, 5), "floor": "servidores", "color": Color("8b9bb4")},
]
## Portas (ladrilhos de parede que viram piso).
const DOOR_TILES: Array[Vector2i] = [Vector2i(4, 6), Vector2i(11, 6), Vector2i(17, 6), Vector2i(21, 6),
	Vector2i(18, 10), Vector2i(18, 15), Vector2i(22, 9), Vector2i(22, 16)]
## Paredes de vidro (frente da reunião e da gerência).
const GLASS_ROWS := {6: [[1, 6], [8, 13]]}

var world_rect := Rect2(0, 0, COLS * TILE, ROWS * TILE)
var floors: Array[Rect2] = []
var doors: Array[Rect2] = []
var obstacles: Array[Rect2] = []
var walls: Array[Dictionary] = []     # {rect, kind: back|glass|low|front}
## Postos com chamado: {pos, rect, center, dept, employee, kinds, priority, server, look, sprite}
var desks: Array[Dictionary] = []
var props: Array[Dictionary] = []     # decoração: {kind, center} (+ look para mesas sem chamado)
var ticket_desks := {}                # índice da mesa -> {priority, urgency}
var player: Node2D
var player_tex: Texture2D             # sprite do técnico já com a skin escolhida
var player_back := false
var player_flip := false
var player_frame := 0

var _time := 0.0
var _static: Node2D          # pisos + paredes do fundo (desenhado uma vez)
var _front: Node2D           # bordas da frente (desenhado uma vez, por cima dos objetos)
var _sorted_walls: Array = []  # divisórias e vidro: ordenados junto com os móveis

const NAMES := ["Ana", "Bruno", "Carla", "Diego", "Elisa", "Fábio", "Gabi", "Heitor", "Iara",
	"João", "Kátia", "Leo", "Marina", "Nina", "Otávio", "Paula", "Rafa", "Sofia"]

# ---------------------------------------------------------------- sprites (gerados por art/*/build.py)
var ANCHOR := {}      # lido de assets/sprites/anchors.json
## Todos os sprites do mundo vêm de UM atlas (assets/sprites/atlas.png, gerado por art/atlas/build.py):
## com uma só textura, a placa de vídeo junta piso, paredes e móveis em poucas chamadas de desenho.
const ATLAS := preload("res://assets/sprites/atlas.png")
var TEX := {}         # nome -> AtlasTexture (recorte do atlas)
var FLOOR_TEX := {}   # "carpete" -> recorte de floor_carpete, etc.
var TEX_EMPLOYEES: Texture2D
var TEX_CHAIR: Texture2D
## Pegada (mundo) de cada móvel, usada na colisão.
const FOOT := {
	"desk": Vector2(160, 60), "rack": Vector2(100, 110), "plant": Vector2(32, 32), "cooler": Vector2(28, 28),
	"conference_table": Vector2(256, 128), "vending": Vector2(56, 48), "fridge": Vector2(48, 44),
	"counter": Vector2(192, 48), "kitchen_table": Vector2(72, 72), "filing": Vector2(40, 32),
	"copier": Vector2(72, 52), "reception": Vector2(192, 56), "sofa": Vector2(128, 48),
	"workbench": Vector2(160, 56), "shelf": Vector2(96, 32), "ups": Vector2(40, 48),
}
const C_OUT := Color("181425")
const WALL_TOP := Color("ead4aa")
const WALL_S := Color("e4a672")
const WALL_E := Color("c28569")


static func iso_f(p: Vector2, z: float = 0.0) -> Vector2:
	return Vector2((p.x - p.y) / 4.0, (p.x + p.y) / 8.0 - z)


static func iso(p: Vector2, z: float = 0.0) -> Vector2:
	return Vector2(roundf((p.x - p.y) / 4.0), roundf((p.x + p.y) / 8.0 - z))


static func tile_rect(t: Rect2i) -> Rect2:
	return Rect2(t.position.x * TILE, t.position.y * TILE, t.size.x * TILE, t.size.y * TILE)


func _ready() -> void:
	load_atlas()
	var f := FileAccess.open("res://assets/sprites/anchors.json", FileAccess.READ)
	if f:
		var data: Dictionary = JSON.parse_string(f.get_as_text())
		for k in data:
			ANCHOR[k] = Vector2(data[k][0], data[k][1])
	build()
	_static = Node2D.new()
	_static.show_behind_parent = true
	_static.draw.connect(_draw_static)
	add_child(_static)
	_front = Node2D.new()
	_front.draw.connect(_draw_front)
	add_child(_front)


func load_atlas() -> void:
	var rects: Dictionary = JSON.parse_string(FileAccess.open("res://assets/sprites/atlas.json", FileAccess.READ).get_as_text())
	for name in rects:
		var r: Array = rects[name]
		var t := AtlasTexture.new()
		t.atlas = ATLAS
		t.region = Rect2(r[0], r[1], r[2], r[3])
		TEX[name] = t
		if name.begins_with("floor_"):
			FLOOR_TEX[name.substr(6)] = t
	TEX_EMPLOYEES = TEX["employees"]
	TEX_CHAIR = TEX["chair"]


func room_rect(name: String) -> Rect2:
	for r in rooms:
		if r.name == name:
			return tile_rect(r.tiles)
	return Rect2()


# ================================================================ montagem do andar

func build() -> void:
	floors.clear(); doors.clear(); obstacles.clear(); desks.clear(); props.clear(); walls.clear()
	for r in rooms:
		r.rect = tile_rect(r.tiles)
		floors.append(r.rect)
	for t in DOOR_TILES:
		var d := Rect2(t.x * TILE, t.y * TILE, TILE, TILE)
		doors.append(d)
		floors.append(d)
	var names := NAMES.duplicate()
	var look := 0
	var vendas := room_rect("VENDAS")
	var all_kinds := ["slow", "printer", "password", "phishing", "cables", "hardware",
		"files", "install", "cleanup", "extensions", "shortcuts"]

	# ---- Área de vendas: 2 fileiras de 3 mesas, recepção com sala de espera, copiadora e arquivos
	for row in 2:
		for col in 3:
			var c := Vector2(vendas.position.x + 224 + col * 352, vendas.position.y + 160 + row * 230)
			_add_desk("desk", c, "Vendas", names.pop_front(), all_kinds, false, look)
			look += 3
	_add_desk("reception", Vector2(vendas.position.x + 200, vendas.end.y - 120), "Recepção",
		names.pop_front(), ["printer", "phishing", "password", "shortcuts", "files", "extensions"], false, look)
	look += 3
	_add_prop("sofa", Vector2(vendas.position.x + 520, vendas.end.y - 50))
	_add_prop("plant", Vector2(vendas.position.x + 650, vendas.end.y - 40))
	_add_prop("copier", Vector2(vendas.end.x - 70, vendas.end.y - 100))
	_add_prop("filing", Vector2(vendas.end.x - 170, vendas.end.y - 30))
	for k in 3:
		_add_prop("filing", Vector2(vendas.position.x + 30, vendas.position.y + 130 + k * 48))
	_add_prop("plant", Vector2(vendas.position.x + 36, vendas.end.y - 40))
	_add_prop("plant", Vector2(vendas.position.x + 600, vendas.position.y + 36))

	# ---- Gerência (vidro): mesa do gerente, sofá, planta, arquivo
	var ger := room_rect("GERÊNCIA")
	_add_desk("desk", ger.get_center() + Vector2(-10, -20), "Gerência", "Gerente " + names.pop_front(),
		["password", "phishing", "slow", "printer", "files", "install", "extensions"], true, look)
	look += 3
	_add_prop("sofa", Vector2(ger.position.x + 110, ger.end.y - 50))
	_add_prop("plant", ger.position + Vector2(36, 36))
	_add_prop("filing", Vector2(ger.end.x - 40, ger.position.y + 40))

	# ---- Reunião (vidro): mesa grande; chamados de projetor/cabos
	var reu := room_rect("REUNIÃO")
	_add_desk("conference_table", reu.get_center() + Vector2(0, -16), "Sala de reunião",
		names.pop_front(), ["cables", "hardware", "extensions", "install"], false, -1)
	_add_prop("plant", reu.position + Vector2(36, 36))

	# ---- Copa: bancada, geladeira, mesa e bebedouro (sem chamados)
	var copa := room_rect("COPA")
	_add_prop("counter", Vector2(copa.position.x + 110, copa.position.y + 40))
	_add_prop("fridge", Vector2(copa.position.x + 260, copa.position.y + 40))
	_add_prop("kitchen_table", copa.get_center() + Vector2(-20, 50))
	_add_prop("cooler", Vector2(copa.end.x - 30, copa.end.y - 40))

	# ---- Suporte TI: bancada de manutenção, estante, mesa do técnico
	var ti := room_rect("SUPORTE TI")
	_add_prop("workbench", Vector2(ti.position.x + 140, ti.position.y + 44))
	_add_prop("shelf", Vector2(ti.end.x - 64, ti.position.y + 30))
	_add_prop("shelf", Vector2(ti.end.x - 170, ti.position.y + 30))
	var tdesk := Vector2(ti.position.x + 430, ti.position.y + 190)
	props.append({"kind": "desk_empty", "center": tdesk, "look": 0})
	obstacles.append(Rect2(tdesk - FOOT["desk"] / 2, FOOT["desk"]))
	_add_prop("plant", Vector2(ti.end.x - 36, ti.end.y - 36))
	_add_prop("filing", Vector2(ti.position.x + 30, ti.position.y + 150))

	# ---- Corredor: máquina de lanches, bebedouro e plantas encostados nas paredes
	var cor := room_rect("CORREDOR")
	# (portas: oeste em y 640-704 e 960-1024; leste em y 576-640 e 1024-1088)
	_add_prop("vending", Vector2(cor.end.x - 32, cor.position.y + 300))
	_add_prop("cooler", Vector2(cor.end.x - 26, cor.position.y + 420))
	_add_prop("plant", Vector2(cor.end.x - 30, cor.position.y + 500))
	_add_prop("plant", Vector2(cor.position.x + 30, cor.end.y - 36))
	_add_prop("plant", Vector2(cor.position.x + 30, cor.position.y + 40))

	# ---- RH e Contabilidade: 2 mesas da contabilidade + 1 do RH, arquivos
	var cont := room_rect("RH E CONTABILIDADE")
	var cont_kinds := ["slow", "printer", "password", "hardware", "phishing", "cleanup", "extensions", "shortcuts", "files"]
	for c in [Vector2(cont.position.x + 150, cont.position.y + 110), Vector2(cont.position.x + 360, cont.position.y + 110)]:
		_add_desk("desk", c, "Contabilidade", names.pop_front(), cont_kinds, false, look)
		look += 3
	_add_desk("desk", Vector2(cont.position.x + 230, cont.position.y + 270), "RH", names.pop_front(),
		["password", "phishing", "printer", "files", "shortcuts", "install"], false, look)
	look += 3
	_add_prop("filing", Vector2(cont.end.x - 26, cont.end.y - 120))
	_add_prop("filing", Vector2(cont.end.x - 26, cont.end.y - 70))
	_add_prop("plant", cont.position + Vector2(36, 36))

	# ---- Servidores: três racks na parede do fundo, nobreaks e estante
	var srv := room_rect("SERVIDORES")
	var rack_names := ["ARQ01", "WEB01", "BD01"]
	for k in 3:
		var c := Vector2(srv.position.x + 90 + k * 140, srv.position.y + 70)
		var rect := Rect2(c - FOOT["rack"] / 2, FOOT["rack"])
		obstacles.append(rect)
		desks.append({"pos": Vector2(c.x, rect.end.y + 40), "rect": rect, "center": c, "dept": "Servidores",
			"employee": "Servidor %s" % rack_names[k], "kinds": ["hardware", "slow", "cleanup"],
			"priority": false, "server": true, "look": -1, "sprite": "rack"})
	_add_prop("ups", Vector2(srv.position.x + 90, srv.end.y - 40))
	_add_prop("ups", Vector2(srv.position.x + 150, srv.end.y - 40))
	_add_prop("shelf", Vector2(srv.end.x - 70, srv.end.y - 30))

	_build_walls()


## Móvel com funcionário e chamados possíveis.
func _add_desk(sprite: String, c: Vector2, dept: String, employee: String, kinds: Array,
		priority: bool, look: int) -> void:
	var rect := Rect2(c - FOOT[sprite] / 2, FOOT[sprite])
	obstacles.append(rect)
	if sprite == "desk" or sprite == "reception":
		obstacles.append(Rect2(c + Vector2(-6, -FOOT[sprite].y / 2 - 44), Vector2(60, 44)))   # cadeira + pessoa
	desks.append({"pos": Vector2(c.x, rect.end.y + 34), "rect": rect, "center": c, "dept": dept,
		"employee": employee, "kinds": kinds, "priority": priority, "server": false,
		"look": look % 8 if look >= 0 else -1, "sprite": sprite})


func _add_prop(kind: String, c: Vector2) -> void:
	props.append({"kind": kind, "center": c})
	obstacles.append(Rect2(c - FOOT[kind] / 2, FOOT[kind]))


func _build_walls() -> void:
	for ty in ROWS:
		for tx in COLS:
			var c := Vector2(tx * TILE + TILE / 2, ty * TILE + TILE / 2)
			if _in_floor(c):
				continue
			var kind := "low"
			if ty == 0 or tx == 0:
				kind = "back"
			elif ty == ROWS - 1 or tx == COLS - 1:
				kind = "front"
			elif GLASS_ROWS.has(ty):
				for span in GLASS_ROWS[ty]:
					if tx >= span[0] and tx <= span[1]:
						kind = "glass"
			walls.append({"rect": Rect2(tx * TILE, ty * TILE, TILE, TILE), "kind": kind,
				"sprite": _wall_sprite(kind, tx, ty)})


func _wall_sprite(kind: String, tx: int, ty: int) -> String:
	match kind:
		"back":
			if ty == 0 and tx > 0 and tx < COLS - 1 and tx % 2 == 1:
				return "wall_back_win_s"      # janela com persiana na parede norte
			if tx == 0 and ty > 0 and ty < ROWS - 1 and ty % 2 == 1:
				return "wall_back_win_e"      # janela na parede oeste
			return "wall_back"
		"front":
			return "wall_front"
		"glass":
			return "wall_glass"
	return "wall_low"


## Mantido para os testes: paredes altas só no fundo do andar.
func is_back_wall(w: Rect2) -> bool:
	return w.position.y < TILE or w.position.x < TILE


func _in_floor(p: Vector2) -> bool:
	for f in floors:
		if f.has_point(p):
			return true
	return false


## Uma caixa (pés do personagem) está toda dentro do piso e fora dos móveis?
func is_walkable(box: Rect2) -> bool:
	for corner in [box.position, Vector2(box.end.x, box.position.y), Vector2(box.position.x, box.end.y), box.end]:
		if not _in_floor(corner):
			return false
	for o in obstacles:
		if o.intersects(box):
			return false
	return true


func desk_index_near(pos: Vector2, radius: float = 80.0) -> int:
	var best := -1
	var best_d := radius
	for i in desks.size():
		var d := pos.distance_to(desks[i].pos)
		if d < best_d:
			best_d = d
			best = i
	return best


## Ponto acima da cabeça de quem está na mesa (para balões de fala, acima do "!").
func speaker_point(i: int) -> Vector2:
	var d: Dictionary = desks[i]
	return iso_f(d.center + Vector2(24, -44), 74 if not d.server else 94)


func iso_bounds() -> Rect2:
	var pts := [iso(world_rect.position), iso(Vector2(world_rect.end.x, world_rect.position.y)),
		iso(Vector2(world_rect.position.x, world_rect.end.y)), iso(world_rect.end)]
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r.grow_individual(8, H_BACK + 16, 8, 8)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


# ================================================================ camadas estáticas
# Desenhadas uma única vez (não a cada quadro) e com sprites iguais em sequência,
# para a placa de vídeo juntar tudo em poucas chamadas de desenho.

func _draw_static() -> void:
	var ci := _static
	# pisos agrupados por textura
	var by_tex := {}
	for r in rooms:
		_collect_tiles(by_tex, r.rect, r.floor)
	for d in doors:
		_collect_tiles(by_tex, d, "carpete")
	for key in by_tex:
		var tex: Texture2D = FLOOR_TEX[key]
		for pos in by_tex[key]:
			ci.draw_texture(tex, pos)
	# paredes do fundo, de trás para frente
	var back := walls.filter(func(w): return w.kind == "back")
	back.sort_custom(func(a, b): return _wall_key(a) < _wall_key(b))
	for w in back:
		_draw_wall_on(ci, w)


func _draw_front() -> void:
	for w in walls:
		if w.kind == "front":
			_draw_wall_on(_front, w)


func _collect_tiles(by_tex: Dictionary, r: Rect2, floor: String) -> void:
	var ty := 0
	var y := r.position.y
	while y < r.end.y - 1:
		var tx := 0
		var x := r.position.x
		while x < r.end.x - 1:
			var key := floor
			if floor == "copa":
				key = "copa_a" if (tx + ty) % 2 == 0 else "copa_b"
			if not by_tex.has(key):
				by_tex[key] = []
			by_tex[key].append(iso(Vector2(x + TILE / 2, y + TILE / 2)) - Vector2(16, 8))
			x += TILE
			tx += 1
		y += TILE
		ty += 1


func _wall_key(w: Dictionary) -> float:
	var c: Vector2 = w.rect.get_center()
	return c.x + c.y + 30


func _draw_wall_on(ci: CanvasItem, w: Dictionary) -> void:
	ci.draw_texture(TEX[w.sprite], iso(w.rect.get_center()) - ANCHOR[w.sprite])


# ================================================================ camada dinâmica (divisórias + objetos ordenados)

var draw_usec := 0          # tempo do último _draw (medição de desempenho)
var draw_items := 0


func _draw() -> void:
	var t0 := Time.get_ticks_usec()
	_draw_dynamic()
	draw_usec = Time.get_ticks_usec() - t0


func _draw_dynamic() -> void:
	var items: Array = []   # [chave_de_profundidade, Callable]
	for w in walls:
		if w.kind == "low" or w.kind == "glass":
			items.append([_wall_key(w), _draw_wall_on.bind(self, w)])
	for i in desks.size():
		var d: Dictionary = desks[i]
		var c: Vector2 = d.center
		var alert := ticket_desks.has(i)
		match d.sprite:
			"rack":
				items.append([c.x + c.y, _draw_sprite.bind("rack_alert" if alert else "rack", c)])
			"desk":
				items.append([c.x + c.y - 60, _draw_worker.bind(c, d.look, Vector2(24, -44), alert)])
				items.append([c.x + c.y, _draw_sprite.bind("desk_alert" if alert else "desk", c)])
			"reception":
				items.append([c.x + c.y - 60, _draw_worker.bind(c, d.look, Vector2(30, -50), alert)])
				items.append([c.x + c.y, _draw_sprite.bind("reception", c)])
			_:
				items.append([c.x + c.y, _draw_sprite.bind(d.sprite, c)])
	for p in props:
		var c: Vector2 = p.center
		if p.kind == "desk_empty":
			items.append([c.x + c.y - 60, _draw_chair.bind(c)])
			items.append([c.x + c.y, _draw_sprite.bind("desk", c)])
		else:
			items.append([c.x + c.y, _draw_sprite.bind(p.kind, c)])
	if player:
		items.append([player.position.x + player.position.y, _draw_player])
	items.sort_custom(func(a, b): return a[0] < b[0])
	# anel pulsante no chão em volta de quem pediu ajuda (desenhado antes dos móveis)
	for i in ticket_desks:
		_draw_ring(i)
	draw_items = items.size()
	for it in items:
		it[1].call()
	for i in ticket_desks:
		_draw_alert(i)


func _draw_sprite(key: String, world: Vector2) -> void:
	draw_texture(TEX[key], iso(world) - ANCHOR[key])


func _draw_chair(c: Vector2) -> void:
	draw_texture(TEX_CHAIR, iso(c + Vector2(24, -52)) - Vector2(11, 25))


## Funcionário sentado; com chamado aberto, levanta a mão e acena (quadros 1 e 2 da folha).
func _draw_worker(c: Vector2, look: int, off: Vector2, waving := false) -> void:
	draw_texture(TEX_CHAIR, iso(c + off + Vector2(0, -8)) - Vector2(11, 25))
	var pos := iso(c + off) - Vector2(11, 38)
	var pose := 0
	if waving:
		pose = 1 + int(_time * 4.0) % 2
	draw_texture_rect_region(TEX_EMPLOYEES, Rect2(pos, Vector2(22, 32)), Rect2((pose * 8 + maxi(look, 0)) * 22, 0, 22, 32))


func _alert_color(i: int) -> Color:
	var info: Dictionary = ticket_desks[i]
	if info.urgency > 0.7:
		return Color("e43b44")
	return Color("b55088") if info.priority else Color("feae34")


## Losango pulsante no chão, centrado em quem abriu o chamado (ou no rack).
func _draw_ring(i: int) -> void:
	var d: Dictionary = desks[i]
	var c: Vector2 = d.center
	var who: Vector2 = c if d.server or d.sprite == "conference_table" else c + Vector2(24, -40)
	var pulse := 0.5 + 0.5 * sin(_time * 6.0)
	var r := 44.0 + 10.0 * pulse
	var pts := PackedVector2Array([iso(who + Vector2(-r, -r)), iso(who + Vector2(r, -r)), iso(who + Vector2(r, r)), iso(who + Vector2(-r, r))])
	var col := _alert_color(i)
	draw_colored_polygon(pts, Color(col, 0.18 + 0.12 * pulse))
	pts.append(pts[0])
	draw_polyline(pts, Color(col, 0.9), 1.0)


func _draw_player() -> void:
	var base := iso(player.position)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-7, 0), base + Vector2(0, -3), base + Vector2(7, 0), base + Vector2(0, 3)]), Color(0, 0, 0, 0.3))
	var frame := player_frame + (4 if player_back else 0)
	var src := Rect2(frame * 20, 0, 20, 34)
	var dst := Rect2(base - Vector2(10, 33), Vector2(20, 34))
	if player_flip:
		draw_set_transform(Vector2(base.x * 2.0, 0), 0.0, Vector2(-1, 1))
	if player_tex == null:
		player_tex = Skins.texture(0, 0, 0)
	draw_texture_rect_region(player_tex, dst, src)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Balão "!" em dobro do tamanho, sobre a cabeça de quem pediu ajuda, com a barrinha do prazo.
func _draw_alert(i: int) -> void:
	var d: Dictionary = desks[i]
	var info: Dictionary = ticket_desks[i]
	var key := "alert_urgent" if info.urgency > 0.7 else ("alert_high" if info.priority else "alert")
	var bob := roundf(sin(_time * 5.0 + i) * 2.0)
	var p: Vector2
	if d.server:
		p = iso(d.center, 72)
	elif d.sprite == "conference_table":
		p = iso(d.center, 44)
	else:
		p = iso(d.center + (Vector2(30, -50) if d.sprite == "reception" else Vector2(24, -44)), 50)
	p += Vector2(0, bob)
	var tex: Texture2D = TEX[key]
	draw_texture_rect(tex, Rect2(p - ANCHOR[key] * 2.0, tex.get_size() * 2.0), false)
	var left := 1.0 - float(info.urgency)
	draw_rect(Rect2(p + Vector2(-12, 3), Vector2(24, 3)), C_OUT)
	draw_rect(Rect2(p + Vector2(-12, 3), Vector2(roundf(24 * left), 3)),
		Color("63c74d") if left > 0.5 else (Color("feae34") if left > 0.25 else Color("e43b44")))
