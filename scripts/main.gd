extends Node
## Cena principal: menu, sessão salva, andar, técnico, fila de chamados, HUD, balões, sons,
## minijogos e relatório de desempenho.

enum State { TITLE, PLAYING, TASK, PAUSED, DAY_END, FINAL }

## Ampliação do mundo (cada pixel da arte vira view_scale x view_scale pixels da tela).
## Sempre inteira, e a interface também usa escala inteira (scale_mode="integer"):
## escala fracionada deixa pixels de larguras diferentes, que "tremem" ao rolar e
## deixam a fonte pixelada ilegível.
var view_scale := 2
const TECH_LINES := ["Deixa comigo!", "Bora resolver isso.", "Vamos ver o que houve...", "Já estou aqui!"]
const THANKS := ["Valeu! Salvou meu dia!", "Funcionou! Obrigado(a)!", "Ufa! Muito obrigado(a)!", "Você é o(a) melhor!"]
const ANGRY := ["Vou reclamar com o gerente!", "Ninguém veio me ajudar...", "Assim não dá!"]
const FINE := ["Tudo certo por aqui!", "Por enquanto tudo funcionando.", "Bom dia!", "Café está bom hoje."]

var tickets: TicketSystem
var state: State = State.TITLE
var profile := {"name": "", "class_code": "", "skin": 0, "hair": 0, "shirt": 0, "body": 0}
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
var _pause_sound_row: HBoxContainer
var _btn_ambient: Button
var _btn_sfx: Button
var _pause_button: Button
var _serve_button: Button        # "Atender chamado" (toque/clique)
var _rotate_layer: CanvasLayer   # aviso "gire o celular"
var _auto_desk := -1             # mesa a atender quando o técnico chegar (toque numa mesa)
var _confirm_menu := false
var _chat_cooldown := {}         # mesa -> segundos até poder falar de novo
var _step_t := 0.0
## Versão 3D: o mesmo jogo (mapa, colisão, chamados) com o mundo desenhado em 3D.
var is_3d := false
var _w3: Office3D
var _w3_view: SubViewportContainer

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
	get_window().size_changed.connect(_fit_window)
	_fit_window()
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
	_pause_sound_row = HBoxContainer.new()
	_pause_sound_row.add_theme_constant_override("separation", 10)
	_btn_ambient = Button.new()
	_btn_ambient.focus_mode = Control.FOCUS_NONE
	_btn_ambient.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_ambient.pressed.connect(func():
		_audio.set_music(not _audio.music_on)
		_show_pause())
	_btn_sfx = Button.new()
	_btn_sfx.focus_mode = Control.FOCUS_NONE
	_btn_sfx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_sfx.pressed.connect(func():
		_audio.set_sfx(not _audio.sfx_on)
		_show_pause())
	_pause_sound_row.add_child(_btn_ambient)
	_pause_sound_row.add_child(_btn_sfx)
	_overlay_button.get_parent().add_child(_pause_sound_row)
	_pause_sound_row.visible = false
	# botão de pausa sempre visível durante o jogo (canto inferior esquerdo)
	_pause_button = Button.new()
	_pause_button.text = "||  Pausa / Menu  (P)"
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.add_theme_font_size_override("font_size", 16)
	_room_labels.get_parent().add_child(_pause_button)
	_pause_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_pause_button.offset_left = 16
	_pause_button.offset_top = -60
	_pause_button.offset_bottom = -22
	_serve_button = Button.new()
	_serve_button.text = "Atender chamado  (E)"
	_serve_button.focus_mode = Control.FOCUS_NONE
	_serve_button.theme_type_variation = &"PrimaryButton"
	_serve_button.add_theme_font_size_override("font_size", 22)
	_room_labels.get_parent().add_child(_serve_button)
	_serve_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_KEEP_SIZE)
	_serve_button.offset_left = -150
	_serve_button.offset_right = 150
	_serve_button.offset_top = -128
	_serve_button.offset_bottom = -72
	_serve_button.visible = false
	_serve_button.pressed.connect(_interact)
	_build_task_exit()
	_build_rotate_hint()
	_player.arrived.connect(_on_player_arrived)
	_pause_button.pressed.connect(func():
		if state == State.PLAYING:
			_show_pause()
		elif state == State.PAUSED:
			_on_overlay_action())
	_audio = Audio.new()
	add_child(_audio)
	_balloons = Balloons.new()
	_balloons.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_balloons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_balloons.to_screen = func(p: Vector2) -> Vector2: return p    # âncoras já vêm na tela
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
	_set_view(false)          # o fundo do menu é sempre o escritório em pixel art
	_overlay.visible = false
	_room_labels.get_parent().visible = false     # HUD escondido enquanto o menu está aberto
	if _audio:
		_audio.stop_music()                          # o som ambiente toca só durante o jogo
		_audio.play_menu_music()                     # e a música original só no menu
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
	_player.stop_walk()
	_auto_desk = -1
	profile = p
	mode = m
	_set_view(str(p.get("view", "2d")) == "3d")
	var saved := SaveGame.load_session() if resume else {}
	_new_tickets(_seed())
	if resume and saved.has("state"):
		tickets.from_dict(saved.state)
		restarts = int(saved.get("restarts", 0)) + 1
		mode = saved.get("mode", mode)
	else:
		restarts = 0
	_begin_day(tickets.day)
	_map.player_tex = Skins.texture(profile.skin, profile.hair, profile.shirt, int(profile.get("body", 0)))
	if is_3d:
		_w3.set_profile(profile)
		_w3.snap_camera()
	_name_tag.text = profile.name
	_name_tag.add_theme_color_override("font_color", Skins.SHIRT[profile.shirt].c[0])
	if _menu_layer:
		_menu_layer.queue_free()
		_menu_layer = null
	_room_labels.get_parent().visible = true
	_audio.stop_menu_music()
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
	if is_3d and _w3:
		_w3.snap_camera()
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
	var half := Vector2(_world_view.get_child(0).size / 2)
	r.x = clampf(r.x, _cam_bounds.position.x + half.x, maxf(_cam_bounds.position.x + half.x, _cam_bounds.end.x - half.x))
	r.y = clampf(r.y, _cam_bounds.position.y + half.y, maxf(_cam_bounds.position.y + half.y, _cam_bounds.end.y - half.y))
	r = r.round()
	_cam_f = r
	_camera.position = r
	var feet := _world_to_ui(_player.position, 0.0)
	var me := Rect2(feet - Vector2(24, 76), Vector2(48, 82))
	for p in _plaques:
		var node: Control = p.node
		node.position = (_world_to_ui(p.world, 30.0) - node.size / 2.0).round()
		# placa fica quase transparente quando o personagem passa por trás dela
		node.modulate.a = 0.25 if Rect2(node.position, node.size).intersects(me) else 1.0
	_name_tag.visible = state != State.TITLE
	_pause_button.visible = state == State.PLAYING
	_serve_button.visible = state == State.PLAYING and _near_desk >= 0 and not tickets.ticket_at_desk(_near_desk).is_empty()
	_name_tag.position = (feet + Vector2(-_name_tag.size.x / 2.0, 6)).round()


