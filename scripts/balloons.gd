class_name Balloons
extends Control
## Balões de fala sobre os personagens (estilo chat de mundo isométrico):
## caixa branca com o nome em negrito, rabinho apontando para quem fala,
## sobem devagar e somem; falas novas do mesmo personagem empurram as antigas para cima.

const LIFETIME := 5.0
const FADE := 1.0
const RISE := 10.0          # px/s na tela

## Converte um ponto do mundo isométrico (pixels do canvas 640x360) para a tela cheia.
var to_screen: Callable
var _items: Array = []      # {node, anchor: Callable -> Vector2 (iso), age, lift, speaker}


func say(speaker: String, text: String, anchor: Callable, color := Color("262b44")) -> void:
	# empurra para cima as falas anteriores do mesmo personagem
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("ffffff")
	style.border_color = Color("181425")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.corner_detail = 2
	style.anti_aliasing = false
	style.set_content_margin_all(6)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_offset = Vector2(2, 3)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(min(320, 40 + (speaker.length() + text.length()) * 8), 0)
	label.add_theme_font_size_override("normal_font_size", 16)
	label.add_theme_font_size_override("bold_font_size", 16)
	label.add_theme_color_override("default_color", Color("181425"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "[b][color=#%s]%s:[/color][/b] %s" % [color.to_html(false), speaker, text]
	panel.add_child(label)
	var tail := Control.new()
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tail.draw.connect(func():
		var w := panel.size.x
		var pts := PackedVector2Array([Vector2(w / 2 - 6, panel.size.y - 2), Vector2(w / 2 + 6, panel.size.y - 2), Vector2(w / 2, panel.size.y + 7)])
		tail.draw_colored_polygon(pts, Color("ffffff"))
		tail.draw_polyline(PackedVector2Array([pts[0], pts[2], pts[1]]), Color("181425"), 2.0))
	panel.add_child(tail)
	add_child(panel)
	for it in _items:
		if it.speaker == speaker:
			it.lift += 42.0
	_items.append({"node": panel, "anchor": anchor, "age": 0.0, "lift": 0.0, "speaker": speaker, "tail": tail})
	# no máximo 6 balões na tela
	while _items.size() > 6:
		_items[0].node.queue_free()
		_items.pop_front()


func clear() -> void:
	for it in _items:
		it.node.queue_free()
	_items.clear()


func _process(delta: float) -> void:
	if not to_screen.is_valid():
		return
	for it in _items.duplicate():
		it.age += delta
		if it.age > LIFETIME:
			it.node.queue_free()
			_items.erase(it)
	# posição desejada de cada balão (sobre a cabeça de quem fala)
	var rects: Array[Rect2] = []
	for it in _items:
		var node: Control = it.node
		var base: Vector2 = to_screen.call(it.anchor.call())
		var y: float = base.y - node.size.y - 10.0 - it.lift - it.age * RISE
		rects.append(Rect2(Vector2(base.x - node.size.x / 2.0, y), node.size))
	# os mais novos ficam embaixo; os mais antigos sobem até não encostar em nenhum mais novo
	for i in range(rects.size() - 2, -1, -1):
		for j in range(i + 1, rects.size()):
			var a := rects[i]
			var b := rects[j]
			if a.grow(3).intersects(b):
				a.position.y = b.position.y - a.size.y - 6.0
				rects[i] = a
	for i in _items.size():
		var it: Dictionary = _items[i]
		it.node.position = rects[i].position.round()
		it.node.modulate.a = clampf((LIFETIME - it.age) / FADE, 0.0, 1.0)
		it.tail.queue_redraw()
