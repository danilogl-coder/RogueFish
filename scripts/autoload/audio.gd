extends Node
## Sound effects pool and adaptive music.
##
## Music (tools/audio/compose_music.py): the run music is a rotation of five
## exploration songs. Each song is two synced stems, a calm layer and a drive
## layer (drums, bass, lead). The drive layer follows `intensity` (0..1):
## danger and combos push it up, so the music reacts to how the run feels.
## Every time the run returns to exploring (and after a song has looped about
## twice) the next song crossfades in, so long runs do not repeat. Hordes,
## bosses and the menu use their own loops; stingers briefly duck the music.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const MUSIC := {
	"menu": "menu",
	"horde": "horde",
	"boss": "boss",
	"final": "final",
}
## exploration songs (files <id>_base.ogg + <id>_drive.ogg)
const EXPLORE: Array[String] = ["explore1", "explore2", "explore3", "explore4", "explore5"]
const EXPLORE_LOOPS := 2               ## plays of a song before the next one
const SONG_FADE := 4.0                 ## crossfade between exploration songs
const POOL_SIZE := 14

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _streams: Dictionary = {}
var _last_play: Dictionary = {}
var _main: Array[AudioStreamPlayer] = []   ## two music players (crossfade)
var _drv: Array[AudioStreamPlayer] = []    ## drive stem paired with each one
var _tweens: Dictionary = {}
var _cur := 0                          ## index of the active music player
var _sting: AudioStreamPlayer
var _current_music := ""
var _song := -1                        ## index in EXPLORE of the current song
var _song_fixed := false               ## chosen in the Caixa de Música
var _song_loops := 0
var _last_pos := 0.0
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
	for i in 2:
		var m := AudioStreamPlayer.new()
		var d := AudioStreamPlayer.new()
		m.bus = "Music"
		d.bus = "Music"
		add_child(m)
		add_child(d)
		_main.append(m)
		_drv.append(d)
	_sting = AudioStreamPlayer.new()
	_sting.bus = "Music"
	add_child(_sting)
	_song = randi() % EXPLORE.size()
	Profile._apply_audio()


func _process(delta: float) -> void:
	# the drive stem glides toward the requested intensity
	var target := clampf(intensity, 0.0, 1.0) if _current_music == "game" else 0.0
	var rate := 0.9 if target > _drive_lvl else 0.35
	_drive_lvl = move_toward(_drive_lvl, target, delta * rate)
	var duck_db := -7.0 if _duck > 0.0 else 0.0
	_duck -= delta
	for i in 2:
		var m := _main[i]
		var d := _drv[i]
		if m.playing and not m.has_meta("fading"):
			m.volume_db = move_toward(m.volume_db, float(m.get_meta("vol", 0.0)) + duck_db, delta * 30.0)
		if d.playing and not d.has_meta("fading"):
			# follows its calm stem (and that stem's fade-in) plus the intensity
			var fade_db := m.volume_db - float(m.get_meta("vol", 0.0)) if m.playing else -60.0
			d.volume_db = linear_to_db(maxf(0.0001, _drive_lvl)) + minf(fade_db, 0.0) + duck_db
			# keep the stems locked together (they can drift after a pause)
			if m.playing and absf(m.get_playback_position() - d.get_playback_position()) > 0.05:
				d.seek(m.get_playback_position())
	_rotate_songs()


## After a song has looped EXPLORE_LOOPS times, crossfade to the next one.
func _rotate_songs() -> void:
	if _current_music != "game" or _song_fixed:
		return
	var m := _main[_cur]
	if not m.playing or m.stream == null:
		return
	var pos := m.get_playback_position()
	if pos + 1.0 < _last_pos:
		_song_loops += 1
	_last_pos = pos
	var length := m.stream.get_length()
	if _song_loops >= EXPLORE_LOOPS - 1 and length > SONG_FADE * 2.0 and pos >= length - SONG_FADE:
		_play_song((_song + 1) % EXPLORE.size(), SONG_FADE)


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
	# Caixa de Música: a chosen track replaces the run music (hordes and
	# bosses keep theirs)
	var pick: String = str(Profile.settings.get("music_track", "auto"))
	var owns: bool = Profile.owns("relic_music")
	if key == "game" and owns and MUSIC.has(pick):
		key = pick
	if key == _current_music:
		return
	_current_music = key
	if key == "game":
		var fixed := EXPLORE.find(pick) if owns else -1
		_song_fixed = fixed >= 0
		# a different song every time the run goes back to exploring
		_play_song(fixed if _song_fixed else (_song + 1) % EXPLORE.size(), fade)
		return
	var path: String = str(MUSIC.get(key, ""))
	var st: AudioStream = null
	if path != "":
		st = _load_music(path)
	_crossfade(st, null, 0.0, fade)


func _play_song(idx: int, fade: float) -> void:
	_song = idx
	_song_loops = 0
	_last_pos = 0.0
	var id: String = EXPLORE[idx]
	_crossfade(_load_music(id + "_base"), _load_music(id + "_drive"), -2.0, fade)


## Fades the active music out and `stream` (with its synced drive stem) in.
func _crossfade(stream: AudioStream, drive: AudioStream, vol: float, fade: float) -> void:
	var out_i := _cur
	_cur = 1 - _cur
	_fade_out(_main[out_i], fade)
	_fade_out(_drv[out_i], fade)
	var incoming := _main[_cur]
	var in_drv := _drv[_cur]
	_kill_tween(incoming)
	_kill_tween(in_drv)
	incoming.stop()
	in_drv.stop()
	in_drv.remove_meta("fading")
	if stream == null:
		incoming.remove_meta("fading")
		return
	incoming.stream = stream
	incoming.volume_db = -40.0
	incoming.set_meta("vol", vol)
	incoming.set_meta("fading", true)
	incoming.play()
	var t := create_tween()
	t.tween_property(incoming, "volume_db", vol, fade)
	t.tween_callback(func(): incoming.remove_meta("fading"))
	_tweens[incoming] = t
	if drive != null:
		in_drv.stream = drive
		in_drv.volume_db = -60.0
		in_drv.play()


func _fade_out(p: AudioStreamPlayer, fade: float) -> void:
	_kill_tween(p)
	if not p.playing:
		p.remove_meta("fading")
		return
	p.set_meta("fading", true)
	var t := create_tween()
	t.tween_property(p, "volume_db", -40.0, fade)
	t.tween_callback(func():
		p.stop()
		p.remove_meta("fading"))
	_tweens[p] = t


func _kill_tween(p: AudioStreamPlayer) -> void:
	var t: Tween = _tweens.get(p, null)
	if t != null and t.is_valid():
		t.kill()
	_tweens.erase(p)