## Ponto do canvas isométrico (640x360) → posição na tela cheia.
func _to_screen(p: Vector2) -> Vector2:
	return _world_view.get_global_transform() * ((p - _cam_f) * view_scale + _world_view.size / 2.0)


## Ponto do mundo (altura em "pixels" do desenho 2D) → posição na tela cheia, em 2D ou 3D.
func _world_to_ui(world: Vector2, z: float) -> Vector2:
	if is_3d:
		return _w3_ui(_w3.point_screen(world, z * Office3D.PX))
	return _to_screen(OfficeMap.iso_f(world, z))


## Ponto da SubViewport 3D → tela cheia (e o inverso, para toques).
func _w3_ui(p: Vector2) -> Vector2:
	return _w3_view.get_global_transform() * (p * _w3_view.stretch_shrink)


func _ui_w3(ui_pos: Vector2) -> Vector2:
	return (_w3_view.get_global_transform().affine_inverse() * ui_pos) / _w3_view.stretch_shrink


## Balão de fala de quem está na mesa i (já em coordenadas da tela).
func _speaker(i: int) -> Vector2:
	if is_3d:
		return _w3_ui(_w3.speaker_screen(i))
	return _to_screen(_map.speaker_point(i))


## Liga o visual 2D (pixel art) ou 3D. Só o desenho muda: mapa, colisão e chamados são os mesmos.
func _set_view(three: bool) -> void:
	if three and _w3 == null:
		_build_3d()
	is_3d = three
	_world_view.visible = not three
	(_world_view.get_child(0) as SubViewport).render_target_update_mode = \
		SubViewport.UPDATE_DISABLED if three else SubViewport.UPDATE_ALWAYS
	if _w3:
		_w3_view.visible = three
		_w3.process_mode = Node.PROCESS_MODE_INHERIT if three else Node.PROCESS_MODE_DISABLED
		(_w3_view.get_child(0) as SubViewport).render_target_update_mode = \
			SubViewport.UPDATE_ALWAYS if three else SubViewport.UPDATE_DISABLED
	if _balloons:
		_balloons.clear()
	_fit_world()


