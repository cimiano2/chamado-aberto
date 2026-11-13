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

func _init() -> void:
	print("Chamado Aberto — teste de tremor da câmera")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._on_overlay_action()
	var player: Player = main.get_node("%Player")
	var cam: Camera2D = main.get_node("%Camera2D")
	var view: Control = main.get_node("%WorldView")
	player.position = Vector2(1280, 680)   # meio do corredor
	var landmark := Vector2(1280, 600)      # ponto fixo do cenário
	for dir in [KEY_RIGHT, KEY_DOWN, KEY_UP]:
		_key(dir, true)
		var player_x: Array[float] = []
		var land: Array[Vector2] = []
		for i in 40:
			await process_frame
			# onde as coisas aparecem na tela = (pixel do mundo − câmera) * 2 + deslocamento do container
			var off := view.position + Vector2(4, 4)
			var p_screen := (Vector2(OfficeMap.iso(player.position)) - cam.position) * 2.0 + off
			var l_screen := (Vector2(OfficeMap.iso(landmark)) - cam.position) * 2.0 + off
			player_x.append(p_screen.x if dir == KEY_RIGHT else p_screen.y)
			land.append(l_screen)
		_key(dir, false)
		await process_frame
		# o técnico deve ficar parado na tela (no máximo 1 px de variação)
		var spread: float = player_x.max() - player_x.min()
		# o cenário deve andar sempre no mesmo sentido (nunca voltar = tremor)
		var reversals := 0
		var axis := 0 if dir == KEY_RIGHT else 1
		var prev_d := 0.0
		for i in range(2, land.size()):
			var d: float = land[i][axis] - land[i - 1][axis]
			if absf(d) > 0.01 and absf(prev_d) > 0.01 and signf(d) != signf(prev_d):
				reversals += 1
			if absf(d) > 0.01:
				prev_d = d
		var name: String = {KEY_RIGHT: "direita", KEY_DOWN: "baixo", KEY_UP: "cima"}[dir]
		check(spread <= 1.01, "%s: técnico fica fixo na tela (variação %.2f px)" % [name, spread])
		check(reversals == 0, "%s: cenário rola sem ir-e-voltar (%d inversões)" % [name, reversals])
	print("\n%s" % ("TODOS OS TESTES PASSARAM" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)
