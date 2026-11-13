class_name Player
extends Node2D
## Técnico de TI controlado pelo teclado (WASD ou setas).
## Desenhado em código: camisa polo azul, crachá e headset.

@export var speed: float = 300.0
## Área dos pés usada na colisão (relativa à posição).
const FEET := Rect2(-14, -6, 28, 14)

var map: OfficeMap
var can_move := true
var facing := Vector2.DOWN
var _walk := 0.0
var _moving := false


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if can_move:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			dir.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			dir.x += 1
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			dir.y -= 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			dir.y += 1
	_moving = dir != Vector2.ZERO
	if _moving:
		dir = dir.normalized()
		facing = dir
		var step := dir * speed * delta
		# move eixo por eixo para "deslizar" nas paredes
		_try_move(Vector2(step.x, 0))
		_try_move(Vector2(0, step.y))
		_walk += delta * 12.0
	else:
		_walk = 0.0
	queue_redraw()


func _try_move(offset: Vector2) -> void:
	if offset == Vector2.ZERO:
		return
	var target := position + offset
	if map == null or map.is_walkable(Rect2(target + FEET.position, FEET.size)):
		position = target


func _draw() -> void:
	var swing := sin(_walk) * 5.0 if _moving else 0.0
	var side := facing.x < -0.3
	# sombra
	draw_set_transform(Vector2(0, 4), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 22, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# pernas
	draw_rect(Rect2(-11, -14 + swing * 0.4, 9, 18), Color("2b2f45"))
	draw_rect(Rect2(2, -14 - swing * 0.4, 9, 18), Color("2b2f45"))
	draw_rect(Rect2(-12, 2 + swing * 0.4, 11, 5), Color("111111"))
	draw_rect(Rect2(1, 2 - swing * 0.4, 11, 5), Color("111111"))
	# braços
	draw_rect(Rect2(-22, -40 - swing * 0.5, 8, 24), Color("1f5fd6"))
	draw_rect(Rect2(14, -40 + swing * 0.5, 8, 24), Color("1f5fd6"))
	draw_circle(Vector2(-18, -15 - swing * 0.5), 5, Color("e0ac69"))
	draw_circle(Vector2(18, -15 + swing * 0.5), 5, Color("e0ac69"))
	# tronco (polo azul) + gola
	draw_rect(Rect2(-15, -44, 30, 32), Color("2f74ff"))
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -44), Vector2(6, -44), Vector2(0, -36)]), Color("e8eefc"))
	var looking_up := facing.y < -0.5 and absf(facing.x) < 0.5
	if not looking_up:
		# crachá
		draw_line(Vector2(-5, -42), Vector2(-2, -30), Color("ffd23f"), 1)
		draw_rect(Rect2(-6, -31, 9, 11), Color("f5f5f5"))
		draw_rect(Rect2(-5, -30, 7, 3), Color("2f74ff"))
	# cabeça
	var head := Vector2(0, -58)
	draw_circle(head, 15, Color("e0ac69"))
	if looking_up:
		draw_circle(head, 15, Color("3a2416"))
	else:
		draw_arc(head + Vector2(0, -2), 15, PI * 1.05, TAU * 0.985, 14, Color("3a2416"), 9)
		var eye_dx := 3.0 * signf(facing.x) if absf(facing.x) > 0.3 else 0.0
		draw_circle(head + Vector2(-5 + eye_dx, 1), 2, Color("1a1a1a"))
		draw_circle(head + Vector2(5 + eye_dx, 1), 2, Color("1a1a1a"))
	# headset (marca do suporte)
	draw_arc(head, 17, PI * 1.1, TAU * 0.98, 16, Color("222222"), 3)
	var ear := Vector2(15, 0) if not side else Vector2(-15, 0)
	draw_circle(head + ear, 5, Color("222222"))
	draw_circle(head - ear, 5, Color("222222"))
	if not looking_up:
		draw_line(head + ear, head + Vector2(ear.x * 0.4, 12), Color("222222"), 2)
		draw_circle(head + Vector2(ear.x * 0.4, 12), 2.5, Color("34e7e4"))
