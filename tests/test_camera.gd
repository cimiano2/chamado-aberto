extends SceneTree
## Mede o tremor da câmera: segura uma tecla de movimento e registra, quadro a quadro,
## a posição na tela do técnico e de um ponto fixo do cenário.
##   godot --headless --path . -s tests/test_camera.gd

var failures := 0

func check(cond: bool, msg: String) -> void:
	if cond: print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)

func _key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)

func _reversals(pts: Array[Vector2], axis: int) -> int:
	var n := 0
	var prev := 0.0
	for i in range(2, pts.size()):
		var d: float = pts[i][axis] - pts[i - 1][axis]
		if absf(d) > 0.01 and absf(prev) > 0.01 and signf(d) != signf(prev):
			n += 1
		if absf(d) > 0.01:
			prev = d
	return n


## Maior diferença entre passos consecutivos (técnico OU cenário): tremor = passos 0, 4, 0, 4...
func _max_step_jump(ps: Array[Vector2], ls: Array[Vector2], axis: int) -> float:
	var worst := 0.0
	for arr in [ps, ls]:
		for i in range(3, arr.size()):
			var a: float = arr[i][axis] - arr[i - 1][axis]
			var b: float = arr[i - 1][axis] - arr[i - 2][axis]
			worst = maxf(worst, absf(a - b))
	return worst


func _init() -> void:
	print("Chamado Aberto — teste de tremor da câmera")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start_session({"name": "Teste", "class_code": "", "skin": 0, "hair": 0, "shirt": 0}, "treino", false)
	var player: Player = main.get_node("%Player")
	var cam: Camera2D = main.get_node("%Camera2D")
	var view: Control = main.get_node("%WorldView")
	player.position = Vector2(760, 1010)    # área livre da sala de vendas
	var landmark := Vector2(760, 950)       # ponto fixo do cenário
	for dir in [KEY_RIGHT, KEY_DOWN, KEY_UP]:
		_key(dir, true)
		var ps: Array[Vector2] = []
		var ls: Array[Vector2] = []
		for i in 30:
			await process_frame
			var off := view.position + Vector2(4, 4)
			ps.append((Vector2(OfficeMap.iso(player.position)) - cam.position) * 2.0 + off)
			ls.append((Vector2(OfficeMap.iso(landmark)) - cam.position) * 2.0 + off)
		_key(dir, false)
		await process_frame
		var axis := 0 if dir == KEY_RIGHT else 1
		var name: String = {KEY_RIGHT: "direita", KEY_DOWN: "baixo", KEY_UP: "cima"}[dir]
		check(_reversals(ps, axis) == 0, "%s: técnico anda na tela sem ir-e-voltar" % name)
		check(_reversals(ls, axis) == 0, "%s: cenário rola sem ir-e-voltar" % name)
		check(_max_step_jump(ps, ls, axis) <= 2.01, "%s: passos regulares (variação máx. %.1f px)" % [name, _max_step_jump(ps, ls, axis)])
	print("\n%s" % ("TODOS OS TESTES PASSARAM" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)
