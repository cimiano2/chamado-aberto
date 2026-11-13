extends Node
## Cena principal: menu, sessão salva, andar, técnico, fila de chamados, HUD, balões, sons,
## minijogos e relatório de desempenho.

enum State { TITLE, PLAYING, TASK, PAUSED, DAY_END, FINAL }

const VIEW_SCALE := 2.0          # o mundo (640x360) é ampliado 2x
const TECH_LINES := ["Deixa comigo!", "Bora resolver isso.", "Vamos ver o que houve...", "Já estou aqui!"]
const THANKS := ["Valeu! Salvou meu dia!", "Funcionou! Obrigado(a)!", "Ufa! Muito obrigado(a)!", "Você é o(a) melhor!"]
const ANGRY := ["Vou reclamar com o gerente!", "Ninguém veio me ajudar...", "Assim não dá!"]
const FINE := ["Tudo certo por aqui!", "Por enquanto tudo funcionando.", "Bom dia!", "Café está bom hoje."]

var tickets: TicketSystem
var state: State = State.TITLE
var profile := {"name": "", "class_code": "", "skin": 0, "hair": 0, "shirt": 0}
var mode := "treino"             # treino | avaliacao
var restarts := 0

var _task: TaskBase
var _task_ticket_id := -1
var _task_mistakes := 0
var _rows := {}
var _near_desk := -1
var _cam_bounds: Rect2
var _cam_f := Vector2.ZERO
var _plaques: Array = []
var _menu: Menu
var _menu_layer: CanvasLayer
var _audio: Audio
var _balloons: Balloons
var _name_tag: Label
var _combo_label: Label
var _overlay_button2: Button
var _chat_cooldown := {}         # mesa -> segundos até poder falar de novo
var _step_t := 0.0

@onready var _map: OfficeMap = %OfficeMap
@onready var _player: Player = %Player
@onready var _guide: Guide = %Guide
@onready var _camera: Camera2D = %Camera2D
@onready var _world_view: SubViewportContainer = %WorldView
@onready var _room_labels: Control = %RoomLabels
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
	_overlay_button2 = Button.new()
	_overlay_button2.focus_mode = Control.FOCUS_NONE
	_overlay_button2.pressed.connect(_on_overlay_secondary)
	_overlay_button.get_parent().add_child(_overlay_button2)
	_audio = Audio.new()
	add_child(_audio)
	_balloons = Balloons.new()
	_balloons.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_balloons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_balloons.to_screen = _to_screen
	_room_labels.get_parent().add_child(_balloons)
	_room_labels.get_parent().move_child(_balloons, _room_labels.get_index() + 1)
	_name_tag = Label.new()
	_name_tag.add_theme_font_size_override("font_size", 14)
	_name_tag.add_theme_color_override("font_outline_color", Color("181425"))
	_name_tag.add_theme_constant_override("outline_size", 5)
	_room_labels.add_child(_name_tag)
	_combo_label = Label.new()
	_combo_label.add_theme_font_size_override("font_size", 16)
	_combo_label.add_theme_color_override("font_color", Color("fee761"))
	_score.get_parent().add_child(_combo_label)
	_new_tickets(-1)
	_show_menu()


# ================================================================ sessão

func _new_tickets(seed_value: int) -> void:
	tickets = TicketSystem.new(_map.desks, seed_value)
	tickets.ticket_opened.connect(_on_ticket_opened)
	tickets.ticket_expired.connect(_on_ticket_expired)
	tickets.ticket_resolved.connect(_on_ticket_resolved)
	tickets.day_ended.connect(_on_day_ended)
	tickets.game_over.connect(_on_game_over)
	tickets.start_day(1)
	_close_task()
	_rebuild_ticket_list()


func _show_menu() -> void:
	state = State.TITLE
	_overlay.visible = false
	_room_labels.get_parent().visible = false     # HUD escondido enquanto o menu está aberto
	if _menu_layer:
		_menu_layer.queue_free()
	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = 5
	add_child(_menu_layer)
	_menu = Menu.new()
	_menu.audio = _audio
	_audio.changed.connect(_menu._refresh)
	_menu.start_requested.connect(start_session)
	_menu_layer.add_child(_menu)


