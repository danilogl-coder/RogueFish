extends Node
## Sound effects pool and music player with cross-fade.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC := {
	"menu": "res://assets/audio/music/menu_theme.wav",
	"game": "res://assets/audio/background_music.mp3",
	"boss": "res://assets/audio/music/boss_theme.wav",
}
const POOL_SIZE := 14

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _streams: Dictionary = {}
var _last_play: Dictionary = {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current_music := ""


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
	for m in [_music_a, _music_b]:
		m.bus = "Music"
		add_child(m)
	Profile._apply_audio()


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


func play_music(key: String, fade := 1.2) -> void:
	if key == _current_music:
		return
	_current_music = key
	var path: String = MUSIC.get(key, "")
	var incoming := _music_b if _music_a.playing else _music_a
	var outgoing := _music_a if incoming == _music_b else _music_b
	if path != "" and ResourceLoader.exists(path):
		var stream: AudioStream = load(path)
		if stream is AudioStreamWAV:
			var wav := stream as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
		elif stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		incoming.stream = stream
		incoming.volume_db = -40.0
		incoming.play()
		var t := create_tween().set_parallel(true)
		t.tween_property(incoming, "volume_db", 0.0 if key != "game" else -4.0, fade)
		t.tween_property(outgoing, "volume_db", -40.0, fade)
		t.chain().tween_callback(outgoing.stop)
	else:
		var t2 := create_tween()
		t2.tween_property(outgoing, "volume_db", -40.0, fade)
		t2.tween_callback(outgoing.stop)
