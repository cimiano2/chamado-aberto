class_name OSLogic
extends RefCounted
## Algoritmos de sistemas operacionais usados pelas tarefas.
## Funções puras (sem UI), cobertas por tests/test_logic.gd.


# ====================================================================
# Escalonamento de CPU (não preemptivo)
# Processo: {name: String, burst: int, prio: int, arrival: int}
# Convenção de prioridade: MENOR número = MAIOR prioridade.
# ====================================================================

static func schedule_order(procs: Array, policy: String) -> Array[String]:
	var arr := procs.duplicate()
	match policy:
		"FCFS":
			arr.sort_custom(func(a, b): return a.arrival < b.arrival)
		"SJF":
			arr.sort_custom(func(a, b): return a.burst < b.burst)
		"PRIORIDADE":
			arr.sort_custom(func(a, b): return a.prio < b.prio)
	var out: Array[String] = []
	for p in arr:
		out.append(p.name)
	return out


## Tempo médio de espera executando na ordem dada (todos chegam em t=0, exceto FCFS
## que usa arrival; a espera é início − chegada).
static func average_wait(procs: Array, order: Array) -> float:
	var by_name := {}
	for p in procs:
		by_name[p.name] = p
	var t := 0
	var total := 0
	for n in order:
		var p: Dictionary = by_name[n]
		t = maxi(t, p.arrival)
		total += t - p.arrival
		t += p.burst
	return float(total) / maxf(1.0, order.size())


# ====================================================================
# Substituição de páginas
# ====================================================================

## Índices de quadros aceitáveis como vítima.
## loaded_at[i] = instante em que o quadro i recebeu a página atual;
## last_used[i] = último instante em que a página do quadro i foi referenciada.
static func page_victims(algorithm: String, frames: Array, loaded_at: Array,
		last_used: Array, refs: Array, t: int) -> Array[int]:
	var out: Array[int] = []
	match algorithm:
		"FIFO":
			out.append(_argmin(loaded_at))
		"LRU":
			out.append(_argmin(last_used))
		"ÓTIMO":
			var next_use: Array[int] = []
			for page in frames:
				var nxt := 1 << 30   # "nunca mais"
				for k in range(t + 1, refs.size()):
					if refs[k] == page:
						nxt = k
						break
				next_use.append(nxt)
			var far: int = next_use.max()
			for i in next_use.size():
				if next_use[i] == far:
					out.append(i)
	return out


static func next_use_of(page: int, refs: Array, t: int) -> int:
	for k in range(t + 1, refs.size()):
		if refs[k] == page:
			return k
	return -1


## Simula a sequência inteira e devolve {faults, evictions} (escolhendo a 1ª vítima válida).
static func simulate_paging(algorithm: String, refs: Array, n_frames: int) -> Dictionary:
	var frames: Array = []
	var loaded_at: Array = []
	var last_used: Array = []
	var faults := 0
	var evictions := 0
	for t in refs.size():
		var page: int = refs[t]
		var idx := frames.find(page)
		if idx >= 0:
			last_used[idx] = t
			continue
		faults += 1
		if frames.size() < n_frames:
			frames.append(page)
			loaded_at.append(t)
			last_used.append(t)
		else:
			evictions += 1
			var v: int = page_victims(algorithm, frames, loaded_at, last_used, refs, t)[0]
			frames[v] = page
			loaded_at[v] = t
			last_used[v] = t
	return {"faults": faults, "evictions": evictions}


# ====================================================================
# Algoritmo do banqueiro (evitar deadlock)
# ====================================================================

static func fits(need: Array, work: Array) -> bool:
	for i in need.size():
		if need[i] > work[i]:
			return false
	return true


static func add_vec(a: Array, b: Array) -> Array:
	var out := []
	for i in a.size():
		out.append(a[i] + b[i])
	return out


static func is_safe(alloc: Array, need: Array, available: Array) -> bool:
	var work := available.duplicate()
	var done := []
	done.resize(alloc.size())
	done.fill(false)
	var progressed := true
	while progressed:
		progressed = false
		for i in alloc.size():
			if not done[i] and fits(need[i], work):
				work = add_vec(work, alloc[i])
				done[i] = true
				progressed = true
	return not done.has(false)


