class_name OfficeMap
extends Node2D
## Andar da empresa: salas, corredor, portas, mesas e funcionários.
## Desenhado em código; também responde se uma posição é caminhável.

const WALL := 18.0
const FLOOR_HALL := Color("2a2f45")
const WALL_COLOR := Color("0f1222")
const WALL_EDGE := Color("4a5585")
const DESK_COLOR := Color("6b5640")
const DESK_TOP := Color("8a7052")

## Salas: nome, retângulo, cor do piso, tipos de chamado, prioridade (diretoria).
var rooms: Array[Dictionary] = [
	{"name": "DIRETORIA", "rect": Rect2(40, 40, 780, 480), "floor": Color("3a2f40"), "kinds": ["cpu", "chmod", "alloc", "paging"], "priority": true},
	{"name": "FINANCEIRO", "rect": Rect2(880, 40, 780, 480), "floor": Color("2c3a36"), "kinds": ["chmod", "deadlock", "cpu", "alloc"], "priority": false},
	{"name": "RH", "rect": Rect2(1720, 40, 780, 480), "floor": Color("3a3530"), "kinds": ["chmod", "cpu", "paging", "alloc"], "priority": false},
	{"name": "SUPORTE TI", "rect": Rect2(40, 840, 780, 480), "floor": Color("23304a"), "kinds": [], "priority": false},
	{"name": "MARKETING", "rect": Rect2(880, 840, 780, 480), "floor": Color("3a2a3a"), "kinds": ["alloc", "paging", "cpu", "chmod"], "priority": false},
	{"name": "SERVIDORES", "rect": Rect2(1720, 840, 780, 480), "floor": Color("1d2a33"), "kinds": ["disk", "deadlock", "paging", "disk"], "priority": false},
]
var hall := Rect2(40, 600, 2460, 160)
var doors: Array[Rect2] = []
var floors: Array[Rect2] = []
var obstacles: Array[Rect2] = []
## Mesas com possibilidade de chamado: {pos, rect, dept, employee, kinds, priority, look, server}
var desks: Array[Dictionary] = []
var world_rect := Rect2(0, 0, 2540, 1360)

var ticket_desks := {}    # desk index -> {priority: bool, urgency: 0..1}
var _time := 0.0

const DEPT_NAMES := {"DIRETORIA": "Diretoria", "FINANCEIRO": "Financeiro", "RH": "RH",
	"SUPORTE TI": "Suporte TI", "MARKETING": "Marketing", "SERVIDORES": "Servidores"}
const FIRST_NAMES := ["Ana", "Bruno", "Carla", "Diego", "Elisa", "Fábio", "Gabi", "Heitor", "Iara",
	"João", "Kátia", "Leo", "Marina", "Nina", "Otávio", "Paula", "Rafa", "Sofia", "Tiago", "Vera"]
const SKIN := [Color("f1c9a5"), Color("e0ac69"), Color("c68642"), Color("8d5524"), Color("ffdbac")]
const HAIR := [Color("2b1b10"), Color("5a3825"), Color("1a1a1a"), Color("b5651d"), Color("d6c27a"), Color("7a7a7a")]
const SHIRT := [Color("e05a5a"), Color("5ab0e0"), Color("e0c95a"), Color("8fd16a"), Color("c07ae0"), Color("e08f5a"), Color("d9d9d9")]


func _ready() -> void:
	build()


