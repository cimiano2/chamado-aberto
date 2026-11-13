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
var _static: Node2D

const NAMES := ["Ana", "Bruno", "Carla", "Diego", "Elisa", "Fábio", "Gabi", "Heitor", "Iara",
	"João", "Kátia", "Leo", "Marina", "Nina", "Otávio", "Paula", "Rafa", "Sofia"]

# ---------------------------------------------------------------- sprites (gerados por art/*/build.py)
const TEX_EMPLOYEES := preload("res://assets/sprites/employees.png")
const TEX_CHAIR := preload("res://assets/sprites/chair.png")
const TEX := {
	"desk": preload("res://assets/sprites/desk.png"),
	"desk_alert": preload("res://assets/sprites/desk_alert.png"),
	"rack": preload("res://assets/sprites/rack.png"),
	"rack_alert": preload("res://assets/sprites/rack_alert.png"),
	"plant": preload("res://assets/sprites/plant.png"),
	"cooler": preload("res://assets/sprites/cooler.png"),
	"alert": preload("res://assets/sprites/alert.png"),
	"alert_high": preload("res://assets/sprites/alert_high.png"),
	"alert_urgent": preload("res://assets/sprites/alert_urgent.png"),
	"conference_table": preload("res://assets/sprites/conference_table.png"),
	"vending": preload("res://assets/sprites/vending.png"),
	"fridge": preload("res://assets/sprites/fridge.png"),
	"counter": preload("res://assets/sprites/counter.png"),
	"kitchen_table": preload("res://assets/sprites/kitchen_table.png"),
	"filing": preload("res://assets/sprites/filing.png"),
	"copier": preload("res://assets/sprites/copier.png"),
	"reception": preload("res://assets/sprites/reception.png"),
	"sofa": preload("res://assets/sprites/sofa.png"),
	"workbench": preload("res://assets/sprites/workbench.png"),
	"shelf": preload("res://assets/sprites/shelf.png"),
	"ups": preload("res://assets/sprites/ups.png"),
}
var ANCHOR := {}      # lido de assets/sprites/anchors.json
## Pegada (mundo) de cada móvel, usada na colisão.
const FOOT := {
	"desk": Vector2(160, 60), "rack": Vector2(100, 110), "plant": Vector2(32, 32), "cooler": Vector2(28, 28),
	"conference_table": Vector2(256, 128), "vending": Vector2(56, 48), "fridge": Vector2(48, 44),
	"counter": Vector2(192, 48), "kitchen_table": Vector2(72, 72), "filing": Vector2(40, 32),
	"copier": Vector2(72, 52), "reception": Vector2(192, 56), "sofa": Vector2(128, 48),
	"workbench": Vector2(160, 56), "shelf": Vector2(96, 32), "ups": Vector2(40, 48),
}
const FLOOR_TEX := {
	"carpete": preload("res://assets/sprites/floor_carpete.png"),
	"gerente": preload("res://assets/sprites/floor_gerente.png"),
	"reuniao": preload("res://assets/sprites/floor_reuniao.png"),
	"anexo": preload("res://assets/sprites/floor_anexo.png"),
	"rh": preload("res://assets/sprites/floor_rh.png"),
	"ti": preload("res://assets/sprites/floor_ti.png"),
	"copa_a": preload("res://assets/sprites/floor_copa_a.png"),
	"copa_b": preload("res://assets/sprites/floor_copa_b.png"),
	"servidores": preload("res://assets/sprites/floor_servidores.png"),
	"corredor": preload("res://assets/sprites/floor_corredor.png"),
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
	var all_kinds := ["slow", "printer", "password", "phishing", "cables", "hardware"]

	# ---- Área de vendas: 2 fileiras de 3 mesas, recepção com sala de espera, copiadora e arquivos
	for row in 2:
		for col in 3:
			var c := Vector2(vendas.position.x + 224 + col * 352, vendas.position.y + 160 + row * 230)
			_add_desk("desk", c, "Vendas", names.pop_front(), all_kinds, false, look)
			look += 3
	_add_desk("reception", Vector2(vendas.position.x + 200, vendas.end.y - 120), "Recepção",
		names.pop_front(), ["printer", "phishing", "password"], false, look)
	look += 3
	_add_prop("sofa", Vector2(vendas.position.x + 520, vendas.end.y - 50))
	_add_prop("plant", Vector2(vendas.position.x + 650, vendas.end.y - 40))
	_add_prop("copier", Vector2(vendas.end.x - 70, vendas.end.y - 100))
	_add_prop("filing", Vector2(vendas.end.x - 40, vendas.end.y - 220))
	for k in 3:
		_add_prop("filing", Vector2(vendas.position.x + 30, vendas.position.y + 130 + k * 48))
	_add_prop("plant", Vector2(vendas.position.x + 36, vendas.end.y - 40))
	_add_prop("plant", Vector2(vendas.end.x - 36, vendas.position.y + 36))

	# ---- Gerência (vidro): mesa do gerente, sofá, planta, arquivo
	var ger := room_rect("GERÊNCIA")
	_add_desk("desk", ger.get_center() + Vector2(-10, -20), "Gerência", "Gerente " + names.pop_front(),
		["password", "phishing", "slow", "printer"], true, look)
	look += 3
	_add_prop("sofa", Vector2(ger.position.x + 110, ger.end.y - 50))
	_add_prop("plant", ger.position + Vector2(36, 36))
	_add_prop("filing", Vector2(ger.end.x - 40, ger.position.y + 40))

	# ---- Reunião (vidro): mesa grande; chamados de projetor/cabos
	var reu := room_rect("REUNIÃO")
	_add_desk("conference_table", reu.get_center() + Vector2(0, -16), "Sala de reunião",
		names.pop_front(), ["cables", "hardware"], false, -1)
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
	_add_prop("filing", Vector2(ti.position.x + 30, ti.end.y - 60))

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
	var cont_kinds := ["slow", "printer", "password", "hardware", "phishing"]
	for c in [Vector2(cont.position.x + 125, cont.position.y + 110), Vector2(cont.position.x + 335, cont.position.y + 110)]:
		_add_desk("desk", c, "Contabilidade", names.pop_front(), cont_kinds, false, look)
		look += 3
	_add_desk("desk", Vector2(cont.position.x + 230, cont.position.y + 270), "RH", names.pop_front(),
		["password", "phishing", "printer"], false, look)
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
			"employee": "Servidor %s" % rack_names[k], "kinds": ["hardware", "slow"],
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
			walls.append({"rect": Rect2(tx * TILE, ty * TILE, TILE, TILE), "kind": kind})


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


## Ponto acima da cabeça de quem está na mesa (para balões de fala).
func speaker_point(i: int) -> Vector2:
	var d: Dictionary = desks[i]
	return iso_f(d.center + Vector2(24, -44), 46 if not d.server else 66)


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


# ================================================================ camada estática (pisos)

func _draw_static() -> void:
	var ci := _static
	for r in rooms:
		_draw_tiles(ci, r.rect, r.floor)
	for d in doors:
		_draw_tiles(ci, d, "carpete")


func _draw_tiles(ci: CanvasItem, r: Rect2, floor: String) -> void:
	var ty := 0
	var y := r.position.y
	while y < r.end.y - 1:
		var tx := 0
		var x := r.position.x
		while x < r.end.x - 1:
			var key := floor
			if floor == "copa":
				key = "copa_a" if (tx + ty) % 2 == 0 else "copa_b"
			ci.draw_texture(FLOOR_TEX[key], iso(Vector2(x + TILE / 2, y + TILE / 2)) - Vector2(16, 8))
			x += TILE
			tx += 1
		y += TILE
		ty += 1


# ================================================================ camada dinâmica (paredes + objetos ordenados)

func _draw() -> void:
	var items: Array = []   # [chave_de_profundidade, Callable]
	for w in walls:
		var r: Rect2 = w.rect
		items.append([r.get_center().x + r.get_center().y + 30, _draw_wall.bind(w)])
	for i in desks.size():
		var d: Dictionary = desks[i]
		var c: Vector2 = d.center
		var alert := ticket_desks.has(i)
		match d.sprite:
			"rack":
				items.append([c.x + c.y, _draw_sprite.bind("rack_alert" if alert else "rack", c)])
			"desk":
				items.append([c.x + c.y - 60, _draw_worker.bind(c, d.look, Vector2(24, -44))])
				items.append([c.x + c.y, _draw_sprite.bind("desk_alert" if alert else "desk", c)])
			"reception":
				items.append([c.x + c.y - 60, _draw_worker.bind(c, d.look, Vector2(30, -50))])
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
	for it in items:
		it[1].call()
	for i in ticket_desks:
		_draw_alert(i)


func _draw_wall(w: Dictionary) -> void:
	var r: Rect2 = w.rect
	match w.kind:
		"back":
			_iso_box(r, H_BACK, WALL_TOP, WALL_S, WALL_E)
			_draw_window(r)
		"low":
			_iso_box(r, H_LOW, WALL_TOP, WALL_S, WALL_E)
		"front":
			_iso_box(r, H_FRONT, WALL_TOP, WALL_S, WALL_E)
		"glass":
			_draw_glass(r)


func _iso_box(r: Rect2, h: float, top: Color, left: Color, right: Color) -> void:
	var N := r.position
	var E := Vector2(r.end.x, r.position.y)
	var S := r.end
	var W := Vector2(r.position.x, r.end.y)
	draw_colored_polygon(PackedVector2Array([iso(W), iso(S), iso(S, h), iso(W, h)]), left)
	draw_colored_polygon(PackedVector2Array([iso(S), iso(E), iso(E, h), iso(S, h)]), right)
	draw_colored_polygon(PackedVector2Array([iso(N, h), iso(E, h), iso(S, h), iso(W, h)]), top)
	draw_polyline(PackedVector2Array([iso(N, h), iso(E, h), iso(S, h), iso(W, h), iso(N, h)]), C_OUT, 1.0)
	draw_line(iso(W), iso(S), C_OUT, 1.0)
	draw_line(iso(S), iso(E), C_OUT, 1.0)
	draw_line(iso(S), iso(S, h), C_OUT, 1.0)


## Janela com persiana na face voltada para dentro do andar (paredes do fundo).
func _draw_window(r: Rect2) -> void:
	var tx := int(r.position.x / TILE)
	var ty := int(r.position.y / TILE)
	var q: Array
	if ty == 0 and tx > 0 and tx < COLS - 1 and tx % 2 == 1:
		var a := Vector2(r.position.x + 10, r.end.y)
		var b := Vector2(r.end.x - 10, r.end.y)
		q = [iso(a, 14), iso(b, 14), iso(b, 46), iso(a, 46)]
	elif tx == 0 and ty > 0 and ty < ROWS - 1 and ty % 2 == 1:
		var a := Vector2(r.end.x, r.position.y + 10)
		var b := Vector2(r.end.x, r.end.y - 10)
		q = [iso(a, 14), iso(b, 14), iso(b, 46), iso(a, 46)]
	else:
		return
	draw_colored_polygon(PackedVector2Array(q), Color("8fd3ff"))
	# persiana: lâminas horizontais na metade de cima
	for k in 5:
		var t := 0.06 + k * 0.1
		draw_line(q[3].lerp(q[0], t), q[2].lerp(q[1], t), Color("f4f4f4"), 1.0)
	draw_polyline(PackedVector2Array(q + [q[0]]), C_OUT, 1.0)


func _draw_glass(r: Rect2) -> void:
	var W := Vector2(r.position.x, r.end.y)
	var S := r.end
	var N := r.position
	var E := Vector2(r.end.x, r.position.y)
	# rodapé baixo
	_iso_box(r, 6.0, WALL_TOP, WALL_S, WALL_E)
	# painel de vidro translúcido sobre o rodapé (face sul)
	var pane := PackedVector2Array([iso(W, 6), iso(S, 6), iso(S, H_GLASS), iso(W, H_GLASS)])
	draw_colored_polygon(pane, Color(0.75, 0.92, 1.0, 0.28))
	draw_line(iso(W, H_GLASS), iso(S, H_GLASS), Color("5a6988"), 1.0)
	draw_line(iso(N, H_GLASS), iso(E, H_GLASS), Color("5a6988"), 1.0)
	draw_line(iso(S, 6), iso(S, H_GLASS), Color("5a6988"), 1.0)
	# reflexo diagonal
	draw_line(iso(W.lerp(S, 0.2), 12), iso(W.lerp(S, 0.45), 34), Color(1, 1, 1, 0.55), 1.0)


func _draw_sprite(key: String, world: Vector2) -> void:
	draw_texture(TEX[key], iso(world) - ANCHOR[key])


func _draw_chair(c: Vector2) -> void:
	draw_texture(TEX_CHAIR, iso(c + Vector2(24, -52)) - Vector2(11, 25))


func _draw_worker(c: Vector2, look: int, off: Vector2) -> void:
	draw_texture(TEX_CHAIR, iso(c + off + Vector2(0, -8)) - Vector2(11, 25))
	var pos := iso(c + off) - Vector2(10, 30)
	draw_texture_rect_region(TEX_EMPLOYEES, Rect2(pos, Vector2(20, 24)), Rect2(maxi(look, 0) * 20, 0, 20, 24))


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


func _draw_alert(i: int) -> void:
	var d: Dictionary = desks[i]
	var info: Dictionary = ticket_desks[i]
	var key := "alert_urgent" if info.urgency > 0.7 else ("alert_high" if info.priority else "alert")
	var bob := roundf(sin(_time * 5.0 + i) * 2.0)
	var h := 66.0 if d.server else 56.0
	var p := iso(d.center, h) + Vector2(0, bob)
	draw_texture(TEX[key], p - ANCHOR[key])
	var left := 1.0 - float(info.urgency)
	draw_rect(Rect2(p + Vector2(-6, 3), Vector2(12, 2)), C_OUT)
	draw_rect(Rect2(p + Vector2(-6, 3), Vector2(roundf(12 * left), 2)),
		Color("63c74d") if left > 0.5 else (Color("feae34") if left > 0.25 else Color("e43b44")))
