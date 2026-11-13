extends Node
## Cena principal: liga o andar, o técnico, a fila de chamados, o HUD e os minijogos.

const SAVE_PATH := "user://chamado_aberto.cfg"

enum State { TITLE, PLAYING, TASK, PAUSED, DAY_END, GAME_OVER }

var tickets: TicketSystem
var state: State = State.TITLE
var best_score := 0

var _task: TaskBase
var _task_ticket_id := -1
var _task_mistakes := 0
var _rows := {}              # ticket id -> {panel, bar, label}
var _near_desk := -1

@onready var _map: OfficeMap = %OfficeMap
@onready var _player: Player = %Player
@onready var _guide: Guide = %Guide
@onready var _camera: Camera2D = %Camera2D
@onready var _world_view: SubViewportContainer = %WorldView
@onready var _room_labels: Control = %RoomLabels

const VIEW_SCALE := 2.0          # o mundo (640x360) é ampliado 2x
var _cam_bounds: Rect2
var _cam_f := Vector2.ZERO       # posição da câmera sem arredondar (em pixels do mundo)
var _plaques: Array = []         # [{node, world}]
@onready var _clock: Label = %ClockLabel
@onready var _day: Label = %DayLabel
@onready var _score: Label = %ScoreLabel
@onready var _satisfaction: ProgressBar = %SatisfactionBar
@onready var _ticket_list: VBoxContainer = %TicketList
@onready var _empty_label: Label = %EmptyLabel
@onready var _prompt_panel: PanelContainer = %PromptPanel
@onready var _prompt: Label = %PromptLabel
@onready var _minimap: Minimap = %Minimap
@onready var _toast: Label = %Toast
@onready var _task_layer: CanvasLayer = %TaskLayer
@onready var _ticket_header: Label = %TicketHeader
@onready var _ticket_quote: Label = %TicketQuote
@onready var _task_title: Label = %TaskTitle
@onready var _task_explain: Label = %TaskExplain
@onready var _task_holder: VBoxContainer = %TaskHolder
@onready var _task_feedback: Label = %TaskFeedback
@onready var _overlay: CanvasLayer = %Overlay
@onready var _overlay_text: RichTextLabel = %OverlayText
@onready var _overlay_button: Button = %OverlayButton


func _ready() -> void:
	# processa DEPOIS do técnico: a câmera usa a posição já atualizada neste quadro
	process_priority = 100
	_player.map = _map
	_map.player = _player
	_cam_bounds = _map.iso_bounds()
	_build_plaques()
	_guide.player = _player
	_minimap.map = _map
	_minimap.player = _player
	_overlay_button.pressed.connect(_on_overlay_action)
	_load_best()
	_new_game()
	_show_title()


# ================================================================ jogo

func _new_game() -> void:
	tickets = TicketSystem.new(_map.desks)
	tickets.ticket_opened.connect(_on_ticket_opened)
	tickets.ticket_expired.connect(_on_ticket_expired)
	tickets.day_ended.connect(_on_day_ended)
	tickets.game_over.connect(_on_game_over)
	tickets.start_day(1)
	_player.position = OfficeMap.START
	_player.facing = Vector2.DOWN
	_close_task()
	_rebuild_ticket_list()


func _process(delta: float) -> void:
	if state == State.PLAYING or state == State.TASK:
		tickets.update(delta)
	_player.can_move = state == State.PLAYING
	_update_camera()
	_sync_world()
	_refresh_hud()


## Câmera sem tremer: travada no pixel exato do técnico (sem suavização nem frações).
## Com a velocidade calibrada em player.gd, o cenário rola 2 px/quadro na horizontal e
## 1 px/quadro na vertical, sempre inteiro, e o técnico fica parado no centro.
func _update_camera() -> void:
	var r := OfficeMap.iso(_player.position, 18)
	var half := Vector2(320, 180)
	r.x = clampf(r.x, _cam_bounds.position.x + half.x, maxf(_cam_bounds.position.x + half.x, _cam_bounds.end.x - half.x))
	r.y = clampf(r.y, _cam_bounds.position.y + half.y, maxf(_cam_bounds.position.y + half.y, _cam_bounds.end.y - half.y))
	r = r.round()
	_cam_f = r
	_camera.position = r
	# placas das salas acompanham o mundo na resolução cheia
	var center := get_viewport().get_visible_rect().size / 2.0
	for p in _plaques:
		var node: Control = p.node
		node.position = ((OfficeMap.iso_f(p.world, 30) - r) * VIEW_SCALE + center - node.size / 2.0).round()