func build() -> void:
	doors.clear()
	floors.clear()
	obstacles.clear()
	desks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024   # layout fixo; só os chamados variam
	var names := FIRST_NAMES.duplicate()
	OSLogic._shuffle(names, rng)
	for room in rooms:
		var r: Rect2 = room.rect
		var top_row: bool = r.position.y < hall.position.y
		var door := Rect2(r.get_center().x - 70, r.end.y if top_row else hall.end.y, 140,
			hall.position.y - r.end.y if top_row else r.position.y - hall.end.y)
		doors.append(door)
		floors.append(r)
		# 4 postos de trabalho por sala (2 x 2)
		for k in 4:
			var cx := r.position.x + (230.0 if k % 2 == 0 else 550.0)
			var cy := r.position.y + (150.0 if k < 2 else 330.0)
			if not top_row:
				cy += 20.0
			var server: bool = room.name == "SERVIDORES"
			var rect := Rect2(cx - 80, cy - 30, 160, 60) if not server else Rect2(cx - 50, cy - 55, 100, 110)
			obstacles.append(rect)
			if room.kinds.is_empty():
				continue   # sala do suporte: mesas sem chamados
			desks.append({
				"pos": Vector2(cx, rect.end.y + 34), "rect": rect, "dept": DEPT_NAMES[room.name],
				"employee": "Servidor %s" % ["ARQ01", "BD01", "WEB01", "BKP01"][k] if server else names.pop_back(),
				"kinds": room.kinds, "priority": room.priority, "server": server,
				"look": {"skin": SKIN[rng.randi() % SKIN.size()], "hair": HAIR[rng.randi() % HAIR.size()],
					"shirt": SHIRT[rng.randi() % SHIRT.size()]},
			})
	floors.append(hall)
	floors.append_array(doors)
	# plantas no corredor
	for x in [300.0, 1270.0, 2240.0]:
		obstacles.append(Rect2(x - 22, hall.position.y + 4, 44, 36))


## Uma caixa (pés do personagem) está toda dentro do piso e fora dos móveis?
func is_walkable(box: Rect2) -> bool:
	for corner in [box.position, Vector2(box.end.x, box.position.y), Vector2(box.position.x, box.end.y), box.end]:
		var inside := false
		for f in floors:
			if f.has_point(corner):
				inside = true
				break
		if not inside:
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


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var theme_font: Font = ThemeDB.get_project_theme().default_font if ThemeDB.get_project_theme() else ThemeDB.fallback_font
	# paredes: retângulos maiores por baixo, piso por cima
	for f in floors:
		draw_rect(f.grow(WALL), WALL_COLOR)
	for f in floors:
		draw_rect(f.grow(WALL), WALL_EDGE, false, 2)
	for f in floors:
		draw_rect(f.grow(WALL - 4), WALL_COLOR)
	# piso
	_draw_tiles(hall, FLOOR_HALL, 80)
	for d in doors:
		draw_rect(d, FLOOR_HALL)
	for room in rooms:
		_draw_tiles(room.rect, room.floor, 60)
		var r: Rect2 = room.rect
		var top_row: bool = r.position.y < hall.position.y
		var label_pos := Vector2(r.position.x + 24, r.position.y + 44) if top_row else Vector2(r.position.x + 24, r.end.y - 24)
		draw_string(theme_font, label_pos, room.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 1, 1, 0.22))
	# faixa do corredor
	draw_string(theme_font, Vector2(hall.position.x + 900, hall.get_center().y + 10), "CORREDOR · ANDAR 7",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.08))
	# plantas
	for x in [300.0, 1270.0, 2240.0]:
		var c := Vector2(x, hall.position.y + 22)
		draw_circle(c + Vector2(0, 6), 20, Color("3d2b1f"))
		draw_circle(c, 18, Color("2f7a3b"))
		draw_circle(c + Vector2(-7, -5), 9, Color("3f9a4b"))
	# móveis da sala do suporte (sem chamados)
	var ti: Rect2 = rooms[3].rect
	for k in 4:
		var cx := ti.position.x + (230.0 if k % 2 == 0 else 550.0)
		var cy := ti.position.y + (170.0 if k < 2 else 350.0)
		_draw_desk(Rect2(cx - 80, cy - 30, 160, 60), false, {}, -1)
	draw_string(theme_font, ti.position + Vector2(260, 260), "base do suporte", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.18))
	# mesas com funcionários / servidores
	for i in desks.size():
		var d: Dictionary = desks[i]
		if d.server:
			_draw_rack(d.rect, i)
		else:
			_draw_desk(d.rect, true, d.look, i)
	# balões de chamado por cima de tudo
	for i in ticket_desks:
		_draw_alert(i)