## Começa (ou continua) uma sessão. Com código de turma, todos recebem os mesmos chamados.
func start_session(p: Dictionary, m: String, resume: bool) -> void:
	profile = p
	mode = m
	var saved := SaveGame.load_session() if resume else {}
	_new_tickets(_seed())
	if resume and saved.has("state"):
		tickets.from_dict(saved.state)
		restarts = int(saved.get("restarts", 0)) + 1
		mode = saved.get("mode", mode)
	else:
		restarts = 0
	_begin_day(tickets.day)
	_map.player_tex = Skins.texture(profile.skin, profile.hair, profile.shirt)
	_name_tag.text = profile.name
	_name_tag.add_theme_color_override("font_color", Skins.SHIRT[profile.shirt].c[0])
	if _menu_layer:
		_menu_layer.queue_free()
		_menu_layer = null
	_room_labels.get_parent().visible = true
	_audio.start_music()
	_audio.play("click")
	state = State.PLAYING
	var hello := "Bom dia, Papéis Horizonte! Hora de trabalhar." if not resume else "De volta ao trabalho!"
	_balloons.say(profile.name, hello, _player_head, Skins.SHIRT[profile.shirt].c[2])


func _seed() -> int:
	if profile.class_code == "":
		return -1
	return absi(("%s|%s" % [profile.class_code, mode]).hash())


func _begin_day(n: int) -> void:
	tickets.start_day(n)
	if profile.class_code != "":
		tickets.rng.seed = absi(("%s|%s|dia%d" % [profile.class_code, mode, n]).hash())
	_player.position = OfficeMap.START
	_player.facing = Vector2.DOWN
	_balloons.clear()
	_save_session(false)


func _save_session(finished: bool) -> void:
	SaveGame.save_session({"profile": profile, "mode": mode, "state": tickets.to_dict(),
		"restarts": restarts, "finished": finished})


# ================================================================ loop

func _process(delta: float) -> void:
	if state == State.PLAYING or state == State.TASK:
		tickets.update(delta)
		for k in _chat_cooldown.keys():
			_chat_cooldown[k] -= delta
	_player.can_move = state == State.PLAYING
	_update_camera()
	_sync_world()
	_refresh_hud()
	if _player.moving and state == State.PLAYING:
		_step_t -= delta
		if _step_t <= 0.0:
			_audio.play("step", -14.0)
			_step_t = 0.26


## Câmera sem tremer: travada no pixel exato do técnico (sem suavização nem frações).
func _update_camera() -> void:
	var r := OfficeMap.iso(_player.position, 18)
	var half := Vector2(320, 180)
	r.x = clampf(r.x, _cam_bounds.position.x + half.x, maxf(_cam_bounds.position.x + half.x, _cam_bounds.end.x - half.x))
	r.y = clampf(r.y, _cam_bounds.position.y + half.y, maxf(_cam_bounds.position.y + half.y, _cam_bounds.end.y - half.y))
	r = r.round()
	_cam_f = r
	_camera.position = r
	var me := Rect2(_to_screen(OfficeMap.iso_f(_player.position)) - Vector2(24, 76), Vector2(48, 82))
	for p in _plaques:
		var node: Control = p.node
		node.position = (_to_screen(OfficeMap.iso_f(p.world, 30)) - node.size / 2.0).round()
		# placa fica quase transparente quando o personagem passa por trás dela
		node.modulate.a = 0.25 if Rect2(node.position, node.size).intersects(me) else 1.0
	_name_tag.visible = state != State.TITLE
	_name_tag.position = (_to_screen(OfficeMap.iso_f(_player.position)) + Vector2(-_name_tag.size.x / 2.0, 6)).round()


## Ponto do canvas isométrico (640x360) → posição na tela cheia.
func _to_screen(p: Vector2) -> Vector2:
	return (p - _cam_f) * VIEW_SCALE + get_viewport().get_visible_rect().size / 2.0


