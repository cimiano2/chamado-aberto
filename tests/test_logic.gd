extends SceneTree
## Testes headless dos algoritmos:
##   godot --headless --path . -s tests/test_logic.gd

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


func _init() -> void:
	print("Chamado Aberto — testes dos algoritmos")

	# --- escalonamento (exemplo clássico)
	var procs := [
		{"name": "P1", "burst": 6, "prio": 3, "arrival": 0},
		{"name": "P2", "burst": 8, "prio": 1, "arrival": 1},
		{"name": "P3", "burst": 7, "prio": 4, "arrival": 2},
		{"name": "P4", "burst": 3, "prio": 2, "arrival": 3},
	]
	check(OSLogic.schedule_order(procs, "SJF") == ["P4", "P1", "P3", "P2"], "SJF ordena por burst")
	check(OSLogic.schedule_order(procs, "FCFS") == ["P1", "P2", "P3", "P4"], "FCFS ordena por chegada")
	check(OSLogic.schedule_order(procs, "PRIORIDADE") == ["P2", "P4", "P1", "P3"], "Prioridade: menor número primeiro")
	var all_zero := procs.map(func(p): var q: Dictionary = p.duplicate(); q.arrival = 0; return q)
	check(is_equal_approx(OSLogic.average_wait(all_zero, ["P4", "P1", "P3", "P2"]), 7.0), "espera média SJF = 7")

	# --- paginação: sequência do livro (Silberschatz) com 3 quadros
	var refs := [7, 0, 1, 2, 0, 3, 0, 4, 2, 3, 0, 3, 2, 1, 2, 0, 1, 7, 0, 1]
	check(OSLogic.simulate_paging("FIFO", refs, 3).faults == 15, "FIFO = 15 faltas")
	check(OSLogic.simulate_paging("LRU", refs, 3).faults == 12, "LRU = 12 faltas")
	check(OSLogic.simulate_paging("ÓTIMO", refs, 3).faults == 9, "Ótimo = 9 faltas")
	var v := OSLogic.page_victims("ÓTIMO", [1, 2, 3], [0, 1, 2], [0, 1, 2], [1, 2, 3, 4], 3)
	check(v.size() == 3, "Ótimo aceita qualquer página que nunca mais será usada")

	# --- banqueiro (exemplo clássico: seguro)
	var alloc := [[0, 1, 0], [2, 0, 0], [3, 0, 2], [2, 1, 1], [0, 0, 2]]
	var need := [[7, 4, 3], [1, 2, 2], [6, 0, 0], [0, 1, 1], [4, 3, 1]]
	check(OSLogic.is_safe(alloc, need, [3, 3, 2]), "banqueiro: estado clássico é seguro")
	check(not OSLogic.is_safe(alloc, need, [0, 0, 0]), "banqueiro: sem recursos não é seguro")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ok_gen := true
	for i in 200:
		var st := OSLogic.generate_bank_state(rng)
		if not OSLogic.is_safe(st.alloc, st.need, st.available):
			ok_gen = false
	check(ok_gen, "gerador do banqueiro sempre produz estado seguro (200 casos)")

	# --- disco (exemplo clássico: cabeça em 53)
	var reqs := [98, 183, 37, 122, 14, 124, 65, 67]
	var sstf := OSLogic.disk_order(53, reqs, "SSTF")
	check(sstf == [65, 67, 37, 14, 98, 122, 124, 183], "SSTF clássico")
	check(OSLogic.seek_distance(53, sstf) == 236, "SSTF percorre 236 cilindros")
	check(OSLogic.disk_order(53, reqs, "LOOK") == [65, 67, 98, 122, 124, 183, 37, 14], "LOOK subindo")
	check(OSLogic.disk_order(53, reqs, "C-LOOK") == [65, 67, 98, 122, 124, 183, 14, 37], "C-LOOK subindo")
	check(not OSLogic.sstf_unambiguous(50, [40, 60]), "detecta empate no SSTF")

	# --- alocação
	var holes := [{"start": 0, "size": 100}, {"start": 200, "size": 500}, {"start": 800, "size": 200},
		{"start": 1100, "size": 300}, {"start": 1500, "size": 600}]
	check(OSLogic.fit_choices(holes, 212, "FIRST FIT") == [1], "first fit")
	check(OSLogic.fit_choices(holes, 212, "BEST FIT") == [3], "best fit")
	check(OSLogic.fit_choices(holes, 212, "WORST FIT") == [4], "worst fit")
	check(OSLogic.fit_choices(holes, 9999, "FIRST FIT").is_empty(), "nenhuma lacuna cabe")
	OSLogic.allocate(holes, 0, 100)
	check(holes.size() == 4 and holes[0].start == 200, "lacuna consumida inteira é removida")

	# --- chmod
	check(OSLogic.bits_to_octal(OSLogic.octal_to_bits("754")) == "754", "octal ida e volta")
	check(OSLogic.bits_to_symbolic(OSLogic.octal_to_bits("750")) == "rwxr-x---", "simbólico 750")
	check(OSLogic.bits_to_symbolic(OSLogic.octal_to_bits("644")) == "rw-r--r--", "simbólico 644")

	print("\n%s" % ("TODOS OS TESTES PASSARAM" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)