func _draw_tiles(r: Rect2, base: Color, step: int) -> void:
	draw_rect(r, base)
	var line := base.lightened(0.06)
	var x := r.position.x
	while x < r.end.x:
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), line, 1)
		x += step
	var y := r.position.y
	while y < r.end.y:
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), line, 1)
		y += step


func _draw_desk(r: Rect2, with_person: bool, look: Dictionary, index: int) -> void:
	# cadeira e pessoa atrás da mesa
	if with_person:
		var p := Vector2(r.get_center().x, r.position.y - 16)
		draw_circle(p + Vector2(0, -2), 26, Color("1b1f33"))          # cadeira
		draw_rect(Rect2(p.x - 18, p.y - 8, 36, 26), look.shirt)          # tronco
		draw_circle(p + Vector2(0, -20), 13, look.skin)                  # cabeça
		draw_arc(p + Vector2(0, -22), 13, PI, TAU, 12, look.hair, 7)     # cabelo
	draw_rect(r, DESK_COLOR)
	draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y - 8)), DESK_TOP)
	# monitor
	var has_ticket := index >= 0 and ticket_desks.has(index)
	var mon := Rect2(r.get_center().x - 32, r.position.y + 6, 64, 30)
	draw_rect(mon.grow(3), Color("111111"))
	var blink := 0.5 + 0.5 * sin(_time * 8.0)
	var screen := Color("c0392b").lerp(Color("ff6b5a"), blink) if has_ticket else Color("2d6cdf")
	draw_rect(mon, screen)
	if has_ticket:
		draw_string(ThemeDB.fallback_font, mon.position + Vector2(26, 23), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	else:
		draw_line(mon.position + Vector2(8, 10), mon.position + Vector2(40, 10), Color(1, 1, 1, 0.5), 2)
		draw_line(mon.position + Vector2(8, 18), mon.position + Vector2(52, 18), Color(1, 1, 1, 0.3), 2)
	# teclado
	draw_rect(Rect2(r.get_center().x - 26, r.end.y - 20, 52, 8), Color("2a2a2a"))


func _draw_rack(r: Rect2, index: int) -> void:
	draw_rect(r, Color("16181f"))
	draw_rect(r, Color("3a4060"), false, 2)
	var has_ticket := ticket_desks.has(index)
	for k in 6:
		var y := r.position.y + 8 + k * 16
		draw_rect(Rect2(r.position.x + 8, y, r.size.x - 16, 10), Color("262a3a"))
		var on := fmod(_time * 3.0 + k * 0.7 + index, 1.0) > 0.4
		var led := (Color("ff3b3b") if has_ticket else Color("3bff7a")) if on else Color("203020")
		draw_circle(Vector2(r.end.x - 16, y + 5), 3, led)


func _draw_alert(i: int) -> void:
	var d: Dictionary = desks[i]
	var info: Dictionary = ticket_desks[i]
	var top := Vector2(d.rect.get_center().x, d.rect.position.y - (70 if not d.server else 30))
	var bob := sin(_time * 5.0 + i) * 5.0
	var c := top + Vector2(0, bob)
	var col := Color("ff4fa3") if info.priority else Color("ffd23f")
	var urgency: float = info.urgency
	if urgency > 0.7:
		col = Color("ff5a5a")
	draw_circle(c, 20, Color(0, 0, 0, 0.5))
	draw_circle(c, 17, col)
	draw_string(ThemeDB.fallback_font, c + Vector2(-5, 9), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("1a1a1a"))
	# anel de SLA restante
	draw_arc(c, 23, -PI / 2, -PI / 2 + TAU * (1.0 - urgency), 32, col, 4)
