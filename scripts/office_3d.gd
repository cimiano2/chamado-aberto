class_name Office3D
extends Node3D
## Versão 3D do andar. Monta salas, paredes, móveis e pessoas a partir dos MESMOS dados do
## OfficeMap: colisão, mesas, chamados e rota continuam no mapa (só o desenho muda).
##
## Coordenadas: mundo (x, y) do mapa -> 3D (x, altura, y) em metros; 1 ladrilho (64) = 1 m.
## A câmera olha na mesma diagonal da vista isométrica 2D, então "cima" no teclado continua
## sendo "subir na tela" e o Player não precisa saber se o jogo está em 2D ou 3D.
## Estilo: low poly com cores chapadas da mesma paleta (endesga32) da pixel art.

const S := 1.0 / 64.0                 # metros por unidade do mapa
const PX := 0.05                      # metros por pixel de altura do desenho 2D (z do iso)
const WALL_H := {"back": 2.8, "glass": 2.2, "low": 1.1, "front": 0.35}
const CAM_OFFSET := Vector3(6.5, 9.5, 6.5)    # atrás/acima do técnico, na diagonal da vista 2D
const CAM_FOV := 42.0

## Piso de cada sala: duas cores (xadrez sutil por ladrilho).
const FLOOR := {
	"carpete": [Color("5a6988"), Color("51607d")], "gerente": [Color("8a3f7a"), Color("7b376d")],
	"reuniao": [Color("3a4466"), Color("343d5c")], "copa": [Color("ffffff"), Color("c0cbdc")],
	"ti": [Color("1f7fc2"), Color("1b72ae")], "anexo": [Color("3e8948"), Color("387c41")],
	"servidores": [Color("c0cbdc"), Color("aeb9cc")], "corredor": [Color("c0cbdc"), Color("b4bfd2")],
}
const WALL := Color("e4a672")
const WALL_TOP := Color("ead4aa")
const WOOD := Color("b86f50")
const DARK := Color("262b44")
const INK := Color("181425")

## Funcionários: as mesmas 8 aparências da pixel art (art/employees/build.py).
const E_SKIN := [Color("e8b796"), Color("e4a672"), Color("b86f50"), Color("c28569")]
const E_HAIR := [Color("3e2731"), Color("feae34"), Color("733e39"), Color("5a6988"), Color("be4a2f")]
const E_SHIRT := [Color("e43b44"), Color("63c74d"), Color("feae34"), Color("b55088"), Color("c0cbdc"), Color("f77622")]
const E_LOOKS := [[0, 0, 0, false], [1, 1, 1, true], [2, 0, 2, false], [0, 2, 3, true],
	[3, 3, 4, false], [1, 4, 5, true], [2, 1, 3, false], [0, 4, 1, true]]

var map: OfficeMap
var player: Player
var guide_target := Vector2.INF
var camera: Camera3D

var _mat: StandardMaterial3D           # cor por vértice (todo o cenário fixo numa malha só)
var _glass_mat: StandardMaterial3D
var _player_rig: Dictionary = {}
var _workers := {}                     # índice da mesa -> rig do funcionário
var _alerts := {}                      # índice da mesa -> {sprite, ring}
var _arrow: MeshInstance3D
var _tap_ring: MeshInstance3D
var _time := 0.0
var _walk := 0.0
var _cam_target := Vector3.ZERO
var _yaw := 0.0
var _parts := {}                       # nó -> SurfaceTool (peças de personagem juntadas por nó)


func setup(m: OfficeMap, p: Player) -> void:
	map = m
	player = p
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.roughness = 0.9
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glass_mat = StandardMaterial3D.new()
	_glass_mat.albedo_color = Color(0.62, 0.86, 1.0, 0.28)
	_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass_mat.roughness = 0.1
	_glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_build_environment()
	_build_static()
	_build_people()
	_build_markers()
	set_profile({"skin": 0, "hair": 0, "shirt": 0, "body": 0})
	snap_camera()


# ================================================================ conversões

static func to3(p: Vector2, h: float = 0.0) -> Vector3:
	return Vector3(p.x * S, h, p.y * S)


## Ponto do mundo (altura em metros) -> posição na SubViewport 3D.
func point_screen(p: Vector2, h: float) -> Vector2:
	return camera.unproject_position(to3(p, h))


## Toque/clique na SubViewport 3D -> ponto do chão no mundo do mapa.
func screen_to_ground(pos: Vector2) -> Vector2:
	var o := camera.project_ray_origin(pos)
	var d := camera.project_ray_normal(pos)
	if absf(d.y) < 0.0001:
		return Vector2.INF
	var hit := o + d * (-o.y / d.y)
	return Vector2(hit.x, hit.z) / S


