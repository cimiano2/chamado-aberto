class_name SaveGame
extends RefCounted
## Sessão salva em user:// (no navegador fica guardada no próprio navegador).
## Guarda o perfil, o modo, o estado acumulado no início do dia atual e o placar local.

const PATH := "user://chamado_aberto_sessao.json"
const BOARD_PATH := "user://chamado_aberto_placar.json"


static func exists() -> bool:
	return FileAccess.file_exists(PATH)


static func load_session() -> Dictionary:
	if not exists():
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	return d if typeof(d) == TYPE_DICTIONARY else {}


static func save_session(d: Dictionary) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))


static func clear() -> void:
	if exists():
		DirAccess.remove_absolute(PATH)


static func clear_board() -> void:
	if FileAccess.file_exists(BOARD_PATH):
		DirAccess.remove_absolute(BOARD_PATH)


## Placar local (top 10 deste computador/navegador).
static func board() -> Array:
	if not FileAccess.file_exists(BOARD_PATH):
		return []
	var d = JSON.parse_string(FileAccess.open(BOARD_PATH, FileAccess.READ).get_as_text())
	return d if typeof(d) == TYPE_ARRAY else []


static func add_to_board(name: String, class_code: String, mode: String, points: int, nota: float) -> int:
	var b := board()
	var entry := {"name": name, "turma": class_code, "mode": mode, "points": points, "nota": nota,
		"date": Time.get_date_string_from_system()}
	b.append(entry)
	b.sort_custom(func(x, y): return x.points > y.points)
	b = b.slice(0, 10)
	FileAccess.open(BOARD_PATH, FileAccess.WRITE).store_string(JSON.stringify(b))
	return b.find(entry) + 1
