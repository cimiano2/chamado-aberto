class_name Guide
extends Node2D
## Seta ao redor do técnico apontando para o chamado mais urgente.

var player: Node2D
var target := Vector2.INF
var color := Color("ffd23f")
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if player == null or target == Vector2.INF:
		return
	var from := player.position + Vector2(0, -30)
	var to_target := target - from
	if to_target.length() < 220.0:
		return
	var dir := to_target.normalized()
	var r := 64.0 + sin(_t * 6.0) * 4.0
	var tip := from + dir * (r + 16)
	var base := from + dir * r
	var perp := Vector2(-dir.y, dir.x) * 11.0
	draw_colored_polygon(PackedVector2Array([tip, base + perp, base - perp]), color)
	draw_polyline(PackedVector2Array([tip, base + perp, base - perp, tip]), Color(0, 0, 0, 0.6), 2)
