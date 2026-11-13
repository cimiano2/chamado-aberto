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
# pontuação competitiva
var combo := 0                     # chamados seguidos resolvidos sem erro
var best_combo := 0
var history: Array[Dictionary] = []    # um registro por chamado (vai para o relatório)
var stats := {}                    # tipo -> {resolved, clean, mistakes, expired}
var play_seconds := 0.0
var _work := {}                    # id -> segundos gastos atendendo


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
	play_seconds += delta
	if active_id >= 0:
		_work[active_id] = _work.get(active_id, 0.0) + delta
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
			score = maxi(0, score - 50)
			combo = 0
			_stat(t.kind).expired += 1
			_log(t, "estourado", 0, -50)
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
	combo = 0
	satisfaction = maxf(0.0, satisfaction - 1.0)


func resolve(id: int, task_mistakes: int) -> int:
	var t := get_ticket(id)
	active_id = -1
	if t.is_empty():
		return 0
	tickets.erase(t)
	resolved += 1
	day_resolved += 1
	var pts := points_for(t, task_mistakes)
	if task_mistakes == 0:
		combo += 1
		best_combo = maxi(best_combo, combo)
	score += pts
	satisfaction = minf(100.0, satisfaction + 4.0)
	var st := _stat(t.kind)
	st.resolved += 1
	st.mistakes += task_mistakes
	if task_mistakes == 0:
		st.clean += 1
	_log(t, "resolvido", task_mistakes, pts)
	ticket_resolved.emit(t, pts)
	return pts


## Pontos: base 100 + rapidez (até 100) + prioridade (50) − 25 por erro, × sequência sem erros.
func points_for(t: Dictionary, task_mistakes: int) -> int:
	var speed := int(round(100.0 * clampf(t.sla_left / t.sla_total, 0.0, 1.0)))
	var base := 100 + speed + (50 if t.priority else 0) - 25 * task_mistakes
	var mult := multiplier_after(task_mistakes)
	return maxi(20, int(round(base * mult)))


## Multiplicador da sequência que vale para o chamado que está sendo fechado.
func multiplier_after(task_mistakes: int) -> float:
	if task_mistakes > 0:
		return 1.0
	return 1.0 + 0.1 * mini(combo, 5)


## Nota de 0 a 10: 40% resolução, 40% precisão, 20% agilidade.
func grade() -> Dictionary:
	var finished := resolved + expired + (tickets.size() if day_finished else 0)
	var resolution := float(resolved) / finished if finished > 0 else 0.0
	var clean := 0
	var speed_sum := 0.0
	var speed_n := 0
	for e in history:
		if e.result == "resolvido":
			if e.mistakes == 0:
				clean += 1
			speed_sum += e.sla_ratio
			speed_n += 1
	var accuracy := float(clean) / resolved if resolved > 0 else 0.0
	var agility := speed_sum / speed_n if speed_n > 0 else 0.0
	var nota := 10.0 * (0.4 * resolution + 0.4 * accuracy + 0.2 * agility)
	return {"nota": snappedf(nota, 0.1), "resolution": resolution, "accuracy": accuracy, "agility": agility}


func _stat(kind: String) -> Dictionary:
	if not stats.has(kind):
		stats[kind] = {"resolved": 0, "clean": 0, "mistakes": 0, "expired": 0}
	return stats[kind]


func _log(t: Dictionary, result: String, task_mistakes: int, pts: int) -> void:
	history.append({"id": t.id, "day": day, "clock": clock_text(), "kind": t.kind, "dept": t.dept,
		"employee": t.employee, "title": t.title, "result": result, "mistakes": task_mistakes,
		"work_s": snappedf(_work.get(t.id, 0.0), 0.1), "sla_ratio": clampf(t.sla_left / t.sla_total, 0.0, 1.0),
		"points": pts})


## Estado acumulado (para salvar a sessão no início de cada dia).
func to_dict() -> Dictionary:
	return {"day": day, "satisfaction": satisfaction, "score": score, "resolved": resolved,
		"expired": expired, "mistakes": mistakes, "next_id": next_id, "best_combo": best_combo,
		"history": history, "stats": stats, "play_seconds": play_seconds}


func from_dict(d: Dictionary) -> void:
	day = int(d.get("day", 1))
	satisfaction = float(d.get("satisfaction", 100.0))
	score = int(d.get("score", 0))
	resolved = int(d.get("resolved", 0))
	expired = int(d.get("expired", 0))
	mistakes = int(d.get("mistakes", 0))
	next_id = int(d.get("next_id", 1))
	best_combo = int(d.get("best_combo", 0))
	play_seconds = float(d.get("play_seconds", 0.0))
	history.assign(d.get("history", []))
	stats = d.get("stats", {})