## Gera um estado seguro em que o Disponível inicial NÃO atende todo mundo
## (força o jogador a pensar na ordem).
static func generate_bank_state(rng: RandomNumberGenerator, n: int = 4, m: int = 3) -> Dictionary:
	while true:
		var order := range(n)
		_shuffle(order, rng)
		var available := []
		for j in m:
			available.append(rng.randi_range(1, 3))
		var alloc := []
		var need := []
		alloc.resize(n)
		need.resize(n)
		var work := available.duplicate()
		for i in order:
			var nd := []
			var al := []
			for j in m:
				nd.append(rng.randi_range(0, work[j]))
				al.append(rng.randi_range(0, 3))
			need[i] = nd
			alloc[i] = al
			work = add_vec(work, al)
		var blocked := 0
		for i in n:
			if not fits(need[i], available):
				blocked += 1
		if blocked >= 2 and is_safe(alloc, need, available):
			return {"alloc": alloc, "need": need, "available": available}
	return {}


# ====================================================================
# Escalonamento de disco
# ====================================================================

static func disk_order(head: int, requests: Array, algorithm: String) -> Array[int]:
	var out: Array[int] = []
	match algorithm:
		"SSTF":
			var pending := requests.duplicate()
			var pos := head
			while not pending.is_empty():
				var best: int = pending[0]
				for r in pending:
					if absi(r - pos) < absi(best - pos):
						best = r
				out.append(best)
				pending.erase(best)
				pos = best
		"LOOK":   # sobe atendendo, depois desce
			var up := requests.filter(func(r): return r >= head)
			var down := requests.filter(func(r): return r < head)
			up.sort()
			down.sort()
			down.reverse()
			out.assign(up + down)
		"C-LOOK":  # sobe atendendo, volta ao menor e sobe de novo
			var up := requests.filter(func(r): return r >= head)
			var low := requests.filter(func(r): return r < head)
			up.sort()
			low.sort()
			out.assign(up + low)
	return out


static func seek_distance(head: int, order: Array) -> int:
	var total := 0
	var pos := head
	for r in order:
		total += absi(r - pos)
		pos = r
	return total


## true se o SSTF não tiver empates de distância em nenhum passo.
static func sstf_unambiguous(head: int, requests: Array) -> bool:
	var pending := requests.duplicate()
	var pos := head
	while pending.size() > 1:
		var dists := pending.map(func(r): return absi(r - pos))
		var mn: int = dists.min()
		if dists.count(mn) > 1:
			return false
		var best: int = pending[dists.find(mn)]
		pending.erase(best)
		pos = best
	return true


# ====================================================================
# Alocação contígua de memória
# Lacuna: {start: int, size: int}
# ====================================================================

static func fit_choices(holes: Array, size: int, algorithm: String) -> Array[int]:
	var out: Array[int] = []
	var candidates: Array[int] = []
	for i in holes.size():
		if holes[i].size >= size:
			candidates.append(i)
	if candidates.is_empty():
		return out
	match algorithm:
		"FIRST FIT":
			var first := candidates[0]
			for i in candidates:
				if holes[i].start < holes[first].start:
					first = i
			out.append(first)
		"BEST FIT", "WORST FIT":
			var target: int = holes[candidates[0]].size
			for i in candidates:
				var s: int = holes[i].size
				if (algorithm == "BEST FIT" and s < target) or (algorithm == "WORST FIT" and s > target):
					target = s
			for i in candidates:
				if holes[i].size == target:
					out.append(i)
	return out


static func allocate(holes: Array, index: int, size: int) -> void:
	holes[index].start += size
	holes[index].size -= size
	if holes[index].size == 0:
		holes.remove_at(index)


# ====================================================================
# Permissões (chmod)
# bits: 9 bools na ordem dono rwx, grupo rwx, outros rwx
# ====================================================================

static func octal_to_bits(octal: String) -> Array[bool]:
	var bits: Array[bool] = []
	for ch in octal:
		var d := int(ch)
		bits.append(d & 4 != 0)
		bits.append(d & 2 != 0)
		bits.append(d & 1 != 0)
	return bits


static func bits_to_octal(bits: Array) -> String:
	var s := ""
	for g in 3:
		var d := 0
		if bits[g * 3]: d += 4
		if bits[g * 3 + 1]: d += 2
		if bits[g * 3 + 2]: d += 1
		s += str(d)
	return s


static func bits_to_symbolic(bits: Array) -> String:
	var s := ""
	var letters := "rwx"
	for i in 9:
		s += letters[i % 3] if bits[i] else "-"
	return s


# ====================================================================
# util

static func _argmin(arr: Array) -> int:
	var best := 0
	for i in arr.size():
		if arr[i] < arr[best]:
			best = i
	return best


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
