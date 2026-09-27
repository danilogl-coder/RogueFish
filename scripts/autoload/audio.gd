extends Node
## Sound effects pool and adaptive music.
##
## Music (tools/audio/compose_music.py): the run music is two synced stems of
## the same song, a calm layer and a drive layer (drums, bass, saw lead). The
## drive layer follows `intensity` (0..1): danger, waves and combos push it up,
## so the music reacts to how the run feels instead of switching tracks.
## Bosses and the menu use their own loops; stingers (level up, victory...)
## briefly duck the music.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const MUSIC := {
	"menu": "menu",
	"game": "explore_base",
	"boss": "boss",
	"final": "final",
}
const DRIVE := "explore_drive"
const POOL_SIZE := 14

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _streams: Dictionary = {}
var _last_play: Dictionary = {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _drive: AudioStreamPlayer          ## drive stem, synced with the calm stem
var _sting: AudioStreamPlayer
var _current_music := ""
var intensity := 0.0                   ## target 0..1 set by the game
var _drive_lvl := 0.0
var _duck := 0.0                       ## seconds of stinger ducking left


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	_drive = AudioStreamPlayer.new()
	_sting = AudioStreamPlayer.new()
	for m in [_music_a, _music_b, _drive, _sting]:
		m.bus = "Music"
		add_child(m)
	Profile._apply_audio()


func _process(delta: float) -> void:
	# the drive stem glides toward the requested intensity
	var target := clampf(intensity, 0.0, 1.0) if _current_music == "game" else 0.0
	var rate := 0.9 if target > _drive_lvl else 0.35
	_drive_lvl = move_toward(_drive_lvl, target, delta * rate)
	var duck_db := -7.0 if _duck > 0.0 else 0.0
	_duck -= delta
	if _drive.playing:
		_drive.volume_db = linear_to_db(maxf(0.0001, _drive_lvl)) + duck_db
		# keep the stems locked together (they can drift after a pause)
		var main := _music_a if _music_a.stream == _drive.get_meta("pair", null) else _music_b
		if main.playing and absf(main.get_playback_position() - _drive.get_playback_position()) > 0.05:
			_drive.seek(main.get_playback_position())
	for m in [_music_a, _music_b]:
		if m.playing and not m.has_meta("fading"):
			m.volume_db = move_toward(m.volume_db, float(m.get_meta("vol", 0.0)) + duck_db, delta * 30.0)


func _load_music(name: String) -> AudioStream:
	var path := MUSIC_DIR + name + ".ogg"
	if not ResourceLoader.exists(path):
		return null
	var st: AudioStream = load(path)
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	return st


## Short musical cue (level up, victory, defeat, fusion) over ducked music.
func play_stinger(name: String, volume_db := 0.0) -> void:
	var path := MUSIC_DIR + "sting_" + name + ".ogg"
	if not ResourceLoader.exists(path):
		return
	var st: AudioStream = load(path)
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = false
	_sting.stream = st
	_sting.volume_db = volume_db
	_sting.play()
	_duck = minf(st.get_length(), 2.5)


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func _stream(sfx_name: String) -> AudioStream:
	if _streams.has(sfx_name):
		return _streams[sfx_name]
	var path := SFX_DIR + sfx_name + ".wav"
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_streams[sfx_name] = s
	return s


## Plays a one-shot. min_gap prevents the same sound spamming in one frame burst.
func play(sfx_name: String, volume_db := 0.0, pitch_var := 0.08, min_gap := 0.04) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_play.get(sfx_name, -1.0)) < min_gap:
		return
	_last_play[sfx_name] = now
	var s := _stream(sfx_name)
	if s == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


## One-shot at an exact pitch (rising XP chimes, combo sounds).
func play_pitched(sfx_name: String, pitch: float, volume_db := 0.0) -> void:
	var s := _stream(sfx_name)
	if s == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func play_music(key: String, fade := 1.2) -> void:
	if key == _current_music:
		return
	_current_music = key
	var incoming := _music_b if _music_a.playing else _music_a
	var outgoing := _music_a if incoming == _music_b else _music_b
	var stream: AudioStream = _load_music(MUSIC.get(key, ""))
	var t := create_tween().set_parallel(true)
	outgoing.set_meta("fading", true)
	t.tween_property(outgoing, "volume_db", -40.0, fade)
	if _drive.playing:
		t.tween_property(_drive, "volume_db", -40.0, fade)
	t.chain().tween_callback(func():
		outgoing.stop()
		outgoing.remove_meta("fading")
		if _current_music != "game":
			_drive.stop())
	if stream == null:
		return
	incoming.stream = stream
	incoming.volume_db = -40.0
	incoming.set_meta("vol", -2.0 if key == "game" else 0.0)
	incoming.set_meta("fading", true)
	incoming.play()
	var t2 := create_tween()
	t2.tween_property(incoming, "volume_db", float(incoming.get_meta("vol")), fade)
	t2.tween_callback(func(): incoming.remove_meta("fading"))
	if key == "game":
		_drive.stream = _load_music(DRIVE)
		_drive.set_meta("pair", stream)
		_drive_lvl = 0.0
		_drive.volume_db = -60.0
		_drive.play()