func _build_3d() -> void:
	_w3_view = SubViewportContainer.new()
	_w3_view.stretch = true
	_w3_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_w3_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.handle_input_locally = false
	vp.msaa_3d = Viewport.MSAA_DISABLED
	_w3_view.add_child(vp)
	add_child(_w3_view)
	move_child(_w3_view, _world_view.get_index() + 1)
	_w3 = Office3D.new()
	vp.add_child(_w3)
	_w3.setup(_map, _player)


## A interface ocupa a tela toda (base 1280x720, escala livre) com fonte comum suavizada,
## legível em qualquer escala. O mundo em pixel art usa escala sempre inteira (_fit_world).
func _fit_window() -> void:
	if _rotate_layer:
		var ws := get_window().size
		_rotate_layer.visible = ws.y > ws.x
	_fit_world.call_deferred()


## Ajusta o mundo ao tamanho da janela com ampliação inteira: ~360 linhas de arte visíveis
## (2x até 900 px de altura, 3x em 1080p...). O quadro do mundo tem tamanho par em pixels
## de arte e fica centrado em posição inteira, então a câmera cai sempre num pixel exato.
func _fit_world() -> void:
	var ui := get_viewport().get_final_transform()
	var k := ui.get_scale()                       # pixels da tela por unidade da interface
	var phys := Vector2(get_window().size)        # pixels reais da janela
	# ~360 linhas de arte visíveis; em celular (tela de toque baixa) aproxima mais, para os
	# personagens não ficarem minúsculos e serem fáceis de tocar
	var rows := 360.0
	var dpr := maxf(1.0, DisplayServer.screen_get_scale())
	if DisplayServer.is_touchscreen_available() and phys.y / dpr < 520.0:
		rows = 250.0
	view_scale = clampi(roundi(phys.y / rows), 2, 8)
	_world_view.stretch_shrink = view_scale
	var px := Vector2i.ZERO
	for axis in 2:
		var n := int(ceil(phys[axis] / view_scale)) + 2
		n += n % 2    # par: o centro do quadro (onde fica a câmera) cai num pixel inteiro
		px[axis] = n
	var total := Vector2(px * view_scale)
	# o quadro do mundo desfaz a escala da interface: 1 unidade dele = 1 pixel real da tela,
	# e o canto dele cai num pixel inteiro
	var corner_phys := ((phys - total) / 2.0).floor()
	_world_view.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_world_view.scale = Vector2(1.0 / k.x, 1.0 / k.y)
	_world_view.size = total
	_world_view.position = ui.affine_inverse() * corner_phys
	if _w3_view:
		# 3D na resolução real da tela; em celular (tela densa) pela metade, para ficar leve
		_w3_view.stretch_shrink = 2 if dpr >= 2.0 or rows < 300.0 else 1
		_w3_view.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_w3_view.scale = Vector2(1.0 / k.x, 1.0 / k.y)
		_w3_view.size = phys
		_w3_view.position = ui.affine_inverse() * Vector2.ZERO


