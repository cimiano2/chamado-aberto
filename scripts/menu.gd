class_name Menu
extends Control
## Tela inicial: logo, personagem (amostras de cor), identificação, modo de jogo,
## continuar sessão, placar, ajuda e chaves de música/efeitos.

signal start_requested(profile: Dictionary, mode: String, resume: bool)

const C_INK := Color("181425")
const C_CARD := Color("262b44")
const C_CARD2 := Color("3a4466")
const C_CYAN := Color("2ce8f5")
const C_YELLOW := Color("feae34")
const C_MUTED := Color("c0cbdc")

var audio: Audio
var profile := {"name": "", "class_code": "", "skin": 0, "hair": 0, "shirt": 0}
var mode := "avaliacao"
var _saved := {}
var _name: LineEdit
var _code: LineEdit
var _atlas: AtlasTexture
var _preview_name: Label
var _swatches := {}           # chave -> Array[Button]
var _mode_cards := {}         # modo -> PanelContainer
var _error: Label
var _music_btn: Button
var _sfx_btn: Button
var _popup: Control
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_saved = SaveGame.load_session()
	if _saved.has("profile"):
		profile = _saved.profile.duplicate()
	# fundo: o escritório aparece por trás, escurecido
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.05, 0.12, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	var head_panel := PanelContainer.new()
	var hs := StyleBoxFlat.new()
	hs.bg_color = Color(0.06, 0.05, 0.12, 0.92)
	hs.border_color = C_INK
	hs.set_border_width_all(3)
	hs.set_content_margin_all(12)
	hs.content_margin_left = 18
	head_panel.add_theme_stylebox_override("panel", hs)
	head_panel.add_child(_header())
	root.add_child(head_panel)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	body.add_child(_character_card())
	body.add_child(_identity_card())
	body.add_child(_mode_card())
	root.add_child(_footer())
	_refresh()
	_name.grab_focus()


func _process(delta: float) -> void:
	_t += delta
	if _atlas:
		_atlas.region = Rect2(int(_t * 6.0) % 4 * 20, 0, 20, 34)


# ================================================================ blocos

func _header() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/sprites/alert.png")
	icon.custom_minimum_size = Vector2(55, 60)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var title := _label("CHAMADO ABERTO", 46, C_CYAN)
	title.add_theme_color_override("font_shadow_color", Color("124e89"))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	v.add_child(title)
	v.add_child(_label("Papéis Horizonte Ltda.  ·  você é o técnico de TI. Resolva os chamados antes que o prazo estoure!", 17, C_MUTED))
	return h


func _character_card() -> Control:
	var card := _card("1  SEU PERSONAGEM", C_CYAN)
	var box: VBoxContainer = card.get_meta("box")
	var stage := CenterContainer.new()
	stage.custom_minimum_size = Vector2(0, 228)
	box.add_child(stage)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(192, 228)
	stage.add_child(stack)
	var floor := TextureRect.new()
	floor.texture = load("res://assets/sprites/floor_ti.png")
	floor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	floor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	floor.size = Vector2(192, 96)
	floor.position = Vector2(0, 132)
	stack.add_child(floor)
	_atlas = AtlasTexture.new()
	var hero := TextureRect.new()
	hero.texture = _atlas
	hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.size = Vector2(110, 187)
	hero.position = Vector2(41, 0)
	stack.add_child(hero)
	_preview_name = _label("", 18, Color.WHITE)
	_preview_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_name.add_theme_color_override("font_outline_color", C_INK)
	_preview_name.add_theme_constant_override("outline_size", 6)
	box.add_child(_preview_name)
	for k in [["skin", "Pele", Skins.SKIN], ["hair", "Cabelo", Skins.HAIR], ["shirt", "Camisa", Skins.SHIRT]]:
		box.add_child(_label(k[1], 15, C_MUTED))
		box.add_child(_swatch_row(k[0], k[2]))
	return card