## Mesa (móvel ou pessoa) sob o toque; -1 se nenhuma.
func desk_at_screen(pos: Vector2) -> int:
	var ground := screen_to_ground(pos)
	var best := -1
	var best_d := INF
	var radius := 70.0 * get_viewport().get_visible_rect().size.y / 720.0
	for i in map.desks.size():
		var d: Dictionary = map.desks[i]
		var head := point_screen(d.center + Vector2(24, -44), 1.2 if not d.server else 1.4)
		var dist := head.distance_to(pos)
		var r: Rect2 = d.rect
		if ground != Vector2.INF and r.grow(24).has_point(ground):
			dist = minf(dist, 1.0)
		if dist < radius and dist < best_d:
			best_d = dist
			best = i
	return best


## Onde ancorar o balão de fala de quem está na mesa i.
func speaker_screen(i: int) -> Vector2:
	var d: Dictionary = map.desks[i]
	if d.server:
		return point_screen(d.center, 2.6)
	return point_screen(d.center + Vector2(24, -44), 2.05)


func head_screen() -> Vector2:
	return point_screen(player.position, 2.15)


# ================================================================ câmera

func snap_camera() -> void:
	_cam_target = to3(player.position)
	_place_camera()


func _place_camera() -> void:
	camera.position = _cam_target + CAM_OFFSET
	camera.look_at(_cam_target + Vector3(0, 0.6, 0), Vector3.UP)


# ================================================================ quadro a quadro

func _process(delta: float) -> void:
	if map == null:
		return
	_time += delta
	# câmera segue o técnico com suavidade (no 3D não há grade de pixels para respeitar)
	var goal := to3(player.position)
	_cam_target = _cam_target.lerp(goal, 1.0 - exp(-8.0 * delta))
	_place_camera()
	_update_player(delta)
	_update_people()
	_update_markers(delta)


func _update_player(delta: float) -> void:
	var rig: Node3D = _player_rig.root
	rig.position = to3(player.position)
	var wd := Player.screen_to_world_dir(player.facing)
	if wd != Vector2.ZERO:
		var want := atan2(wd.x, wd.y)
		_yaw = lerp_angle(_yaw, want, 1.0 - exp(-14.0 * delta))
	rig.rotation.y = _yaw
	if player.moving:
		_walk += delta * 10.0
	else:
		_walk = lerpf(_walk, roundf(_walk / PI) * PI, 1.0 - exp(-12.0 * delta))
	var sw := sin(_walk) * (0.6 if player.moving else 0.0)
	_player_rig.leg_l.rotation.x = sw
	_player_rig.leg_r.rotation.x = -sw
	_player_rig.arm_l.rotation.x = -sw * 0.8
	_player_rig.arm_r.rotation.x = sw * 0.8
	_player_rig.body.position.y = absf(sin(_walk)) * 0.04 if player.moving else 0.0


func _update_people() -> void:
	for i in _workers:
		var w: Dictionary = _workers[i]
		var has_ticket := map.ticket_desks.has(i)
		# quem abriu chamado levanta o braço e acena (como na pixel art)
		if has_ticket:
			w.arm_r.rotation.x = -2.7
			w.arm_r.rotation.z = sin(_time * 7.0 + i) * 0.35
		else:
			w.arm_r.rotation.x = -0.35 + sin(_time * 9.0 + i * 1.7) * 0.06    # digitando
			w.arm_r.rotation.z = 0.0
		w.arm_l.rotation.x = -0.35 + sin(_time * 9.0 + i * 1.7 + 1.5) * 0.06


func _update_markers(delta: float) -> void:
	for i in _alerts:
		var a: Dictionary = _alerts[i]
		var info: Variant = map.ticket_desks.get(i)
		var on := info != null
		a.sprite.visible = on
		a.ring.visible = on
		if not on:
			continue
		var urgency: float = info.urgency
		var key := "alert_urgent" if urgency > 0.66 else ("alert_high" if info.priority else "alert")
		a.sprite.region_rect = (map.TEX[key] as AtlasTexture).region
		a.sprite.position.y = a.base_h + sin(_time * 4.0 + i) * 0.08
		var col := Color("63c74d").lerp(Color("feae34"), clampf(urgency * 2.0, 0.0, 1.0))
		if urgency > 0.5:
			col = Color("feae34").lerp(Color("e43b44"), clampf((urgency - 0.5) * 2.0, 0.0, 1.0))
		(a.ring.material_override as StandardMaterial3D).albedo_color = col
		var pulse := 1.0 + 0.12 * sin(_time * 6.0)
		a.ring.scale = Vector3(pulse, 1.0, pulse)
	# seta do chamado mais urgente, girando em volta do técnico
	var show_arrow := guide_target != Vector2.INF and player.position.distance_to(guide_target) > 120.0
	_arrow.visible = show_arrow
	if show_arrow:
		var dir := (guide_target - player.position).normalized()
		var p := player.position + dir * 70.0
		_arrow.position = to3(p, 0.06 + 0.04 * sin(_time * 5.0))
		_arrow.rotation.y = atan2(dir.x, dir.y)
	# marca do toque no chão
	_tap_ring.visible = map.tap_marker_t > 0.0
	if _tap_ring.visible:
		var k := map.tap_marker_t / 0.6
		_tap_ring.position = to3(map.tap_marker, 0.03)
		var s := 0.6 + (1.0 - k) * 0.8
		_tap_ring.scale = Vector3(s, 1.0, s)
		(_tap_ring.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.85, 0.25, k)