func _player_head() -> Vector2:
	if is_3d:
		return _w3_ui(_w3.head_screen())
	return _to_screen(OfficeMap.iso_f(_player.position, 36))


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
	if is_3d:
		_w3.guide_target = _guide.target
	var near := _map.desk_index_near(_player.position)
	if near != _near_desk and near >= 0 and state == State.PLAYING and _chat_cooldown.get(near, 0.0) <= 0.0:
		# quem está na mesa puxa conversa (como num chat de mundo isométrico)
		var t := tickets.ticket_at_desk(near)
		var d: Dictionary = _map.desks[near]
		if not t.is_empty():
			_balloons.say(d.employee, t.title, _speaker.bind(near), Color("a22633"))
		elif not d.server:
			_balloons.say(d.employee, FINE[near % FINE.size()], _speaker.bind(near))
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
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and state == State.PLAYING:
		_tap(mb.position)
		get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var k := key.keycode
	if k in [KEY_M, KEY_N] and state != State.TITLE:
		if k == KEY_M:
			_audio.set_music(not _audio.music_on)
			_show_toast("Som ambiente %s (M)" % ("ligado" if _audio.music_on else "desligado"), Color("c0cbdc"))
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
			elif k == KEY_Q and state == State.PAUSED:
				_on_overlay_secondary()
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


## Toque/clique no mundo: anda até o ponto (contornando paredes); tocando num funcionário
## com chamado, anda até a mesa dele e abre o atendimento ao chegar.
func _tap(ui_pos: Vector2) -> void:
	var desk: int
	var target: Vector2
	if is_3d:
		var sp := _ui_w3(ui_pos)
		desk = _w3.desk_at_screen(sp)
		target = _w3.screen_to_ground(sp)
		if target == Vector2.INF and desk < 0:
			return
	else:
		var local := _world_view.get_global_transform().affine_inverse() * ui_pos
		var c := (local - _world_view.size / 2.0) / view_scale + _cam_f      # ponto no canvas isométrico
		desk = _map.desk_at_canvas(c)
		target = Vector2(2.0 * c.x + 4.0 * c.y, -2.0 * c.x + 4.0 * c.y)   # chão (inverso da projeção)
	_auto_desk = -1
	if desk >= 0:
		target = _map.desks[desk].pos
		if not tickets.ticket_at_desk(desk).is_empty():
			_auto_desk = desk
			if _map.desk_index_near(_player.position) == desk:
				_player.stop_walk()
				_on_player_arrived()
				return
	var path := _map.find_path(_player.position, target)
	if path.is_empty():
		_auto_desk = -1
		return
	_map.show_tap(path[path.size() - 1])
	_player.walk_to(path)


func _on_player_arrived() -> void:
	var d := _auto_desk
	_auto_desk = -1
	if d < 0 or state != State.PLAYING or _map.desk_index_near(_player.position) != d:
		return
	var t := tickets.ticket_at_desk(d)
	if not t.is_empty():
		_player.facing = Vector2.UP
		_open_task(t)


## Botão "Sair" no canto do atendimento (para quem não tem a tecla Esc: celular/tablet).
func _build_task_exit() -> void:
	var vbox := _ticket_header.get_parent()
	var row := HBoxContainer.new()
	vbox.add_child(row)
	vbox.move_child(row, _ticket_header.get_index())
	_ticket_header.reparent(row)
	_ticket_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := Button.new()
	b.text = "Sair  (Esc)"
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(func():
		if state == State.TASK:
			_cancel_task())
	row.add_child(b)