func _identity_card() -> Control:
	var card := _card("2  IDENTIFICAÇÃO", C_YELLOW)
	var box: VBoxContainer = card.get_meta("box")
	box.add_child(_label("Seu nome completo", 17, Color.WHITE))
	_name = _edit(profile.name, "Ex.: Maria Silva", 28)
	_name.text_changed.connect(func(_t: String) -> void: _refresh())
	box.add_child(_name)
	box.add_child(_label("Aparece sobre o personagem, no placar e no relatório.", 14, C_MUTED))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 10)
	box.add_child(sp)
	box.add_child(_label("Código da turma", 17, Color.WHITE))
	_code = _edit(profile.class_code, "Ex.: INFO1A", 12)
	box.add_child(_code)
	var hint := _label("O professor informa. Com o mesmo código, todos da turma recebem os mesmos chamados (obrigatório na avaliação).", 14, C_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	if not (_saved.has("profile") and not _saved.get("finished", false)):
		var sp3 := Control.new()
		sp3.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(sp3)
		var tip := PanelContainer.new()
		var ts := StyleBoxFlat.new()
		ts.bg_color = Color("1d2238")
		ts.border_color = C_YELLOW.darkened(0.3)
		ts.set_border_width_all(2)
		ts.border_width_left = 6
		ts.set_content_margin_all(12)
		tip.add_theme_stylebox_override("panel", ts)
		var tl := _label("Dica: a seta amarela aponta o chamado mais urgente. Resolver vários seguidos sem errar multiplica seus pontos!", 15, Color.WHITE)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.add_child(tl)
		box.add_child(tip)
	if _saved.has("profile") and not _saved.get("finished", false):
		var sp2 := Control.new()
		sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(sp2)
		var cont := _button("Continuar sessão salva\n%s · %s · Dia %d · %d pts" % [_saved.profile.name,
			"Avaliação" if _saved.mode == "avaliacao" else "Treino", int(_saved.state.day), int(_saved.state.score)],
			func(): _start(_saved.mode, true), Color("63c74d"))
		cont.custom_minimum_size = Vector2(0, 64)
		box.add_child(cont)
	return card


func _mode_card() -> Control:
	var card := _card("3  MODO DE JOGO", Color("63c74d"))
	var box: VBoxContainer = card.get_meta("box")
	box.add_child(_mode_option("avaliacao", "AVALIAÇÃO",
		"Um expediente de 5 minutos.\nNo fim: nota de 0 a 10 e relatório\npara enviar ao professor."))
	box.add_child(_mode_option("treino", "TREINO",
		"Dias seguidos, cada vez mais difíceis.\nSessão salva para continuar depois."))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(sp)
	_error = _label("", 15, Color("f77622"))
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_error)
	var go := _button("COMEÇAR  >", func(): _start(mode, false), C_CYAN)
	go.add_theme_font_size_override("font_size", 28)
	go.custom_minimum_size = Vector2(0, 68)
	var gs := StyleBoxFlat.new()
	gs.bg_color = Color("0099db")
	gs.border_color = C_INK
	gs.set_border_width_all(4)
	gs.shadow_color = Color("124e89")
	gs.shadow_offset = Vector2(0, 6)
	var gh := gs.duplicate() as StyleBoxFlat
	gh.bg_color = C_CYAN
	go.add_theme_stylebox_override("normal", gs)
	go.add_theme_stylebox_override("hover", gh)
	go.add_theme_stylebox_override("pressed", gh)
	go.add_theme_color_override("font_color", Color.WHITE)
	go.add_theme_color_override("font_hover_color", C_INK)
	go.add_theme_color_override("font_outline_color", Color("124e89"))
	go.add_theme_constant_override("outline_size", 6)
	box.add_child(go)
	return card


