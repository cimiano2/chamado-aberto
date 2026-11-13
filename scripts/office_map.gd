class_name OfficeMap
extends Node2D
## Andar da empresa em pixel art isométrica.
## A lógica (colisão, mesas, chamados) usa coordenadas de MUNDO (vista de cima);
## o desenho projeta tudo em isometria 2:1 (64 unidades = losango de 32x16 px).

const TILE := 64.0
const START := Vector2(448, 1080)
const WALL_LOW := 10.0        # altura (px) das divisórias internas
const WALL_HIGH := 54.0       # altura (px) das paredes externas

const DEPT_NAMES := {"DIRETORIA": "Diretoria", "FINANCEIRO": "Financeiro", "RH": "RH",
	"SUPORTE TI": "Suporte TI", "MARKETING": "Marketing", "SERVIDORES": "Servidores"}

## Salas alinhadas à grade (12 x 7 ladrilhos cada).
var rooms: Array[Dictionary] = [
	{"name": "DIRETORIA", "rect": Rect2(64, 64, 768, 448), "floor": "diretoria", "kinds": ["cpu", "chmod", "alloc", "paging"], "priority": true},
	{"name": "FINANCEIRO", "rect": Rect2(896, 64, 768, 448), "floor": "financeiro", "kinds": ["chmod", "deadlock", "cpu", "alloc"], "priority": false},
	{"name": "RH", "rect": Rect2(1728, 64, 768, 448), "floor": "rh", "kinds": ["chmod", "cpu", "paging", "alloc"], "priority": false},
	{"name": "SUPORTE TI", "rect": Rect2(64, 832, 768, 448), "floor": "suporte", "kinds": [], "priority": false},
	{"name": "MARKETING", "rect": Rect2(896, 832, 768, 448), "floor": "marketing", "kinds": ["alloc", "paging", "cpu", "chmod"], "priority": false},
	{"name": "SERVIDORES", "rect": Rect2(1728, 832, 768, 448), "floor": "servidores", "kinds": ["disk", "deadlock", "paging", "disk"], "priority": false},
]
var hall := Rect2(64, 576, 2432, 192)
var world_rect := Rect2(0, 0, 2560, 1344)
var doors: Array[Rect2] = []
var floors: Array[Rect2] = []
var obstacles: Array[Rect2] = []
var walls: Array[Rect2] = []          # blocos de parede (regiões fora do piso)
## Postos com chamado: {pos, rect, center, dept, employee, kinds, priority, server, look}
var desks: Array[Dictionary] = []
var props: Array[Dictionary] = []     # decoração: {kind, center}
var ticket_desks := {}                # índice da mesa -> {priority, urgency}
var player: Node2D                    # técnico (lógica em coordenadas de mundo)
var player_back := false
var player_flip := false
var player_frame := 0

var _time := 0.0
var _static: Node2D

const FIRST_NAMES := ["Ana", "Bruno", "Carla", "Diego", "Elisa", "Fábio", "Gabi", "Heitor", "Iara",
	"João", "Kátia", "Leo", "Marina", "Nina", "Otávio", "Paula", "Rafa", "Sofia", "Tiago", "Vera"]

# ---------------------------------------------------------------- sprites (assets/sprites, gerados por art/*/build.py)
const TEX_TECH := preload("res://assets/sprites/technician.png")
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
}
## Ponto de ancoragem de cada sprite (centro da pegada no chão), de art/office/anchors.json.
const ANCHOR := {
	"desk": Vector2(30, 32), "desk_alert": Vector2(30, 32), "rack": Vector2(27, 58),
	"rack_alert": Vector2(27, 58), "plant": Vector2(13, 29), "cooler": Vector2(9, 34),
	"alert": Vector2(5, 11), "alert_high": Vector2(5, 11), "alert_urgent": Vector2(5, 11),
}
const FLOOR_TEX := {
	"diretoria": preload("res://assets/sprites/floor_diretoria.png"),
	"financeiro": preload("res://assets/sprites/floor_financeiro.png"),
	"rh": preload("res://assets/sprites/floor_rh.png"),
	"suporte": preload("res://assets/sprites/floor_suporte.png"),
	"marketing": preload("res://assets/sprites/floor_marketing.png"),
	"servidores": preload("res://assets/sprites/floor_servidores.png"),
	"corredor": preload("res://assets/sprites/floor_corredor.png"),
}
const C_OUT := Color("181425")
const C_WALL_TOP := Color("8b9bb4")
const C_WALL_L := Color("5a6988")
const C_WALL_R := Color("3a4466")
const C_WINDOW := Color("2ce8f5")
const C_WINDOW_D := Color("0099db")


static func iso(p: Vector2, z: float = 0.0) -> Vector2:
	return Vector2(roundf((p.x - p.y) / 4.0), roundf((p.x + p.y) / 8.0 - z))


func _ready() -> void:
	build()
	_static = Node2D.new()
	_static.show_behind_parent = true
	_static.draw.connect(_draw_static)
	add_child(_static)