# ================================================================ técnico

## Aparência do técnico: as mesmas escolhas do menu (estilo, pele, cabelo, camisa).
func set_profile(profile: Dictionary) -> void:
	if not _player_rig.is_empty():
		_player_rig.root.queue_free()
	var skin: Color = Skins.SKIN[int(profile.get("skin", 0))].c[0]
	var hair: Color = Skins.HAIR[int(profile.get("hair", 0))].c[1]
	var shirt: Color = Skins.SHIRT[int(profile.get("shirt", 0))].c[1]
	var fem := int(profile.get("body", 0)) == 1
	_player_rig = _person(skin, hair, shirt, fem, false, true)
	add_child(_player_rig.root)


# ================================================================ montagem

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("181425")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("c0cbdc")
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	# luz do alto à esquerda, como na pixel art
	sun.rotation_degrees = Vector3(-55, -135, 0)
	sun.light_energy = 0.85
	# sem sombra em tempo real (custa muito em placa fraca e celular): os móveis e as pessoas
	# têm uma sombra suave fixa no chão (_shadow), que dá a mesma noção de apoio
	sun.shadow_enabled = false
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = CAM_FOV
	camera.near = 0.5
	camera.far = 80.0
	camera.current = true
	add_child(camera)


## Todo o cenário fixo (pisos, paredes, móveis) vira UMA malha com cor por vértice:
## poucas chamadas de desenho, importante para celular e computadores fracos.
func _build_static() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glass := SurfaceTool.new()
	glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shade := SurfaceTool.new()
	shade.begin(Mesh.PRIMITIVE_TRIANGLES)
	# chão escuro em volta (o andar "flutua" como na vista 2D)
	_box(st, Vector3(map.world_rect.get_center().x * S, -0.11, map.world_rect.get_center().y * S),
		Vector3(map.world_rect.size.x * S + 0.4, 0.2, map.world_rect.size.y * S + 0.4), INK)
	# pisos, ladrilho por ladrilho (xadrez sutil)
	for room in map.rooms:
		_floor(st, room.rect, FLOOR.get(room.floor, FLOOR.corredor))
	for d in map.doors:
		_floor(st, d, FLOOR.corredor)
	# paredes
	var cells := {}
	for w in map.walls:
		cells[Vector2i(w.rect.position / OfficeMap.TILE)] = w.kind
	for w in map.walls:
		var r: Rect2 = w.rect
		var h: float = WALL_H[w.kind]
		var c := to3(r.get_center(), h / 2.0)
		if w.kind == "low":
			_thin_wall(st, Vector2i(r.position / OfficeMap.TILE), h, cells)
			continue
		if w.kind == "glass":
			_box(glass, c, Vector3(r.size.x * S, h, r.size.y * S * 0.25), Color.WHITE)
			_box(st, Vector3(c.x, h, c.z), Vector3(r.size.x * S, 0.06, r.size.y * S * 0.3), DARK)   # caixilho
			_box(st, Vector3(c.x, 0.04, c.z), Vector3(r.size.x * S, 0.08, r.size.y * S * 0.3), DARK)
			continue
		_box(st, c, Vector3(r.size.x * S, h, r.size.y * S), WALL, WALL_TOP)
		if w.sprite == "wall_back_win_s":
			_window(st, Vector3(c.x, 1.55, r.end.y * S + 0.01), true)
		elif w.sprite == "wall_back_win_e":
			_window(st, Vector3(r.end.x * S + 0.01, 1.55, c.z), false)
	# móveis (com sombra suave no chão, deslocada para longe da luz)
	for d in map.desks:
		_furniture(st, d.sprite, d.center)
		_shadow(shade, d.center, OfficeMap.FOOT[d.sprite])
		if d.sprite == "desk" or d.sprite == "reception":
			_chair(st, d.center + Vector2(24, -FOOT_Y(d.sprite) / 2.0 - 22))
			_shadow(shade, d.center + Vector2(24, -FOOT_Y(d.sprite) / 2.0 - 22), Vector2(44, 40))
	for p in map.props:
		_furniture(st, p.kind, p.center)
		var k: String = "desk" if p.kind == "desk_empty" else p.kind
		if OfficeMap.FOOT.has(k):
			_shadow(shade, p.center, OfficeMap.FOOT[k])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat
	add_child(mi)
	var si := MeshInstance3D.new()
	si.mesh = shade.commit()
	si.material_override = _shadow_mat()
	add_child(si)
	var gi := MeshInstance3D.new()
	gi.mesh = glass.commit()
	gi.material_override = _glass_mat
	gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gi)


