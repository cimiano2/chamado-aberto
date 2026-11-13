class_name Minimap
extends Control
## Mapa em miniatura do andar: salas, chamados abertos e posição do técnico.

var map: OfficeMap
var player: Node2D
var tickets: Array = []      # chamados abertos (TicketSystem.tickets)
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if map == null:
		return
	var s := minf(size.x / map.world_rect.size.x, size.y / map.world_rect.size.y)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.07, 0.85))
	for f in map.floors:
		draw_rect(Rect2(f.position * s, f.size * s), Color("3a4268"))
	var font: Font = get_theme_default_font()
	for room in map.rooms:
		var r: Rect2 = room.rect
		draw_string(font, r.position * s + Vector2(3, 11), room.name.substr(0, 4), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.45))
	for t in tickets:
		var d: Dictionary = map.desks[t.desk]
		var urgency: float = 1.0 - t.sla_left / t.sla_total
		var col := Color("ff5a5a") if urgency > 0.7 else (Color("ff4fa3") if t.priority else Color("ffd23f"))
		var pulse := 3.5 + 1.5 * sin(_t * 8.0)
		draw_circle(d.pos * s, pulse, col)
	if player:
		draw_circle(player.position * s, 4, Color("34e7e4"))
		draw_arc(player.position * s, 6, 0, TAU, 16, Color("34e7e4"), 1)
	draw_rect(Rect2(Vector2.ZERO, size), Color("2a3566"), false, 2)