func _build_plaques() -> void:
	var colors := {"diretoria": Color("b55088"), "financeiro": Color("3e8948"), "rh": Color("e4a672"),
		"suporte": Color("0099db"), "marketing": Color("e43b44"), "servidores": Color("8b9bb4")}
	for room in _map.rooms:
		var r: Rect2 = room.rect
		var top_row: bool = r.position.y < _map.hall.position.y
		# placa logo acima da porta, do lado de dentro da sala
		var world := Vector2(r.get_center().x, r.end.y - 40 if top_row else r.position.y + 40)
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("181425")
		style.border_color = colors[room.floor]
		style.set_border_width_all(3)
		style.set_content_margin_all(5)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.shadow_color = Color(0, 0, 0, 0.5)
		style.shadow_offset = Vector2(3, 3)
		panel.add_theme_stylebox_override("panel", style)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := Label.new()
		label.text = room.name
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color.WHITE)
		panel.add_child(label)
		_room_labels.add_child(panel)
		_plaques.append({"node": panel, "world": world})


func _sync_world() -> void:
	var td := {}
	for t in tickets.tickets:
		td[t.desk] = {"priority": t.priority, "urgency": clampf(1.0 - t.sla_left / t.sla_total, 0.0, 1.0)}
	_map.ticket_desks = td
	_minimap.tickets = tickets.tickets
	var urgent := tickets.most_urgent()
	_guide.target = _map.desks[urgent.desk].pos if not urgent.is_empty() and state == State.PLAYING else Vector2.INF
	_near_desk = _map.desk_index_near(_player.position)


func _refresh_hud() -> void:
	_clock.text = tickets.clock_text()
	_day.text = "Dia %d" % tickets.day
	_score.text = str(tickets.score)
	_satisfaction.value = tickets.satisfaction / 100.0
	var sat_color := Color("5cff8a") if tickets.satisfaction > 60 else (Color("ffd23f") if tickets.satisfaction > 30 else Color("ff5a5a"))
	_set_fill(_satisfaction, sat_color)

	# lista de chamados: reconstrói se o conjunto mudou, senão só atualiza
	var ids := tickets.tickets.map(func(t): return t.id)
	if ids != _rows.keys():
		_rebuild_ticket_list()
	for t in tickets.tickets:
		var r: Dictionary = _rows[t.id]
		var ratio := clampf(t.sla_left / t.sla_total, 0.0, 1.0)
		r.bar.value = ratio
		_set_fill(r.bar, Color("5cff8a") if ratio > 0.5 else (Color("ffd23f") if ratio > 0.25 else Color("ff5a5a")))
		r.time.text = "%ds" % ceili(t.sla_left)

	# dica de interação
	var show_prompt := false
	if state == State.PLAYING and _near_desk >= 0:
		var t := tickets.ticket_at_desk(_near_desk)
		var d: Dictionary = _map.desks[_near_desk]
		if not t.is_empty():
			_prompt.text = "[E] Atender chamado #%d · %s (%s)" % [t.id, d.employee, d.dept]
			show_prompt = true
		elif not d.server:
			_prompt.text = "%s (%s): \"Tudo certo por aqui!\"" % [d.employee, d.dept]
			show_prompt = true
	_prompt_panel.visible = show_prompt


func _rebuild_ticket_list() -> void:
	for c in _ticket_list.get_children():
		c.queue_free()
	_rows.clear()
	_empty_label.visible = tickets.tickets.is_empty()
	for t in tickets.tickets:
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.07, 0.15, 0.7)
		style.set_content_margin_all(6)
		style.set_corner_radius_all(4)
		panel.add_theme_stylebox_override("panel", style)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		panel.add_child(v)
		var top := HBoxContainer.new()
		v.add_child(top)
		var head := Label.new()
		head.text = "#%d %s%s" % [t.id, "[ALTA] " if t.priority else "", t.dept]
		head.add_theme_color_override("font_color", Color("ff4fa3") if t.priority else Color("34e7e4"))
		head.add_theme_font_size_override("font_size", 12)
		head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(head)
		var time := Label.new()
		time.add_theme_font_size_override("font_size", 12)
		top.add_child(time)
		var body := Label.new()
		body.text = "%s: %s" % [t.employee, t.title]
		body.add_theme_font_size_override("font_size", 11)
		body.add_theme_color_override("font_color", Color("b5c0e8"))
		body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		body.clip_text = true
		body.custom_minimum_size = Vector2(250, 0)
		v.add_child(body)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.step = 0.0
		bar.custom_minimum_size = Vector2(0, 4)
		v.add_child(bar)
		_ticket_list.add_child(panel)
		_rows[t.id] = {"bar": bar, "time": time}