## Divisória interna fina (30 cm): um pilar no centro do ladrilho e braços até as paredes
## vizinhas; o resto do ladrilho vira piso. A colisão continua sendo o ladrilho inteiro.
func _thin_wall(st: SurfaceTool, t: Vector2i, h: float, cells: Dictionary) -> void:
	var x0 := float(t.x)
	var z0 := float(t.y)
	var fc: Color = FLOOR.corredor[1]
	_quad(st, Vector3(x0, 0, z0), Vector3(x0 + 1, 0, z0), Vector3(x0 + 1, 0, z0 + 1), Vector3(x0, 0, z0 + 1), Vector3.UP, fc)
	var c := Vector3(x0 + 0.5, h / 2.0, z0 + 0.5)
	var th := 0.3
	_box(st, c, Vector3(th, h, th), WALL, WALL_TOP)
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not cells.has(t + dir):
			continue
		var off := Vector3(dir.x * 0.25 + dir.x * 0.0, 0, dir.y * 0.25)
		var size := Vector3(0.5 if dir.x != 0 else th, h, 0.5 if dir.y != 0 else th)
		_box(st, c + off, size, WALL, WALL_TOP)


## Sombra suave: retângulo escuro translúcido no chão, um pouco maior que a pegada e
## deslocado para a direita/baixo da tela (a luz vem do alto à esquerda).
func _shadow(st: SurfaceTool, center: Vector2, foot: Vector2) -> void:
	var c := to3(center, 0.012) + Vector3(0.1, 0, 0.0)
	var h := Vector3(foot.x * S / 2.0 + 0.08, 0, foot.y * S / 2.0 + 0.08)
	st.set_normal(Vector3.UP)
	st.set_color(Color(0, 0, 0, 0.28))
	for v in [Vector3(-h.x, 0, -h.z), Vector3(h.x, 0, -h.z), Vector3(h.x, 0, h.z),
			Vector3(-h.x, 0, -h.z), Vector3(h.x, 0, h.z), Vector3(-h.x, 0, h.z)]:
		st.add_vertex(c + v)


func _shadow_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func FOOT_Y(kind: String) -> float:
	return OfficeMap.FOOT[kind].y


func _floor(st: SurfaceTool, r: Rect2, cols: Array) -> void:
	var tx0 := int(r.position.x / OfficeMap.TILE)
	var ty0 := int(r.position.y / OfficeMap.TILE)
	for ty in int(r.size.y / OfficeMap.TILE):
		for tx in int(r.size.x / OfficeMap.TILE):
			var x0 := (tx0 + tx) * 1.0
			var z0 := (ty0 + ty) * 1.0
			var col: Color = cols[(tx0 + tx + ty0 + ty) % 2]
			_quad(st, Vector3(x0, 0, z0), Vector3(x0 + 1, 0, z0), Vector3(x0 + 1, 0, z0 + 1), Vector3(x0, 0, z0 + 1), Vector3.UP, col)


func _window(st: SurfaceTool, c: Vector3, facing_z: bool) -> void:
	var w := Vector3(0.62, 1.1, 0.03) if facing_z else Vector3(0.03, 1.1, 0.62)
	_box(st, c, w + (Vector3(0.08, 0.08, 0.0) if facing_z else Vector3(0.0, 0.08, 0.08)), Color("ead4aa"))
	_box(st, c + (Vector3(0, 0, 0.01) if facing_z else Vector3(0.01, 0, 0)), w, Color("0099db"))
	for k in 4:   # persiana
		var y := c.y + 0.4 - k * 0.26
		var off := Vector3(0, 0, 0.025) if facing_z else Vector3(0.025, 0, 0)
		_box(st, Vector3(c.x, y, c.z) + off, Vector3(0.6, 0.035, 0.01) if facing_z else Vector3(0.01, 0.035, 0.6), Color("c0cbdc"))


func _chair(st: SurfaceTool, p: Vector2) -> void:
	var c := to3(p)
	_box(st, c + Vector3(0, 0.22, 0), Vector3(0.08, 0.44, 0.08), DARK)
	_box(st, c + Vector3(0, 0.46, 0), Vector3(0.5, 0.08, 0.48), Color("3a4466"))
	_box(st, c + Vector3(0, 0.78, -0.22), Vector3(0.48, 0.6, 0.07), Color("3a4466"))


