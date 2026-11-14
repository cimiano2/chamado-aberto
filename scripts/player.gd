class_name Player
extends Node2D
## Técnico de TI controlado pelo teclado. A posição é em coordenadas de MUNDO;
## o desenho (sprite isométrico) é feito pelo OfficeMap.
## As setas/WASD seguem a direção NA TELA: cima = sobe na tela.

## 339.4 un/s = exatamente 120 px/s na horizontal e 60 px/s na vertical da tela
## (2 px e 1 px por quadro a 60 FPS): rolagem em pixels inteiros, sem tremor.
@export var speed: float = 339.4
## Área dos pés usada na colisão (relativa à posição).
const FEET := Rect2(-14, -6, 28, 14)
const WALK_FPS := 8.0

var map: OfficeMap
var can_move := true
var facing := Vector2.DOWN        # direção na tela
var moving := false
var _walk := 0.0
## Rota (pontos no mundo) quando o jogador toca/clica no chão; o teclado cancela a rota.
var path := PackedVector2Array()
signal arrived


func walk_to(points: PackedVector2Array) -> void:
	path = points


func stop_walk() -> void:
	path.clear()


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
	if screen_dir != Vector2.ZERO:
		path.clear()
	elif can_move and not path.is_empty():
		_follow_path(delta)
		return
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


## Anda em direção ao próximo ponto da rota (toque/clique).
func _follow_path(delta: float) -> void:
	var to := path[0] - position
	var budget := speed * delta
	if to.length() <= budget:
		var before := position
		_try_move(Vector2(to.x, 0))
		_try_move(Vector2(0, to.y))
		path.remove_at(0)
		if position == before and to.length() > 0.5:
			path.clear()
		if path.is_empty():
			moving = false
			_walk = 0.0
			_update_map_pose()
			arrived.emit()
			return
	else:
		var before := position
		var step := to.normalized() * budget
		_try_move(Vector2(step.x, 0))
		_try_move(Vector2(0, step.y))
		if position == before:      # preso: desiste da rota
			path.clear()
	moving = not path.is_empty()
	# direção na tela para escolher o sprite (frente/costas, espelhado)
	facing = Vector2((to.x - to.y) / 4.0, (to.x + to.y) / 8.0).normalized()
	_walk += delta * WALK_FPS
	_update_map_pose()


func _update_map_pose() -> void:
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
