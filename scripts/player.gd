class_name Player
extends Node2D
## Técnico de TI controlado pelo teclado. A posição é em coordenadas de MUNDO;
## o desenho (sprite isométrico) é feito pelo OfficeMap.
## As setas/WASD seguem a direção NA TELA: cima = sobe na tela.

@export var speed: float = 300.0
## Área dos pés usada na colisão (relativa à posição).
const FEET := Rect2(-14, -6, 28, 14)
const WALK_FPS := 8.0

var map: OfficeMap
var can_move := true
var facing := Vector2.DOWN        # direção na tela
var moving := false
var _walk := 0.0


func _process(delta: float) -> void:
	var screen_dir := Vector2.ZERO
	if can_move:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			screen_dir.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			screen_dir.x += 1
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			screen_dir.y -= 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			screen_dir.y += 1
	moving = screen_dir != Vector2.ZERO
	if moving:
		facing = screen_dir
		var world_dir := screen_to_world_dir(screen_dir)
		var step := world_dir * speed * delta
		# move eixo por eixo para "deslizar" nas paredes
		_try_move(Vector2(step.x, 0))
		_try_move(Vector2(0, step.y))
		_walk += delta * WALK_FPS
	else:
		_walk = 0.0
	if map:
		map.player_back = facing.y < 0
		map.player_flip = facing.x < 0
		map.player_frame = (int(_walk) % 4) if moving else 0


## Converte uma direção na tela em direção no mundo (inverso da projeção 2:1).
static func screen_to_world_dir(d: Vector2) -> Vector2:
	# tela: sx = (x - y)/4, sy = (x + y)/8  →  x = 2sx + 4sy, y = -2sx + 4sy
	return Vector2(2.0 * d.x + 4.0 * d.y, -2.0 * d.x + 4.0 * d.y).normalized()


func _try_move(offset: Vector2) -> void:
	if offset == Vector2.ZERO:
		return
	var target := position + offset
	if map == null or map.is_walkable(Rect2(target + FEET.position, FEET.size)):
		position = target
