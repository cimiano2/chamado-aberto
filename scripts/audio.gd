class_name Audio
extends Node
## Efeitos sonoros e música (assets/sfx, gerados por art/sfx/build.py). M liga/desliga.

const SFX := ["click", "step", "ticket", "success", "error", "expired", "combo", "dayend", "open"]
const PREF_PATH := "user://chamado_aberto_audio.cfg"

var muted := false
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
	_music.volume_db = -9.0
	add_child(_music)
	var cfg := ConfigFile.new()
	if cfg.load(PREF_PATH) == OK:
		muted = cfg.get_value("audio", "muted", false)


func play(name: String, volume_db := 0.0) -> void:
	if muted or not _streams.has(name):
		return
	for p in _pool:
		if not p.playing:
			p.stream = _streams[name]
			p.volume_db = volume_db
			p.play()
			return


func start_music() -> void:
	if not muted and not _music.playing:
		_music.play()


func toggle_mute() -> bool:
	muted = not muted
	if muted:
		_music.stop()
		for p in _pool:
			p.stop()
	else:
		_music.play()
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "muted", muted)
	cfg.save(PREF_PATH)
	return muted