## Móvel low poly a partir da pegada (OfficeMap.FOOT) — o desenho bate com a colisão.
func _furniture(st: SurfaceTool, kind: String, center: Vector2) -> void:
	var k := "desk" if kind == "desk_empty" else kind
	if not OfficeMap.FOOT.has(k):
		return
	var f: Vector2 = OfficeMap.FOOT[k] * S
	var c := to3(center)
	match k:
		"desk":
			_box(st, c + Vector3(0, 0.73, 0), Vector3(f.x, 0.05, f.y), WOOD, Color("c28569"))
			for sx in [-1, 1]:
				_box(st, c + Vector3(sx * (f.x / 2 - 0.04), 0.355, 0), Vector3(0.05, 0.71, f.y - 0.06), Color("733e39"))
			_box(st, c + Vector3(0, 0.45, -f.y / 2 + 0.03), Vector3(f.x - 0.1, 0.45, 0.03), Color("733e39"))
			# monitor virado para quem senta (lado norte), teclado e papéis
			_box(st, c + Vector3(0.5, 0.78, 0.05), Vector3(0.18, 0.06, 0.14), DARK)
			_box(st, c + Vector3(0.5, 0.98, 0.06), Vector3(0.62, 0.38, 0.05), DARK)
			_box(st, c + Vector3(0.5, 0.98, 0.03), Vector3(0.55, 0.31, 0.01), Color("2ce8f5"))
			_box(st, c + Vector3(0.45, 0.765, -0.14), Vector3(0.42, 0.02, 0.13), Color("c0cbdc"))
			_box(st, c + Vector3(-0.7, 0.77, 0.0), Vector3(0.3, 0.03, 0.22), Color("ffffff"))
		"reception":
			_box(st, c + Vector3(0, 0.52, 0.06), Vector3(f.x, 1.04, f.y - 0.12), Color("733e39"), Color("c28569"))
			_box(st, c + Vector3(0, 0.74, -0.12), Vector3(f.x - 0.1, 0.05, f.y * 0.5), WOOD)
			_box(st, c + Vector3(0.6, 0.98, -0.15), Vector3(0.5, 0.34, 0.05), DARK)
			_box(st, c + Vector3(0.6, 0.98, -0.18), Vector3(0.44, 0.28, 0.01), Color("2ce8f5"))
		"conference_table":
			_box(st, c + Vector3(0, 0.73, 0), Vector3(f.x, 0.06, f.y), WOOD, Color("c28569"))
			_box(st, c + Vector3(0, 0.36, 0), Vector3(f.x * 0.6, 0.7, 0.3), Color("733e39"))
			for i in 4:
				var x := -f.x / 2 + 0.5 + i * (f.x - 1.0) / 3.0
				for sz in [-1, 1]:
					var p := c + Vector3(x, 0, sz * (f.y / 2 + 0.3))
					_box(st, p + Vector3(0, 0.45, 0), Vector3(0.42, 0.08, 0.42), DARK)
					_box(st, p + Vector3(0, 0.72, sz * 0.19), Vector3(0.42, 0.5, 0.06), DARK)
			_box(st, c + Vector3(0, 0.8, 0), Vector3(0.3, 0.08, 0.2), DARK)    # telefone/projetor
		"rack":
			_box(st, c + Vector3(0, 0.8, 0), Vector3(f.x * 0.8, 1.6, f.y * 0.8), DARK, Color("3a4466"))
			for i in 6:
				var y := 0.35 + i * 0.22
				_box(st, c + Vector3(0, y, f.y * 0.4 + 0.005), Vector3(f.x * 0.66, 0.14, 0.01), Color("3a4466"))
				_box(st, c + Vector3(f.x * 0.25, y, f.y * 0.4 + 0.012), Vector3(0.05, 0.03, 0.01), Color("63c74d") if i % 3 else Color("2ce8f5"))
		"plant":
			_prism(st, c, 0.17, 0.36, 8, Color("be4a2f"), Color("733e39"))
			_box(st, c + Vector3(0, 0.62, 0), Vector3(0.42, 0.5, 0.42), Color("3e8948"))
			_box(st, c + Vector3(0.05, 0.92, -0.04), Vector3(0.32, 0.32, 0.32), Color("63c74d"))
			_box(st, c + Vector3(-0.12, 0.75, 0.1), Vector3(0.22, 0.26, 0.22), Color("63c74d"))
		"cooler":
			_box(st, c + Vector3(0, 0.45, 0), Vector3(0.34, 0.9, 0.34), Color("c0cbdc"))
			_prism(st, c + Vector3(0, 0.9, 0), 0.14, 0.38, 8, Color("2ce8f5"), Color("0099db"))
		"vending":
			_box(st, c + Vector3(0, 0.9, 0), Vector3(f.x, 1.8, f.y), Color("a22633"), Color("e43b44"))
			_box(st, c + Vector3(-0.08, 1.05, f.y / 2 + 0.01), Vector3(f.x * 0.6, 1.1, 0.02), Color("2ce8f5"))
			for i in 4:
				_box(st, c + Vector3(-0.08, 0.65 + i * 0.27, f.y / 2 + 0.025), Vector3(f.x * 0.55, 0.05, 0.02), Color("feae34"))
		"fridge":
			_box(st, c + Vector3(0, 0.9, 0), Vector3(f.x, 1.8, f.y), Color("ffffff"), Color("c0cbdc"))
			_box(st, c + Vector3(0.24, 1.2, f.y / 2 + 0.02), Vector3(0.04, 0.4, 0.03), Color("8b9bb4"))
			_box(st, c + Vector3(0, 1.25, f.y / 2 + 0.005), Vector3(f.x, 0.02, 0.01), Color("8b9bb4"))
		"counter":
			_box(st, c + Vector3(0, 0.45, 0), Vector3(f.x, 0.9, f.y), Color("8b9bb4"), Color("ffffff"))
			_box(st, c + Vector3(-0.8, 0.91, 0), Vector3(0.5, 0.03, 0.4), Color("c0cbdc"))
			_box(st, c + Vector3(0.9, 1.05, -0.1), Vector3(0.35, 0.28, 0.25), DARK)   # micro-ondas
			_box(st, c + Vector3(0.3, 1.0, -0.05), Vector3(0.14, 0.2, 0.14), Color("e43b44"))  # cafeteira
		"kitchen_table":
			_box(st, c + Vector3(0, 0.73, 0), Vector3(f.x, 0.05, f.y), Color("ead4aa"))
			_box(st, c + Vector3(0, 0.36, 0), Vector3(0.1, 0.7, 0.1), Color("8b9bb4"))
			for o in [Vector3(-0.7, 0, 0), Vector3(0.7, 0, 0)]:
				_box(st, c + o + Vector3(0, 0.45, 0), Vector3(0.36, 0.06, 0.36), Color("e43b44"))
				_box(st, c + o + Vector3(0, 0.22, 0), Vector3(0.06, 0.44, 0.06), Color("8b9bb4"))
		"filing":
			_box(st, c + Vector3(0, 0.55, 0), Vector3(f.x, 1.1, f.y), Color("8b9bb4"), Color("c0cbdc"))
			for i in 3:
				_box(st, c + Vector3(0, 0.25 + i * 0.32, f.y / 2 + 0.005), Vector3(f.x * 0.8, 0.02, 0.01), Color("5a6988"))
		"copier":
			_box(st, c + Vector3(0, 0.5, 0), Vector3(f.x, 1.0, f.y), Color("c0cbdc"), Color("5a6988"))
			_box(st, c + Vector3(0.1, 1.02, 0), Vector3(f.x * 0.6, 0.04, f.y * 0.7), Color("ffffff"))
		"sofa":
			_box(st, c + Vector3(0, 0.22, 0.06), Vector3(f.x, 0.44, f.y - 0.12), Color("3a4466"), Color("5a6988"))
			_box(st, c + Vector3(0, 0.55, -f.y / 2 + 0.1), Vector3(f.x, 0.7, 0.2), Color("3a4466"))
			for sx in [-1, 1]:
				_box(st, c + Vector3(sx * (f.x / 2 - 0.08), 0.42, 0.06), Vector3(0.16, 0.42, f.y - 0.12), Color("3a4466"))
		"workbench":
			_box(st, c + Vector3(0, 0.86, 0), Vector3(f.x, 0.06, f.y), Color("733e39"), WOOD)
			for sx in [-1, 1]:
				_box(st, c + Vector3(sx * (f.x / 2 - 0.05), 0.42, 0), Vector3(0.06, 0.84, f.y - 0.06), DARK)
			_box(st, c + Vector3(-0.6, 1.05, 0), Vector3(0.45, 0.32, 0.4), Color("5a6988"))   # gabinete aberto
			_box(st, c + Vector3(0.2, 0.93, 0.05), Vector3(0.3, 0.08, 0.2), Color("3e8948"))   # placa-mãe
			_box(st, c + Vector3(0.75, 0.95, -0.05), Vector3(0.25, 0.12, 0.18), Color("feae34"))  # caixa de peças
		"shelf":
			_box(st, c + Vector3(0, 0.9, 0), Vector3(f.x, 1.8, f.y), Color("5a6988"))
			for i in 4:
				var y := 0.3 + i * 0.45
				_box(st, c + Vector3(0, y, 0.01), Vector3(f.x - 0.06, 0.03, f.y), Color("8b9bb4"))
				for j in 3:
					var col: Color = [Color("feae34"), Color("e43b44"), Color("0099db"), Color("63c74d")][(i + j) % 4]
					_box(st, c + Vector3(-f.x / 2 + 0.25 + j * 0.5, y + 0.14, 0.02), Vector3(0.3, 0.25, f.y * 0.7), col)
		"ups":
			_box(st, c + Vector3(0, 0.32, 0), Vector3(f.x, 0.64, f.y), DARK, Color("3a4466"))
			_box(st, c + Vector3(0, 0.5, f.y / 2 + 0.005), Vector3(0.08, 0.04, 0.01), Color("63c74d"))
		_:
			_box(st, c + Vector3(0, 0.4, 0), Vector3(f.x, 0.8, f.y), Color("8b9bb4"))