func build() -> void:
	doors.clear(); floors.clear(); obstacles.clear(); desks.clear(); walls.clear(); props.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024   # layout fixo; só os chamados variam
	var names := FIRST_NAMES.duplicate()
	OSLogic._shuffle(names, rng)
	var look_i := 0
	for room in rooms:
		var r: Rect2 = room.rect
		var top_row: bool = r.position.y < hall.position.y
		var door := Rect2(r.get_center().x - 64, r.end.y if top_row else hall.end.y, 128, 64)
		doors.append(door)
		floors.append(r)
		var server: bool = room.name == "SERVIDORES"
		for k in 4:
			var cx := r.position.x + (224.0 if k % 2 == 0 else 544.0)
			var cy := r.position.y + (150.0 if k < 2 else 320.0)
			if not top_row:
				cy += 20.0
			var rect := Rect2(cx - 80, cy - 30, 160, 60) if not server else Rect2(cx - 50, cy - 55, 100, 110)
			obstacles.append(rect)
			if not server:
				obstacles.append(Rect2(cx - 30, cy - 70, 60, 40))   # cadeira + funcionário
			var d := {
				"pos": Vector2(cx, rect.end.y + 34), "rect": rect, "center": Vector2(cx, cy),
				"dept": DEPT_NAMES[room.name], "kinds": room.kinds, "priority": room.priority,
				"server": server, "look": look_i % 8,
				"employee": "Servidor %s" % ["ARQ01", "BD01", "WEB01", "BKP01"][k] if server else names.pop_back(),
			}
			look_i += 3
			if room.kinds.is_empty():
				props.append({"kind": "desk_empty", "center": d.center, "look": d.look})
			else:
				desks.append(d)
	floors.append(hall)
	floors.append_array(doors)
	# decoração no corredor (também bloqueia)
	for x in [320.0, 1280.0, 2240.0]:
		var c := Vector2(x, hall.position.y + 26)
		props.append({"kind": "plant", "center": c})
		obstacles.append(Rect2(c - Vector2(16, 16), Vector2(32, 32)))
	for x in [800.0, 1760.0]:
		var c := Vector2(x, hall.end.y - 24)
		props.append({"kind": "cooler", "center": c})
		obstacles.append(Rect2(c - Vector2(14, 14), Vector2(28, 28)))
	_build_walls()


## Blocos de parede = tudo dentro do mundo que não é piso (faixas entre salas e bordas).
func _build_walls() -> void:
	var g := TILE
	var cols := int(world_rect.size.x / g)
	var rows := int(world_rect.size.y / g)
	for ty in rows:
		var run_start := -1
		for tx in cols + 1:
			var solid := false
			if tx < cols:
				var c := Vector2(tx * g + g / 2, ty * g + g / 2)
				solid = not _in_floor(c)
			if solid and run_start < 0:
				run_start = tx
			elif not solid and run_start >= 0:
				walls.append(Rect2(run_start * g, ty * g, (tx - run_start) * g, g))
				run_start = -1


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


func iso_bounds() -> Rect2:
	var pts := [iso(world_rect.position), iso(Vector2(world_rect.end.x, world_rect.position.y)),
		iso(Vector2(world_rect.position.x, world_rect.end.y)), iso(world_rect.end)]
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r.grow_individual(8, WALL_HIGH + 16, 8, 8)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


# ================================================================ camada estática (piso + paredes)

func _draw_static() -> void:
	var ci := _static
	for room in rooms:
		_draw_tiles(ci, room.rect, FLOOR_TEX[room.floor])
	_draw_tiles(ci, hall, FLOOR_TEX["corredor"])
	for d in doors:
		_draw_tiles(ci, d, FLOOR_TEX["corredor"])
	# paredes: altas na borda de trás (norte/oeste), baixas no resto; de trás para frente
	var sorted := walls.duplicate()
	sorted.sort_custom(func(a, b): return a.get_center().x + a.get_center().y < b.get_center().x + b.get_center().y)
	for w in sorted:
		var high: bool = w.position.y < 64 or w.position.x < 64
		_iso_box(ci, w, WALL_HIGH if high else WALL_LOW, C_WALL_TOP, C_WALL_L, C_WALL_R)
		if high and w.position.y < 64:
			_draw_windows(ci, w)
	# nomes das salas pintados no piso
	var font: Font = ThemeDB.get_project_theme().default_font
	for room in rooms:
		var p := iso(room.rect.position + Vector2(48, 48))
		ci.draw_string_outline(font, p + Vector2(-6, 4), room.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, Color(0, 0, 0, 0.35))
		ci.draw_string(font, p + Vector2(-6, 4), room.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.8))


func _draw_tiles(ci: CanvasItem, r: Rect2, tex: Texture2D) -> void:
	var y := r.position.y
	while y < r.end.y - 1:
		var x := r.position.x
		while x < r.end.x - 1:
			ci.draw_texture(tex, iso(Vector2(x + TILE / 2, y + TILE / 2)) - Vector2(16, 8))
			x += TILE
		y += TILE