## Celular em pé: pede para girar (o jogo é horizontal).
func _build_rotate_hint() -> void:
	_rotate_layer = CanvasLayer.new()
	_rotate_layer.layer = 20
	add_child(_rotate_layer)
	var bg := ColorRect.new()
	bg.color = Color("181425")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rotate_layer.add_child(bg)
	var l := Label.new()
	l.text = "Gire o celular\npara a horizontal"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 64)
	l.add_theme_color_override("font_color", Color("2ce8f5"))
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_child(l)
	_rotate_layer.visible = false
	_fit_window()


func _interact() -> void:
	if _near_desk < 0:
		return
	var t := tickets.ticket_at_desk(_near_desk)
	if not t.is_empty():
		_open_task(t)


# ================================================================ minijogos

func _open_task(t: Dictionary) -> void:
	_player.stop_walk()
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
	_balloons.say(t.employee, t.title, _speaker.bind(t.desk), Color("a22633"))
	_chat_cooldown[t.desk] = 8.0


func _on_ticket_resolved(t: Dictionary, pts: int) -> void:
	_balloons.say(t.employee, THANKS[t.id % THANKS.size()], _speaker.bind(t.desk), Color("3e8948"))
	var extra := ""
	if tickets.combo >= 2:
		extra = "  ·  sequência de %d sem erro!" % tickets.combo
		_audio.play("combo", -4.0)
	_show_toast("Chamado #%d resolvido! +%d pontos%s" % [t.id, pts, extra], Color("5cff8a"))


func _on_ticket_expired(t: Dictionary) -> void:
	_audio.play("expired")
	_balloons.say(t.employee, ANGRY[t.id % ANGRY.size()], _speaker.bind(t.desk), Color("a22633"))
	_show_toast("Prazo estourado! Chamado #%d de %s (−%d pontos)." % [t.id, t.employee, TicketSystem.EXPIRED_PENALTY], Color("ff5a5a"))


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
	_player.stop_walk()
	state = State.PAUSED
	_overlay_text.text = """[color=#2ce8f5][font_size=28]PAUSA PARA O CAFÉ[/font_size][/color]
[color=#c0cbdc]%s · Dia %d · %s · %d pontos[/color]

O relógio parou. Aperte [b]P[/b], [b]Esc[/b] ou [b]Enter[/b] para continuar.
%s""" % [profile.name, tickets.day, tickets.clock_text(), tickets.score,
		"\n[color=#feae34]Tem certeza? O expediente de hoje recomeça das 09:00 quando você continuar a sessão.%s[/color]" % (
			" Na avaliação, isso fica registrado no relatório." if mode == "avaliacao" else "") if _confirm_menu else ""]
	_overlay_button.text = "[Enter] Continuar jogando"
	_overlay_button2.text = "Sim, voltar ao menu inicial" if _confirm_menu else "[Q] Voltar ao menu inicial"
	_overlay_button2.visible = true
	_btn_ambient.text = "Som ambiente: %s (M)" % ("ligado" if _audio.music_on else "desligado")
	_btn_sfx.text = "Efeitos: %s (N)" % ("ligados" if _audio.sfx_on else "desligados")
	_pause_sound_row.visible = true
	_overlay.visible = true


func _on_overlay_action() -> void:
	_pause_sound_row.visible = false
	match state:
		State.PAUSED:
			_confirm_menu = false
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
		State.PAUSED:
			if not _confirm_menu:
				_confirm_menu = true
				_show_pause()
				return
			back_to_menu()
		State.DAY_END:
			download_report()
		State.FINAL:
			_overlay.visible = false
			_new_tickets(-1)
			_show_menu()


## Volta ao menu inicial. A sessão continua salva (do início do dia atual) para "Continuar".
func back_to_menu() -> void:
	_confirm_menu = false
	_close_task()
	_balloons.clear()
	_overlay.visible = false
	_pause_sound_row.visible = false
	_new_tickets(-1)
	_show_menu()


func _show_toast(text: String, color: Color) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)