func _build_people() -> void:
	for i in map.desks.size():
		var d: Dictionary = map.desks[i]
		if d.server or int(d.look) < 0 and d.sprite != "conference_table":
			continue
		var look: Array = E_LOOKS[int(d.look) % 8] if int(d.look) >= 0 else E_LOOKS[(i * 3) % 8]
		var rig := _person(E_SKIN[look[0]], E_HAIR[look[1]], E_SHIRT[look[2]], look[3], true, false)
		var seat: Vector2 = d.center + Vector2(24, -FOOT_Y(d.sprite) / 2.0 - 22)
		if d.sprite == "conference_table":
			seat = d.center + Vector2(0, -FOOT_Y(d.sprite) / 2.0 - 19)
		rig.root.position = to3(seat)
		add_child(rig.root)
		_workers[i] = rig


func _build_markers() -> void:
	for i in map.desks.size():
		var d: Dictionary = map.desks[i]
		var spr := Sprite3D.new()
		spr.texture = OfficeMap.ATLAS
		spr.region_enabled = true
		spr.region_rect = (map.TEX["alert"] as AtlasTexture).region
		spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		spr.pixel_size = 0.05
		spr.no_depth_test = true
		spr.render_priority = 10
		spr.shaded = false
		var head: Vector2 = d.center + Vector2(24, -44) if not d.server else d.center
		var base_h := 2.2 if d.server else 1.95
		spr.position = to3(head, base_h)
		spr.visible = false
		add_child(spr)
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.42
		tm.outer_radius = 0.52
		tm.rings = 24
		tm.ring_segments = 4
		ring.mesh = tm
		ring.scale = Vector3.ONE
		var rm := StandardMaterial3D.new()
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.albedo_color = Color("63c74d")
		ring.material_override = rm
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.position = to3(d.pos, 0.03)
		ring.visible = false
		add_child(ring)
		_alerts[i] = {"sprite": spr, "ring": ring, "base_h": base_h}
	# seta-guia (chamado mais urgente)
	_arrow = MeshInstance3D.new()
	var ast := SurfaceTool.new()
	ast.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tip := Vector3(0, 0, 0.42)
	var l := Vector3(-0.28, 0, 0.05)
	var r := Vector3(0.28, 0, 0.05)
	ast.set_normal(Vector3.UP)
	for v in [l, tip, r, Vector3(-0.11, 0, 0.06), Vector3(0.11, 0, 0.06), Vector3(0.11, 0, -0.3),
			Vector3(-0.11, 0, 0.06), Vector3(0.11, 0, -0.3), Vector3(-0.11, 0, -0.3)]:
		ast.add_vertex(v)
	_arrow.mesh = ast.commit()
	var am := StandardMaterial3D.new()
	am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	am.albedo_color = Color("fee761")
	am.cull_mode = BaseMaterial3D.CULL_DISABLED
	_arrow.material_override = am
	_arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_arrow)
	_tap_ring = MeshInstance3D.new()
	var tt := TorusMesh.new()
	tt.inner_radius = 0.18
	tt.outer_radius = 0.24
	tt.ring_segments = 4
	_tap_ring.mesh = tt
	var tmat := StandardMaterial3D.new()
	tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tmat.albedo_color = Color("fee761")
	_tap_ring.material_override = tmat
	_tap_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tap_ring.visible = false
	add_child(_tap_ring)