func _footer() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.add_child(_button("Placar", _show_board, C_YELLOW))
	h.add_child(_button("Como jogar", _show_help, C_CYAN))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	_music_btn = _button("", func(): audio.set_music(not audio.music_on), Color("b55088"))
	_sfx_btn = _button("", func(): audio.set_sfx(not audio.sfx_on), Color("b55088"))
	h.add_child(_music_btn)
	h.add_child(_sfx_btn)
	return h


# ================================================================ peças

func _card(title: String, accent: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := StyleBoxFlat.new()
	st.bg_color = C_CARD
	st.border_color = C_INK
	st.set_border_width_all(3)
	st.border_width_top = 8
	st.border_color = accent.darkened(0.15)
	st.set_content_margin_all(16)
	st.shadow_color = Color(0, 0, 0, 0.45)
	st.shadow_offset = Vector2(5, 5)
	p.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(_label(title, 20, accent))
	p.set_meta("box", v)
	return p


func _swatch_row(key: String, options: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var list: Array[Button] = []
	for i in options.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(30, 30)
		b.tooltip_text = options[i].name
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func():
			profile[key] = i
			if audio: audio.play("click", -6.0)
			_refresh())
		h.add_child(b)
		list.append(b)
	_swatches[key] = [list, options]
	return h


func _mode_option(key: String, title: String, desc: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var t := _label(title, 22, Color.WHITE)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	var d := _label(desc, 15, C_MUTED)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(d)
	p.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			mode = key
			if audio: audio.play("click", -6.0)
			_refresh())
	_mode_cards[key] = p
	return p


func _refresh() -> void:
	_atlas.atlas = Skins.texture(profile.skin, profile.hair, profile.shirt)
	_preview_name.text = _name.text.strip_edges() if _name and _name.text.strip_edges() != "" else "Seu nome"
	for key in _swatches:
		var list: Array = _swatches[key][0]
		var opts: Array = _swatches[key][1]
		for i in list.size():
			var col: Color = opts[i].c[1] if opts[i].c.size() > 2 else opts[i].c[0]
			var st := StyleBoxFlat.new()
			st.bg_color = col
			var sel: bool = int(profile[key]) == i
			st.border_color = Color.WHITE if sel else C_INK
			st.set_border_width_all(4 if sel else 2)
			for state in ["normal", "hover", "pressed"]:
				list[i].add_theme_stylebox_override(state, st)
	for key in _mode_cards:
		var sel: bool = key == mode
		var st := StyleBoxFlat.new()
		st.bg_color = C_CARD2 if sel else Color("1d2238")
		st.border_color = C_YELLOW if sel else C_INK
		st.set_border_width_all(4 if sel else 2)
		st.set_content_margin_all(12)
		_mode_cards[key].add_theme_stylebox_override("panel", st)
	if audio:
		_music_btn.text = "Som ambiente: %s  (M)" % ("ligado" if audio.music_on else "desligado")
		_sfx_btn.text = "Efeitos: %s  (N)" % ("ligados" if audio.sfx_on else "desligados")


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if _popup and k.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
		_close_popup()
	elif k.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		_start(mode, false)
	else:
		return
	get_viewport().set_input_as_handled()


func _start(m: String, resume: bool) -> void:
	profile.name = _name.text.strip_edges()
	profile.class_code = _code.text.strip_edges().to_upper()
	if profile.name.length() < 2:
		_error.text = "Digite seu nome no cartão 2."
		_name.grab_focus()
		return
	if m == "avaliacao" and profile.class_code == "" and not resume:
		_error.text = "Para a avaliação, digite o código da turma no cartão 2."
		_code.grab_focus()
		return
	start_requested.emit(profile.duplicate(), m, resume)


# ================================================================ janelas (placar e ajuda)

func _show_board() -> void:
	var lines := ""
	var board := SaveGame.board()
	if board.is_empty():
		lines = "[color=#c0cbdc]Ninguém jogou ainda neste computador. Seja o primeiro![/color]"
	for i in board.size():
		var e: Dictionary = board[i]
		lines += "[color=%s]%dº  %s[/color]   [color=#feae34]%d pts[/color]  ·  nota %.1f\n[color=#8b9bb4]      %s · %s · %s[/color]\n" % [
			"#fee761" if i == 0 else "#ffffff", i + 1, e.name, int(e.points), float(e.nota),
			e.turma if e.turma != "" else "sem turma", "avaliação" if e.mode == "avaliacao" else "treino", e.date]
	_open_popup("PLACAR DESTE COMPUTADOR", lines + "\n[color=#c0cbdc]O ranking da turma é feito pelo professor com os relatórios enviados.[/color]")


func _show_help() -> void:
	_open_popup("COMO JOGAR", """[color=#feae34]Andar:[/color] WASD ou setas  ·  [color=#feae34]Atender:[/color] E (na frente da mesa com [b]![/b])
[color=#feae34]Responder:[/color] teclas 1–9 e Enter (ou o mouse)  ·  [color=#feae34]Sair do atendimento:[/color] Esc
[color=#feae34]Pausa:[/color] P ou Esc  ·  [color=#feae34]Som ambiente:[/color] M  ·  [color=#feae34]Efeitos:[/color] N

A seta amarela aponta o chamado mais urgente. Cada chamado tem um prazo:
se ele estourar, a satisfação dos usuários cai e você perde pontos.

[color=#2ce8f5]Pontos[/color]
• 100 por chamado resolvido  · até +100 se for rápido  · +50 se for da Gerência
• −25 por erro  · prazo estourado: −50
• resolver vários seguidos sem errar multiplica os pontos (até ×1,5)

[color=#2ce8f5]Nota (0 a 10)[/color]: 40% chamados resolvidos + 40% resolvidos sem erro + 20% rapidez.""")


func _open_popup(title: String, bbcode: String) -> void:
	_close_popup()
	_popup = ColorRect.new()
	(_popup as ColorRect).color = Color(0, 0, 0, 0.6)
	add_child(_popup)
	_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var c := CenterContainer.new()
	_popup.add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := _card(title, C_YELLOW)
	card.custom_minimum_size = Vector2(760, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.add_child(card)
	var box: VBoxContainer = card.get_meta("box")
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.add_theme_font_size_override("normal_font_size", 17)
	text.add_theme_font_size_override("bold_font_size", 17)
	text.text = bbcode
	box.add_child(text)
	box.add_child(_button("Fechar  (Esc)", _close_popup, C_CYAN))


func _close_popup() -> void:
	if _popup:
		_popup.queue_free()
		_popup = null


# ================================================================ util

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _edit(text: String, placeholder: String, max_len: int) -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.placeholder_text = placeholder
	e.max_length = max_len
	e.add_theme_font_size_override("font_size", 22)
	e.custom_minimum_size = Vector2(0, 46)
	var st := StyleBoxFlat.new()
	st.bg_color = C_INK
	st.border_color = Color("5a6988")
	st.set_border_width_all(3)
	st.set_content_margin_all(10)
	var fo := st.duplicate() as StyleBoxFlat
	fo.border_color = C_YELLOW
	e.add_theme_stylebox_override("normal", st)
	e.add_theme_stylebox_override("focus", fo)
	e.add_theme_color_override("font_placeholder_color", Color("5a6988"))
	return e


func _button(text: String, cb: Callable, accent: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 17)
	var st := StyleBoxFlat.new()
	st.bg_color = C_CARD2
	st.border_color = accent.darkened(0.2)
	st.set_border_width_all(3)
	st.set_content_margin_all(10)
	st.content_margin_left = 16
	st.content_margin_right = 16
	var hv := st.duplicate() as StyleBoxFlat
	hv.bg_color = accent.darkened(0.45)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.pressed.connect(func():
		if audio: audio.play("click", -6.0)
		cb.call())
	return b