func _iso_box(ci: CanvasItem, r: Rect2, h: float, top: Color, left: Color, right: Color) -> void:
	var N := r.position
	var E := Vector2(r.end.x, r.position.y)
	var S := r.end
	var W := Vector2(r.position.x, r.end.y)
	ci.draw_colored_polygon(PackedVector2Array([iso(W), iso(S), iso(S, h), iso(W, h)]), left)
	ci.draw_colored_polygon(PackedVector2Array([iso(S), iso(E), iso(E, h), iso(S, h)]), right)
	ci.draw_colored_polygon(PackedVector2Array([iso(N, h), iso(E, h), iso(S, h), iso(W, h)]), top)
	ci.draw_polyline(PackedVector2Array([iso(N, h), iso(E, h), iso(S, h), iso(W, h), iso(N, h)]), C_OUT, 1.0)
	ci.draw_line(iso(W), iso(S), C_OUT, 1.0)
	ci.draw_line(iso(S), iso(E), C_OUT, 1.0)


func _draw_windows(ci: CanvasItem, w: Rect2) -> void:
	# janelas na face sul da parede externa do fundo
	var x := w.position.x + 112.0
	while x + 64.0 <= w.end.x - 32.0:
		var a := Vector2(x, w.end.y)
		var b := Vector2(x + 64, w.end.y)
		var q := [iso(a, 16), iso(b, 16), iso(b, 44), iso(a, 44)]
		ci.draw_colored_polygon(PackedVector2Array(q), C_WINDOW_D)
		ci.draw_colored_polygon(PackedVector2Array([q[0] + Vector2(2, -2), q[1] + Vector2(-2, -2), q[2] + Vector2(-2, 2), q[3] + Vector2(2, 2)]), C_WINDOW)
		ci.draw_polyline(PackedVector2Array(q + [q[0]]), C_OUT, 1.0)
		ci.draw_line((q[0] + q[3]) / 2, (q[1] + q[2]) / 2, C_OUT, 1.0)
		x += 192.0


# ================================================================ camada dinâmica (objetos ordenados)

func _draw() -> void:
	var items: Array = []   # [chave_de_profundidade, Callable]
	for i in desks.size():
		var d: Dictionary = desks[i]
		var c: Vector2 = d.center
		var alert := ticket_desks.has(i)
		if d.server:
			items.append([c.x + c.y, _draw_sprite.bind("rack_alert" if alert else "rack", c)])
		else:
			items.append([c.x + c.y - 60, _draw_worker.bind(c, d.look)])
			items.append([c.x + c.y, _draw_sprite.bind("desk_alert" if alert else "desk", c)])
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


func _draw_sprite(key: String, world: Vector2) -> void:
	draw_texture(TEX[key], iso(world) - ANCHOR[key])


func _draw_chair(c: Vector2) -> void:
	draw_texture(TEX_CHAIR, iso(c + Vector2(24, -52)) - Vector2(11, 25))


func _draw_worker(c: Vector2, look: int) -> void:
	_draw_chair(c)
	var pos := iso(c + Vector2(24, -44)) - Vector2(10, 30)
	draw_texture_rect_region(TEX_EMPLOYEES, Rect2(pos, Vector2(20, 24)), Rect2(look * 20, 0, 20, 24))


func _draw_player() -> void:
	var base := iso(player.position)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-7, 0), base + Vector2(0, -3), base + Vector2(7, 0), base + Vector2(0, 3)]), Color(0, 0, 0, 0.3))
	var frame := player_frame + (4 if player_back else 0)
	var src := Rect2(frame * 20, 0, 20, 34)
	var dst := Rect2(base - Vector2(10, 33), Vector2(20, 34))
	if player_flip:
		# espelha em torno do eixo vertical do personagem
		draw_set_transform(Vector2(base.x * 2.0, 0), 0.0, Vector2(-1, 1))
	draw_texture_rect_region(TEX_TECH, dst, src)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_alert(i: int) -> void:
	var d: Dictionary = desks[i]
	var info: Dictionary = ticket_desks[i]
	var key := "alert_urgent" if info.urgency > 0.7 else ("alert_high" if info.priority else "alert")
	var bob := roundf(sin(_time * 5.0 + i) * 2.0)
	var h := 66.0 if d.server else 52.0
	var p := iso(d.center, h) + Vector2(0, bob)
	draw_texture(TEX[key], p - ANCHOR[key])
	var left := 1.0 - float(info.urgency)
	draw_rect(Rect2(p + Vector2(-6, 3), Vector2(12, 2)), C_OUT)
	draw_rect(Rect2(p + Vector2(-6, 3), Vector2(roundf(12 * left), 2)),
		Color("63c74d") if left > 0.5 else (Color("feae34") if left > 0.25 else Color("e43b44")))