## Personagem low poly: pernas, tronco, braços (com pivô no ombro), cabeça, cabelo e olhos.
## Sentado: coxas para a frente e tronco mais baixo. Olha para +z.
func _person(skin: Color, hair: Color, shirt: Color, long_hair: bool, seated: bool, is_player: bool) -> Dictionary:
	var root := Node3D.new()
	var body := Node3D.new()
	root.add_child(body)
	var blob := SurfaceTool.new()
	blob.begin(Mesh.PRIMITIVE_TRIANGLES)
	_shadow(blob, Vector2.ZERO, Vector2(30, 26))
	var bm := MeshInstance3D.new()
	bm.mesh = blob.commit()
	bm.material_override = _shadow_mat()
	root.add_child(bm)
	var pants := Color("3a4466")
	var hip := 0.47 if seated else 0.8
	var rig := {"root": root, "body": body}
	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.1, hip, 0)
		body.add_child(leg)
		if seated:
			_part(leg, Vector3(0, 0, 0.2), Vector3(0.15, 0.15, 0.42), pants)
			_part(leg, Vector3(0, -0.22, 0.4), Vector3(0.14, 0.45, 0.15), pants)
			_part(leg, Vector3(0, -0.44, 0.45), Vector3(0.15, 0.07, 0.24), INK)
		else:
			_part(leg, Vector3(0, -0.38, 0), Vector3(0.15, 0.76, 0.17), pants)
			_part(leg, Vector3(0, -0.77, 0.04), Vector3(0.16, 0.07, 0.25), INK)
		rig["leg_l" if side < 0 else "leg_r"] = leg
	var torso_h := 0.55
	_part(body, Vector3(0, hip + torso_h / 2, 0), Vector3(0.44, torso_h, 0.25), shirt)
	_part(body, Vector3(0, hip + torso_h - 0.05, 0.13), Vector3(0.16, 0.12, 0.01), Color("ffffff"))   # gola
	if is_player:
		# crachá e headset: o técnico de TI
		_part(body, Vector3(0.12, hip + 0.35, 0.13), Vector3(0.08, 0.1, 0.01), Color("ffffff"))
	for side in [-1, 1]:
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.29, hip + torso_h - 0.04, 0)
		body.add_child(arm)
		_part(arm, Vector3(0, -0.24, 0), Vector3(0.12, 0.48, 0.14), shirt)
		_part(arm, Vector3(0, -0.52, 0), Vector3(0.11, 0.1, 0.12), skin)
		rig["arm_l" if side < 0 else "arm_r"] = arm
	var head_y := hip + torso_h + 0.19
	_part(body, Vector3(0, hip + torso_h + 0.03, 0), Vector3(0.12, 0.06, 0.12), skin)
	_part(body, Vector3(0, head_y, 0), Vector3(0.32, 0.32, 0.3), skin)
	for side in [-1, 1]:
		_part(body, Vector3(side * 0.075, head_y + 0.01, 0.151), Vector3(0.05, 0.06, 0.01), INK)
	_part(body, Vector3(0, head_y + 0.17, -0.02), Vector3(0.35, 0.09, 0.35), hair)
	_part(body, Vector3(0, head_y + 0.02, -0.16), Vector3(0.35, 0.3, 0.05), hair)
	if long_hair:
		_part(body, Vector3(0, head_y - 0.18, -0.16), Vector3(0.34, 0.32, 0.06), hair)
		for side in [-1, 1]:
			_part(body, Vector3(side * 0.17, head_y - 0.05, -0.02), Vector3(0.04, 0.34, 0.2), hair)
	if is_player:
		_part(body, Vector3(0, head_y + 0.12, 0), Vector3(0.37, 0.04, 0.05), DARK)         # headset
		_part(body, Vector3(-0.18, head_y, 0), Vector3(0.05, 0.12, 0.1), DARK)
		_part(body, Vector3(-0.15, head_y - 0.08, 0.1), Vector3(0.02, 0.02, 0.14), DARK)   # microfone
	_flush_parts()
	return rig


