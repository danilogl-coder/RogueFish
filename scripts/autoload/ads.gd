extends Node
## Rewarded video ads (autoload "Ads").
##
##   Ads.show_rewarded("revive", func(): game.revive_player(), func(): ...)
##
## Every placement (Offers.VIDEOS) has a daily cap and a cooldown, both kept
## in Profile.ad_log so they survive restarts. VIP players get the reward
## immediately, without a video.
##
## Backends:
##  * a real ad SDK registers itself with `Ads.set_backend(obj)`, where obj
##    has `show_rewarded(placement: String, on_done: Callable)` and calls
##    on_done.call(true) when the user earned the reward, or
##    on_done.call(false) when the video failed / was skipped.
##    See docs/MONETIZATION.md for the AdMob (poing-studios plugin) glue.
##  * without one, a simulated video (5 s overlay) is shown so the whole flow
##    can be tested in the editor and on desktop.

signal reward_granted(placement: String)

const SIM_SECONDS := 5.0

var _backend: Object = null
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_backend(obj: Object) -> void:
	_backend = obj


func has_real_backend() -> bool:
	return _backend != null


# ---------------------------------------------------------------- limits
func _today() -> String:
	return Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()))


func _log() -> Dictionary:
	var log: Dictionary = Profile.ad_log
	if String(log.get("date", "")) != _today():
		log["date"] = _today()
		log["counts"] = {}
	if not log.has("last"):
		log["last"] = {}
	return log


func watched_today(placement: String) -> int:
	return int(_log().counts.get(placement, 0))


func remaining(placement: String) -> int:
	return maxi(0, int(Offers.VIDEOS[placement].daily) - watched_today(placement))


func cooldown_left(placement: String) -> float:
	var last := float(_log().last.get(placement, 0.0))
	var cd := float(Offers.VIDEOS[placement].cooldown)
	return maxf(0.0, last + cd - Time.get_unix_time_from_system())


func can_show(placement: String) -> bool:
	return not _busy and remaining(placement) > 0 and cooldown_left(placement) <= 0.0


## Short text for a button ("VER VÍDEO", "3/5 hoje", "volte em 2:10"...).
func status_text(placement: String) -> String:
	if remaining(placement) <= 0:
		return "volte amanhã"
	var cd := cooldown_left(placement)
	if cd > 0.0:
		return "em %d:%02d" % [int(cd) / 60, int(cd) % 60]
	return "%d/%d hoje" % [remaining(placement), int(Offers.VIDEOS[placement].daily)]


# ------------------------------------------------------------------ show
## Shows a rewarded video. on_reward runs only if the video was completed.
func show_rewarded(placement: String, on_reward: Callable, on_fail := Callable()) -> void:
	if not can_show(placement):
		if on_fail.is_valid():
			on_fail.call()
		return
	var done := func(ok: bool):
		_busy = false
		if ok:
			var log := _log()
			log.counts[placement] = watched_today(placement) + 1
			log.last[placement] = Time.get_unix_time_from_system()
			Profile.bump("ads_watched")
			Profile.save_game()
			reward_granted.emit(placement)
			on_reward.call()
		elif on_fail.is_valid():
			on_fail.call()
	_busy = true
	if Profile.vip:
		done.call(true)
	elif _backend != null:
		_backend.call("show_rewarded", placement, done)
	else:
		_simulate(placement, done)


## Stand-in video for the editor / desktop builds.
func _simulate(placement: String, done: Callable) -> void:
	Sfx.duck(SIM_SECONDS + 0.5)
	var layer := CanvasLayer.new()
	layer.layer = 120
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var root := Control.new()
	root.theme = UIKit.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	UIKit.dim_background(root, 0.92)
	var panel := UIKit.center_panel(root, Vector2(300, 120))
	var v := UIKit.vbox(8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)
	v.add_child(UIKit.label("ANÚNCIO", 16, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("(vídeo de teste - nenhum SDK de anúncios ligado)", 8, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var bar := UIKit.bar("bar_xp", Vector2(240, 8))
	bar.max_value = SIM_SECONDS
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(bar)
	var skip := UIKit.button("FECHAR (sem prêmio)", "", 0, "back")
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(skip)
	var finished := [false]
	var close := func(ok: bool):
		if finished[0]:
			return
		finished[0] = true
		layer.queue_free()
		done.call(ok)
	skip.pressed.connect(func(): close.call(false))
	var tw := create_tween()
	tw.tween_property(bar, "value", SIM_SECONDS, SIM_SECONDS)
	tw.finished.connect(func(): close.call(true))
