class_name Audio
extends Node
## Efeitos sonoros e música (assets/sfx, gerados por art/sfx/build.py).
## Música e efeitos ligam/desligam separadamente; a música começa DESLIGADA.
## Teclas no jogo: M = música, N = efeitos. A escolha fica salva.

signal changed

const SFX := ["click", "step", "ticket", "success", "error", "expired", "combo", "dayend", "open"]
const PREF_PATH := "user://chamado_aberto_audio.cfg"

var music_on := false
var sfx_on := true
var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer


func _ready() -> void:
	for n in SFX:
		_streams[n] = load("res://assets/sfx/%s.wav" % n)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	var m: AudioStreamWAV = load("res://assets/sfx/music.wav")
	m.loop_mode = AudioStreamWAV.LOOP_FORWARD
	m.loop_begin = 0
	m.loop_end = m.data.size() / 2
	_music.stream = m
	_music.volume_db = -12.0
	add_child(_music)
	var cfg := ConfigFile.new()
	if cfg.load(PREF_PATH) == OK:
		music_on = cfg.get_value("audio", "music", false)
		sfx_on = cfg.get_value("audio", "sfx", true)


func play(name: String, volume_db := 0.0) -> void:
	if not sfx_on or not _streams.has(name):
		return
	for p in _pool:
		if not p.playing:
			p.stream = _streams[name]
			p.volume_db = volume_db
			p.play()
			return


## Chamado quando a partida começa: só toca se o jogador deixou a música ligada.
func start_music() -> void:
	if music_on and not _music.playing:
		_music.play()


func set_music(on: bool) -> void:
	music_on = on
	if on and not _music.playing:
		_music.play()
	elif not on:
		_music.stop()
	_save()


func set_sfx(on: bool) -> void:
	sfx_on = on
	if not on:
		for p in _pool:
			p.stop()
	_save()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_on)
	cfg.set_value("audio", "sfx", sfx_on)
	cfg.save(PREF_PATH)
	changed.emit()
