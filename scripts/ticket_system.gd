class_name TicketSystem
extends RefCounted
## Fila de chamados, relógio do expediente, SLA e satisfação. Sem UI (testável).

signal ticket_opened(ticket: Dictionary)
signal ticket_expired(ticket: Dictionary)
signal ticket_resolved(ticket: Dictionary, points: int)
signal day_ended
signal game_over

const DAY_START := 9 * 60          # 09:00 em minutos
const DAY_END := 18 * 60           # 18:00
const DAY_SECONDS := 300.0         # duração real de um expediente
const MAX_OPEN := 6

## Tipos de chamado → script do minijogo e frases dos usuários (e dos alertas de servidor).
const TYPES := {
	"hardware": {"task": "res://scripts/tasks/task_hardware.gd", "titles": [
		"Meu PC não liga direito", "O computador está apitando", "A tela fica preta e não aparece nada"],
		"server_titles": ["Alerta: servidor desligou sozinho", "Alerta: servidor reiniciando sem parar"]},
	"printer": {"task": "res://scripts/tasks/task_printer.gd", "titles": [
		"A impressora não imprime", "Mandei imprimir e nada saiu", "A impressora está piscando uma luz laranja"]},
	"password": {"task": "res://scripts/tasks/task_password.gd", "titles": [
		"Esqueci minha senha", "Minha conta foi bloqueada", "Minha senha expirou e não consigo trocar"]},
	"slow": {"task": "res://scripts/tasks/task_taskmgr.gd", "titles": [
		"Meu computador está muito lento", "O PC trava toda hora", "O ventilador do PC não para de fazer barulho"],
		"server_titles": ["Alerta: CPU do servidor em 100%", "Alerta: servidor respondendo muito devagar"]},
	"phishing": {"task": "res://scripts/tasks/task_phishing.gd", "titles": [
		"Recebi uns e-mails estranhos", "Acho que caí num golpe por e-mail", "Pediram minha senha por e-mail, é normal?"]},
	"cables": {"task": "res://scripts/tasks/task_cables.gd", "titles": [
		"Mudei de mesa e nada funciona", "Meu PC novo chegou, pode instalar?", "O monitor e o teclado não ligam"]},
}

var rng := RandomNumberGenerator.new()
var desks: Array = []              # [{dept, employee, kinds: Array[String], priority: bool}]
var day := 1
var clock := float(DAY_START)
var satisfaction := 100.0
var score := 0
var resolved := 0
var expired := 0
var mistakes := 0
var tickets: Array[Dictionary] = []
var next_id := 1
var spawn_timer := 3.0
var active_id := -1                # chamado sendo atendido (o SLA dele pausa)
var is_over := false
var day_finished := false
# estatísticas do dia
var day_resolved := 0
var day_expired := 0


func _init(desk_list: Array, seed_value: int = -1) -> void:
	desks = desk_list
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


func start_day(n: int) -> void:
	day = n
	clock = DAY_START
	tickets.clear()
	spawn_timer = 3.0
	active_id = -1
	day_finished = false
	day_resolved = 0
	day_expired = 0


func spawn_interval() -> float:
	return maxf(7.0, 20.0 - 4.0 * (day - 1)) * rng.randf_range(0.7, 1.3)


func sla_for(priority: bool) -> float:
	var base := maxf(45.0, 95.0 - 10.0 * (day - 1))
	return base * (0.65 if priority else 1.0)


func clock_text() -> String:
	var m := int(clock)
	return "%02d:%02d" % [m / 60, m % 60]


func update(delta: float) -> void:
	if is_over or day_finished:
		return
	clock += delta * (DAY_END - DAY_START) / DAY_SECONDS
	spawn_timer -= delta
	if spawn_timer <= 0.0 and clock < DAY_END - 20:
		spawn()
		spawn_timer = spawn_interval()
	for t in tickets.duplicate():
		if t.id == active_id:
			continue
		t.sla_left -= delta
		if t.sla_left <= 0.0:
			tickets.erase(t)
			expired += 1
			day_expired += 1
			satisfaction -= 12.0 if t.priority else 8.0
			ticket_expired.emit(t)
	satisfaction = clampf(satisfaction, 0.0, 100.0)
	if satisfaction <= 0.0:
		is_over = true
		game_over.emit()
		return
	if clock >= DAY_END and active_id == -1:
		day_finished = true
		# chamados ainda abertos no fim do dia pesam na avaliação
		satisfaction = maxf(0.0, satisfaction - 3.0 * tickets.size())
		day_ended.emit()


## Abre um chamado numa mesa livre. Retorna o chamado ou {} se não houver vaga.
func spawn() -> Dictionary:
	if tickets.size() >= MAX_OPEN:
		return {}
	var busy := tickets.map(func(t): return t.desk)
	var free: Array = []
	for i in desks.size():
		if not busy.has(i):
			free.append(i)
	if free.is_empty():
		return {}
	var d: int = free[rng.randi() % free.size()]
	var desk: Dictionary = desks[d]
	var kind: String = desk.kinds[rng.randi() % desk.kinds.size()]
	var titles: Array = TYPES[kind].server_titles if desk.get("server", false) and TYPES[kind].has("server_titles") else TYPES[kind].titles
	var t := {
		"id": next_id, "desk": d, "kind": kind, "dept": desk.dept, "employee": desk.employee,
		"title": titles[rng.randi() % titles.size()], "priority": desk.priority,
		"sla_total": sla_for(desk.priority), "sla_left": sla_for(desk.priority),
	}
	next_id += 1
	tickets.append(t)
	ticket_opened.emit(t)
	return t


func ticket_at_desk(desk_index: int) -> Dictionary:
	for t in tickets:
		if t.desk == desk_index:
			return t
	return {}


func get_ticket(id: int) -> Dictionary:
	for t in tickets:
		if t.id == id:
			return t
	return {}


## Chamado mais urgente (menor SLA restante).
func most_urgent() -> Dictionary:
	var best := {}
	for t in tickets:
		if best.is_empty() or t.sla_left < best.sla_left:
			best = t
	return best


func begin(id: int) -> void:
	active_id = id


func cancel() -> void:
	active_id = -1


func register_mistake() -> void:
	mistakes += 1
	satisfaction = maxf(0.0, satisfaction - 1.0)


func resolve(id: int, task_mistakes: int) -> int:
	var t := get_ticket(id)
	active_id = -1
	if t.is_empty():
		return 0
	tickets.erase(t)
	resolved += 1
	day_resolved += 1
	var pts := 100 + int(t.sla_left) * 2 + (100 if t.priority else 0) - task_mistakes * 20
	pts = maxi(30, pts)
	score += pts
	satisfaction = minf(100.0, satisfaction + 4.0)
	ticket_resolved.emit(t, pts)
	return pts