func _set_fill(bar: ProgressBar, color: Color) -> void:
	var s := bar.get_theme_stylebox("fill") as StyleBoxFlat
	if s and s.bg_color != color:
		var n := s.duplicate() as StyleBoxFlat
		n.bg_color = color
		bar.add_theme_stylebox_override("fill", n)


# ================================================================ entrada

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var k := key.keycode
	match state:
		State.TITLE, State.DAY_END, State.GAME_OVER, State.PAUSED:
			if k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] or (state == State.PAUSED and k in [KEY_P, KEY_ESCAPE]):
				_on_overlay_action()
		State.TASK:
			if k == KEY_ESCAPE:
				_cancel_task()
			elif _task:
				_task.handle_key(k)
		State.PLAYING:
			if k in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
				_interact()
			elif k in [KEY_P, KEY_ESCAPE]:
				_show_pause()
			else:
				return
	get_viewport().set_input_as_handled()


func _interact() -> void:
	if _near_desk < 0:
		return
	var t := tickets.ticket_at_desk(_near_desk)
	if not t.is_empty():
		_open_task(t)


# ================================================================ minijogos

func _open_task(t: Dictionary) -> void:
	var script: GDScript = load(TicketSystem.TYPES[t.kind].task)
	_task = script.new()
	_task.set_meta("employee", t.employee)
	_task_ticket_id = t.id
	_task_mistakes = 0
	_task.feedback.connect(_on_task_feedback)
	_task.mistake.connect(_on_task_mistake)
	_task.solved.connect(_on_task_solved)
	_task_holder.add_child(_task)
	_ticket_header.text = "Chamado #%d · %s · %s%s" % [t.id, t.dept, t.employee, "  [PRIORIDADE ALTA]" if t.priority else ""]
	_ticket_quote.text = "\"%s\"" % t.title
	_task_title.text = _task.task_title
	_task_explain.text = _task.explain
	_task_feedback.text = ""
	tickets.begin(t.id)
	state = State.TASK
	_task_layer.visible = true


func _on_task_feedback(text: String, kind: String) -> void:
	_task_feedback.text = text
	var colors := {"good": Color("5cff8a"), "bad": Color("ff5a5a"), "ask": Color("ffd23f")}
	_task_feedback.add_theme_color_override("font_color", colors.get(kind, Color.WHITE))


func _on_task_mistake() -> void:
	_task_mistakes += 1
	tickets.register_mistake()


func _on_task_solved(summary: String) -> void:
	_task_feedback.text = "RESOLVIDO! " + summary
	_task_feedback.add_theme_color_override("font_color", Color("5cff8a"))
	var id := _task_ticket_id
	await get_tree().create_timer(1.8).timeout
	if state != State.TASK or _task_ticket_id != id:
		return
	var pts := tickets.resolve(id, _task_mistakes)
	_close_task()
	state = State.PLAYING
	_show_toast("Chamado #%d resolvido! +%d pontos" % [id, pts], Color("5cff8a"))


func _cancel_task() -> void:
	tickets.cancel()
	_close_task()
	state = State.PLAYING
	_show_toast("Chamado continua aberto: o prazo voltou a correr.", Color("ffd23f"))


func _close_task() -> void:
	if _task:
		_task.queue_free()
		_task = null
	_task_ticket_id = -1
	_task_layer.visible = false


# ================================================================ eventos da fila

func _on_ticket_opened(t: Dictionary) -> void:
	_show_toast("Novo chamado #%d · %s (%s)" % [t.id, t.employee, t.dept],
		Color("ff4fa3") if t.priority else Color("34e7e4"))


func _on_ticket_expired(t: Dictionary) -> void:
	_show_toast("SLA estourado! Chamado #%d de %s foi escalado ao gerente." % [t.id, t.employee], Color("ff5a5a"))


func _on_day_ended() -> void:
	state = State.DAY_END
	_save_best_if_needed()
	var grade := _grade(tickets.day_resolved, tickets.day_expired)
	_overlay_text.text = """[color=#34e7e4][font_size=28]18:00 — FIM DO EXPEDIENTE[/font_size][/color]
[color=#8592c4]Dia %d concluído.[/color]

[table=2]
[cell]Chamados resolvidos hoje   [/cell][cell][color=#5cff8a]%d[/color][/cell]
[cell]Chamados com SLA estourado[/cell][cell][color=#ff5a5a]%d[/color][/cell]
[cell]Ainda abertos[/cell][cell]%d[/cell]
[cell]Satisfação dos usuários[/cell][cell]%d%%[/cell]
[cell]Pontuação total[/cell][cell][color=#ffd23f]%d[/color][/cell]
[/table]

Avaliação do dia: [color=#ffd23f][font_size=24]%s[/font_size][/color]

[color=#8592c4]Amanhã os chamados chegam mais rápido e com prazos menores.[/color]""" % [
		tickets.day, tickets.day_resolved, tickets.day_expired, tickets.tickets.size(),
		int(tickets.satisfaction), tickets.score, grade]
	_overlay_button.text = "[Enter] Começar o dia %d" % (tickets.day + 1)
	_overlay.visible = true