func _player_head() -> Vector2:
	return OfficeMap.iso_f(_player.position, 36)


func _build_plaques() -> void:
	for room in _map.rooms:
		if not room.get("plaque", true):
			continue
		var r: Rect2 = room.rect
		var back_row: bool = r.position.y < 2 * OfficeMap.TILE
		var world := Vector2(r.get_center().x, r.end.y - 50 if back_row else r.position.y + 50)
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("181425")
		style.border_color = room.color
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
		label.add_theme_font_size_override("font_size", 16)
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
	var near := _map.desk_index_near(_player.position)
	if near != _near_desk and near >= 0 and state == State.PLAYING and _chat_cooldown.get(near, 0.0) <= 0.0:
		# quem está na mesa puxa conversa (como num chat de mundo isométrico)
		var t := tickets.ticket_at_desk(near)
		var d: Dictionary = _map.desks[near]
		if not t.is_empty():
			_balloons.say(d.employee, t.title, _map.speaker_point.bind(near), Color("a22633"))
		elif not d.server:
			_balloons.say(d.employee, FINE[near % FINE.size()], _map.speaker_point.bind(near))
		_chat_cooldown[near] = 8.0
	_near_desk = near


func _refresh_hud() -> void:
	_clock.text = tickets.clock_text()
	_day.text = "Dia %d · %s" % [tickets.day, "AVALIAÇÃO" if mode == "avaliacao" else "treino"]
	_score.text = str(tickets.score)
	_combo_label.text = "sequência ×%.1f" % tickets.multiplier_after(0) if tickets.combo > 0 else ""
	_satisfaction.value = tickets.satisfaction / 100.0
	var sat_color := Color("5cff8a") if tickets.satisfaction > 60 else (Color("ffd23f") if tickets.satisfaction > 30 else Color("ff5a5a"))
	_set_fill(_satisfaction, sat_color)
	var ids := tickets.tickets.map(func(t): return t.id)
	if ids != _rows.keys():
		_rebuild_ticket_list()
	for t in tickets.tickets:
		var r: Dictionary = _rows[t.id]
		var ratio := clampf(t.sla_left / t.sla_total, 0.0, 1.0)
		r.bar.value = ratio
		_set_fill(r.bar, Color("5cff8a") if ratio > 0.5 else (Color("ffd23f") if ratio > 0.25 else Color("ff5a5a")))
		r.time.text = "%ds" % ceili(t.sla_left)
	var show_prompt := false
	if state == State.PLAYING and _near_desk >= 0:
		var t := tickets.ticket_at_desk(_near_desk)
		var d: Dictionary = _map.desks[_near_desk]
		if not t.is_empty():
			_prompt.text = "[E] Atender chamado #%d · %s (%s)" % [t.id, d.employee, d.dept]
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
	if k in [KEY_M, KEY_N] and state != State.TITLE:
		if k == KEY_M:
			_audio.set_music(not _audio.music_on)
			_show_toast("Música %s (M)" % ("ligada" if _audio.music_on else "desligada"), Color("c0cbdc"))
		else:
			_audio.set_sfx(not _audio.sfx_on)
			_show_toast("Efeitos sonoros %s (N)" % ("ligados" if _audio.sfx_on else "desligados"), Color("c0cbdc"))
		if state == State.PAUSED:
			_show_pause()
		get_viewport().set_input_as_handled()
		return
	match state:
		State.TITLE:
			return
		State.FINAL:
			if k in [KEY_ENTER, KEY_KP_ENTER]:
				_on_overlay_secondary()       # voltar ao menu
			elif k == KEY_R:
				download_report()
		State.DAY_END, State.PAUSED:
			if k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] or (state == State.PAUSED and k in [KEY_P, KEY_ESCAPE]):
				_on_overlay_action()
			elif k == KEY_R and state == State.DAY_END:
				_on_overlay_secondary()
		State.TASK:
			if k == KEY_ESCAPE:
				_cancel_task()
			elif _task and _task.handle_key(k):
				_audio.play("click", -6.0)
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
	if profile.class_code != "":
		_task.set_meta("seed", absi(("%s|%s|%d" % [profile.class_code, mode, t.id]).hash()))
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
	_audio.play("open")
	_balloons.say(profile.name, TECH_LINES[t.id % TECH_LINES.size()], _player_head, Skins.SHIRT[profile.shirt].c[2])


