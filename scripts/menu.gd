class_name Menu
extends Control
## Tela inicial: nome, código da turma, skin, modo de jogo, continuar sessão e placar local.

signal start_requested(profile: Dictionary, mode: String, resume: bool)

var profile := {"name": "", "class_code": "", "skin": 0, "hair": 0, "shirt": 0}
var _name: LineEdit
var _code: LineEdit
var _preview: TextureRect
var _atlas: AtlasTexture
var _labels := {}
var _error: Label
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var saved := SaveGame.load_session()
	if saved.has("profile"):
		profile = saved.profile.duplicate()
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.08, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"Modal"
	center.add_child(panel)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	panel.add_child(cols)

	# ---------------- coluna esquerda: perfil
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.custom_minimum_size = Vector2(520, 0)
	cols.add_child(left)
	left.add_child(_label("CHAMADO ABERTO", 34, Color("2ce8f5")))
	left.add_child(_label("Papéis Horizonte Ltda. · Suporte de TI · 7º andar", 16, Color("c0cbdc")))
	left.add_child(HSeparator.new())
	left.add_child(_label("Seu nome", 16, Color("feae34")))
	_name = _edit(profile.name, "Ex.: Maria Silva", 24)
	left.add_child(_name)
	left.add_child(_label("Código da turma (o professor informa — opcional no treino)", 16, Color("feae34")))
	_code = _edit(profile.class_code, "Ex.: INFO1A", 12)
	left.add_child(_code)

	var skin_row := HBoxContainer.new()
	skin_row.add_theme_constant_override("separation", 18)
	left.add_child(skin_row)
	var preview_box := PanelContainer.new()
	skin_row.add_child(preview_box)
	_atlas = AtlasTexture.new()
	_preview = TextureRect.new()
	_preview.texture = _atlas
	_preview.custom_minimum_size = Vector2(100, 170)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_box.add_child(_preview)
	var pickers := VBoxContainer.new()
	pickers.add_theme_constant_override("separation", 6)
	pickers.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skin_row.add_child(pickers)
	pickers.add_child(_label("Personagem", 18, Color("2ce8f5")))
	for k in [["skin", "Pele", Skins.SKIN], ["hair", "Cabelo", Skins.HAIR], ["shirt", "Camisa", Skins.SHIRT]]:
		pickers.add_child(_picker(k[0], k[1], k[2]))

	_error = _label("", 16, Color("e43b44"))
	left.add_child(_error)
	var b1 := _button("Treino  ·  expediente livre, dias seguidos", _start.bind("treino", false))
	var b2 := _button("Avaliação  ·  1 expediente, gera relatório", _start.bind("avaliacao", false))
	b2.theme_type_variation = &"PrimaryButton"
	left.add_child(b1)
	left.add_child(b2)
	if saved.has("profile") and not saved.get("finished", false):
		var info := "Continuar: %s · %s · Dia %d · %d pts" % [saved.profile.name,
			"Avaliação" if saved.mode == "avaliacao" else "Treino", int(saved.state.day), int(saved.state.score)]
		left.add_child(_button(info, _start.bind(saved.mode, true)))

	# ---------------- coluna direita: placar
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.custom_minimum_size = Vector2(330, 0)
	cols.add_child(right)
	right.add_child(_label("PLACAR DESTE COMPUTADOR", 18, Color("feae34")))
	var board := SaveGame.board()
	if board.is_empty():
		right.add_child(_label("Ninguém jogou ainda.\nSeja o primeiro!", 16, Color("c0cbdc")))
	for i in board.size():
		var e: Dictionary = board[i]
		right.add_child(_label("%d. %s  %d pts  (nota %.1f)" % [i + 1, e.name, int(e.points), float(e.nota)],
			16, Color("fee761") if i == 0 else Color.WHITE))
		right.add_child(_label("    %s · %s · %s" % [e.turma if e.turma != "" else "sem turma",
			"avaliação" if e.mode == "avaliacao" else "treino", e.date], 13, Color("8b9bb4")))
	right.add_child(HSeparator.new())
	right.add_child(_label("Como pontuar:", 16, Color("2ce8f5")))
	right.add_child(_label("• 100 por chamado resolvido\n• até +100 se for rápido\n• +50 se for da Gerência\n• −25 por erro\n• sequência sem erro: até ×1,5\n• prazo estourado: −50", 15, Color("c0cbdc")))
	_update_preview()
	_name.grab_focus()


func _process(delta: float) -> void:
	_t += delta
	if _atlas:
		_atlas.region = Rect2(int(_t * 6.0) % 4 * 20, 0, 20, 34)


func _picker(key: String, title: String, options: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var t := _label(title, 16, Color("c0cbdc"))
	t.custom_minimum_size = Vector2(70, 0)
	h.add_child(t)
	h.add_child(_small_button("<", func(): _cycle(key, -1, options.size())))
	var v := _label("", 16, Color.WHITE)
	v.custom_minimum_size = Vector2(110, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(v)
	h.add_child(_small_button(">", func(): _cycle(key, 1, options.size())))
	_labels[key] = [v, options]
	return h


func _cycle(key: String, dir: int, n: int) -> void:
	profile[key] = posmod(int(profile[key]) + dir, n)
	_update_preview()


func _update_preview() -> void:
	_atlas.atlas = Skins.texture(profile.skin, profile.hair, profile.shirt)
	for key in _labels:
		_labels[key][0].text = _labels[key][1][int(profile[key])].name


func _start(mode: String, resume: bool) -> void:
	profile.name = _name.text.strip_edges()
	profile.class_code = _code.text.strip_edges().to_upper()
	if profile.name.length() < 2:
		_error.text = "Digite seu nome (é ele que vai no relatório e no placar)."
		_name.grab_focus()
		return
	if mode == "avaliacao" and profile.class_code == "" and not resume:
		_error.text = "Para a avaliação, digite o código da turma que o professor passou."
		_code.grab_focus()
		return
	start_requested.emit(profile.duplicate(), mode, resume)


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
	e.add_theme_font_size_override("font_size", 20)
	e.custom_minimum_size = Vector2(0, 40)
	return e


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b


func _small_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(36, 0)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b
