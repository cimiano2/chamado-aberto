class_name Guide
extends Node2D
## Seta em pixel art ao redor do técnico apontando para o chamado mais urgente (em isometria).

var player: Node2D
var target := Vector2.INF       # posição de MUNDO do chamado
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if player == null or target == Vector2.INF:
		return
	var from := OfficeMap.iso(player.position, 16)
	var to := OfficeMap.iso(target)
	var v := to - from
	if v.length() < 60.0:
		return
	var dir := v.normalized()
	var r := 22.0 + roundf(sin(_t * 6.0) * 2.0)
	var tip := (from + dir * (r + 7)).round()
	var base := from + dir * r
	var perp := Vector2(-dir.y, dir.x) * 5.0
	var pts := PackedVector2Array([tip, (base + perp).round(), (base - perp).round()])
	draw_colored_polygon(pts, Color("feae34"))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color("181425"), 1.0)