func _on_game_over() -> void:
	state = State.GAME_OVER
	_close_task()
	var record := _save_best_if_needed()
	_overlay_text.text = """[color=#ff5a5a][font_size=28]CHAMADO NA SALA DO GERENTE[/font_size][/color]
A satisfação dos usuários chegou a zero. O gerente quer "conversar sobre o suporte".
%s
[table=2]
[cell]Dias trabalhados   [/cell][cell]%d[/cell]
[cell]Chamados resolvidos[/cell][cell][color=#5cff8a]%d[/color][/cell]
[cell]SLAs estourados[/cell][cell][color=#ff5a5a]%d[/color][/cell]
[cell]Erros nos atendimentos[/cell][cell]%d[/cell]
[cell]Pontuação[/cell][cell][color=#ffd23f]%d[/color][/cell]
[cell]Recorde[/cell][cell][color=#ffd23f]%d[/color][/cell]
[/table]""" % ["\n[color=#ffd23f]*** NOVO RECORDE! ***[/color]\n" if record else "",
		tickets.day, tickets.resolved, tickets.expired, tickets.mistakes, tickets.score, best_score]
	_overlay_button.text = "[Enter] Recomeçar"
	_overlay.visible = true


func _grade(resolved_n: int, expired_n: int) -> String:
	if expired_n == 0 and resolved_n >= 8:
		return "S — técnico do mês!"
	if expired_n <= 1:
		return "A — ótimo atendimento"
	if expired_n <= 3:
		return "B — dá para melhorar"
	return "C — a fila venceu hoje"


# ================================================================ overlays

func _show_title() -> void:
	state = State.TITLE
	_overlay_text.text = """[color=#34e7e4][font_size=30]CHAMADO ABERTO[/font_size][/color]
[color=#8592c4]Você é o técnico de TI do 7º andar. O telefone não para.[/color]

[color=#ffd23f]Como jogar[/color]
• Ande com [b]WASD[/b] ou as [b]setas[/b]. A seta amarela aponta o chamado mais urgente.
• Chegue na mesa com [b]![/b] e aperte [b]E[/b] para atender.
• Resolva o problema com as teclas [b]1–9[/b] e [b]Enter[/b] (o mouse também funciona).
• [b]Esc[/b] sai do atendimento sem resolver; [b]P[/b] pausa.

[color=#ffd23f]Prazos (SLA)[/color]
Cada chamado tem um prazo. Se estourar, a satisfação cai. Chamados da [color=#ff4fa3]Diretoria[/color] têm prioridade alta: prazo menor, mais pontos.
Enquanto você atende um chamado, o prazo [b]dele[/b] para, mas o dos outros continua correndo!

[color=#8592c4]Problemas do dia a dia do suporte: internet, impressora, senha, PC lento, e-mail suspeito e cabos.[/color]"""
	_overlay_button.text = "[Enter] Bater o ponto (09:00)"
	_overlay.visible = true


func _show_pause() -> void:
	state = State.PAUSED
	_overlay_text.text = "[color=#34e7e4][font_size=28]PAUSA PARA O CAFÉ[/font_size][/color]\n\nO relógio parou. Aperte [b]P[/b], [b]Esc[/b] ou [b]Enter[/b] para voltar."
	_overlay_button.text = "[Enter] Voltar ao trabalho"
	_overlay.visible = true


func _on_overlay_action() -> void:
	match state:
		State.TITLE, State.PAUSED:
			state = State.PLAYING
		State.DAY_END:
			tickets.start_day(tickets.day + 1)
			_player.position = OfficeMap.START
			state = State.PLAYING
			_show_toast("Dia %d · 09:00 · bom trabalho!" % tickets.day, Color("34e7e4"))
		State.GAME_OVER:
			_new_game()
			state = State.PLAYING
	_overlay.visible = false


func _show_toast(text: String, color: Color) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)


func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_score = int(cfg.get_value("score", "best", 0))


func _save_best_if_needed() -> bool:
	if tickets.score <= best_score:
		return false
	best_score = tickets.score
	var cfg := ConfigFile.new()
	cfg.set_value("score", "best", best_score)
	cfg.save(SAVE_PATH)
	return true