func _on_task_feedback(text: String, kind: String) -> void:
	_task_feedback.text = text
	var colors := {"good": Color("5cff8a"), "bad": Color("ff5a5a"), "ask": Color("ffd23f")}
	_task_feedback.add_theme_color_override("font_color", colors.get(kind, Color.WHITE))


func _on_task_mistake() -> void:
	_task_mistakes += 1
	tickets.register_mistake()
	_audio.play("error")


func _on_task_solved(summary: String) -> void:
	_task_feedback.text = "RESOLVIDO! " + summary
	_task_feedback.add_theme_color_override("font_color", Color("5cff8a"))
	_audio.play("success")
	var id := _task_ticket_id
	await get_tree().create_timer(1.8).timeout
	if state != State.TASK or _task_ticket_id != id:
		return
	tickets.resolve(id, _task_mistakes)
	_close_task()
	state = State.PLAYING


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
	if _task_layer:
		_task_layer.visible = false


# ================================================================ eventos da fila

func _on_ticket_opened(t: Dictionary) -> void:
	_audio.play("ticket", -3.0)
	_balloons.say(t.employee, t.title, _map.speaker_point.bind(t.desk), Color("a22633"))
	_chat_cooldown[t.desk] = 8.0


func _on_ticket_resolved(t: Dictionary, pts: int) -> void:
	_balloons.say(t.employee, THANKS[t.id % THANKS.size()], _map.speaker_point.bind(t.desk), Color("3e8948"))
	var extra := ""
	if tickets.combo >= 2:
		extra = "  ·  sequência de %d sem erro!" % tickets.combo
		_audio.play("combo", -4.0)
	_show_toast("Chamado #%d resolvido! +%d pontos%s" % [t.id, pts, extra], Color("5cff8a"))


func _on_ticket_expired(t: Dictionary) -> void:
	_audio.play("expired")
	_balloons.say(t.employee, ANGRY[t.id % ANGRY.size()], _map.speaker_point.bind(t.desk), Color("a22633"))
	_show_toast("Prazo estourado! Chamado #%d de %s (−50 pontos)." % [t.id, t.employee], Color("ff5a5a"))


func _on_day_ended() -> void:
	_audio.play("dayend")
	if mode == "avaliacao":
		_show_final("18:00 — FIM DA AVALIAÇÃO", "Expediente concluído. Baixe o relatório e envie para o professor.")
		return
	state = State.DAY_END
	_save_session_next_day()
	var g := tickets.grade()
	_overlay_text.text = """[color=#2ce8f5][font_size=28]18:00 — FIM DO EXPEDIENTE[/font_size][/color]
[color=#c0cbdc]%s · Dia %d concluído · sessão salva[/color]

[table=2]
[cell]Chamados resolvidos hoje   [/cell][cell][color=#63c74d]%d[/color][/cell]
[cell]Prazos estourados hoje[/cell][cell][color=#e43b44]%d[/color][/cell]
[cell]Satisfação dos usuários[/cell][cell]%d%%[/cell]
[cell]Pontuação total[/cell][cell][color=#feae34]%d[/color][/cell]
[cell]Nota até agora (0 a 10)[/cell][cell][color=#feae34]%.1f[/color][/cell]
[/table]

[color=#c0cbdc]Amanhã os chamados chegam mais rápido e com prazos menores.[/color]""" % [
		profile.name, tickets.day, tickets.day_resolved, tickets.day_expired,
		int(tickets.satisfaction), tickets.score, g.nota]
	_overlay_button.text = "[Enter] Começar o dia %d" % (tickets.day + 1)
	_overlay_button2.text = "[R] Baixar relatório"
	_overlay_button2.visible = true
	_overlay.visible = true