## Peça de personagem: vai para a malha do nó (tronco, cada braço, cada perna). Cada pessoa
## vira poucas malhas em vez de uma por peça — bem mais leve no celular.
func _part(parent: Node3D, pos: Vector3, size: Vector3, col: Color) -> void:
	if not _parts.has(parent):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_parts[parent] = st
	_box(_parts[parent], pos, size, col)


func _flush_parts() -> void:
	for node in _parts:
		var mi := MeshInstance3D.new()
		mi.mesh = (_parts[node] as SurfaceTool).commit()
		mi.material_override = _mat
		node.add_child(mi)
	_parts.clear()


# ================================================================ geometria

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color) -> void:
	st.set_normal(n)
	st.set_color(col.srgb_to_linear())    # paleta em sRGB -> espaço linear da iluminação
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)


## Caixa com cor por vértice; o topo pode ter outra cor (tampo, borda da parede).
func _box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color, top := Color(0, 0, 0, 0)) -> void:
	var h := s / 2.0
	var x0 := c.x - h.x
	var x1 := c.x + h.x
	var y0 := c.y - h.y
	var y1 := c.y + h.y
	var z0 := c.z - h.z
	var z1 := c.z + h.z
	_quad(st, Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3.UP, col if top.a == 0.0 else top)
	_quad(st, Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3.DOWN, col.darkened(0.3))
	_quad(st, Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3.RIGHT, col)
	_quad(st, Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3(x0, y0, z1), Vector3.LEFT, col)
	_quad(st, Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y0, z1), Vector3.BACK, col)
	_quad(st, Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0), Vector3.FORWARD, col)


## Prisma (cilindro low poly) apoiado no chão em `base`.
func _prism(st: SurfaceTool, base: Vector3, radius: float, height: float, sides: int, col: Color, top: Color) -> void:
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := Vector3(cos(a0) * radius, 0, sin(a0) * radius)
		var p1 := Vector3(cos(a1) * radius, 0, sin(a1) * radius)
		var n := Vector3(cos((a0 + a1) / 2), 0, sin((a0 + a1) / 2))
		var up := Vector3(0, height, 0)
		_quad(st, base + p0, base + p1, base + p1 + up, base + p0 + up, n, col)
		st.set_normal(Vector3.UP)
		st.set_color(top.srgb_to_linear())
		for v in [base + up, base + p0 + up, base + p1 + up]:
			st.add_vertex(v)