func _save_session_next_day() -> void:
	var d := tickets.to_dict()
	d.day = tickets.day + 1
	SaveGame.save_session({"profile": profile, "mode": mode, "state": d, "restarts": restarts, "finished": false})


func _on_game_over() -> void:
	_close_task()
	_audio.play("expired")
	_show_final("CHAMADO NA SALA DO GERENTE", "A satisfação dos usuários chegou a zero. O gerente quer \"conversar sobre o suporte\".")


## Tela de resultado final (fim da avaliação ou fim de jogo): nota, placar e relatório.
func _show_final(title: String, subtitle: String) -> void:
	state = State.FINAL
	var g := tickets.grade()
	var pos := SaveGame.add_to_board(profile.name, profile.class_code, mode, tickets.score, g.nota)
	_save_session(true)
	_overlay_text.text = """[color=#2ce8f5][font_size=28]%s[/font_size][/color]
[color=#c0cbdc]%s[/color]

[font_size=22]%s · nota [color=#feae34]%.1f[/color] · [color=#feae34]%d[/color] pontos[/font_size]
%s
[table=2]
[cell]Chamados resolvidos   [/cell][cell][color=#63c74d]%d[/color][/cell]
[cell]Resolvidos sem erro[/cell][cell]%d%%[/cell]
[cell]Prazos estourados[/cell][cell][color=#e43b44]%d[/color][/cell]
[cell]Erros nos atendimentos[/cell][cell]%d[/cell]
[cell]Melhor sequência sem erro[/cell][cell]%d[/cell]
[/table]

[color=#c0cbdc]O relatório tem um código de verificação: o professor confere se ele não foi alterado.[/color]""" % [
		title, subtitle, profile.name, g.nota, tickets.score,
		"[color=#fee761]%dº lugar no placar deste computador![/color]\n" % pos if pos > 0 and pos <= 10 else "",
		tickets.resolved, int(g.accuracy * 100), tickets.expired, tickets.mistakes, tickets.best_combo]
	_overlay_button.text = "[R] Baixar relatório para enviar ao professor"
	_overlay_button2.text = "[Enter] Voltar ao menu"
	_overlay_button2.visible = true
	_overlay.visible = true


func download_report() -> String:
	var d := Report.data(profile, tickets, "Avaliação" if mode == "avaliacao" else "Treino", restarts)
	var msg := Report.deliver(Report.html(d), Report.file_name(profile))
	_show_toast(msg, Color("63c74d"))
	return msg


# ================================================================ overlays

func _show_pause() -> void:
	state = State.PAUSED
	_overlay_text.text = "[color=#2ce8f5][font_size=28]PAUSA PARA O CAFÉ[/font_size][/color]\n\nO relógio parou. Aperte [b]P[/b], [b]Esc[/b] ou [b]Enter[/b] para voltar.\n\n[b]M[/b]  Música: %s\n[b]N[/b]  Efeitos sonoros: %s" % [
		"[color=#63c74d]ligada[/color]" if _audio.music_on else "[color=#e43b44]desligada[/color]",
		"[color=#63c74d]ligados[/color]" if _audio.sfx_on else "[color=#e43b44]desligados[/color]"]
	_overlay_button.text = "[Enter] Voltar ao trabalho"
	_overlay_button2.visible = false
	_overlay.visible = true


func _on_overlay_action() -> void:
	match state:
		State.PAUSED:
			state = State.PLAYING
		State.DAY_END:
			_begin_day(tickets.day + 1)
			state = State.PLAYING
			_show_toast("Dia %d · 09:00 · bom trabalho!" % tickets.day, Color("34e7e4"))
		State.FINAL:
			download_report()
			return
	_overlay.visible = false


func _on_overlay_secondary() -> void:
	match state:
		State.DAY_END:
			download_report()
		State.FINAL:
			_overlay.visible = false
			_new_tickets(-1)
			_show_menu()


func _show_toast(text: String, color: Color) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)
