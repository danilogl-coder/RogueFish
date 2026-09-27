class_name SettingsView
extends VBoxContainer
## Shared options list (music, sfx, vibration, shake, damage numbers).


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_language()
	_slider("MÚSICA", "music", "music")
	_slider("EFEITOS", "sfx", "sound")
	_toggle("VIBRAÇÃO", "vibration", "vibrate")
	_toggle("TREMOR DE TELA", "shake", "wave")
	_toggle("NÚMEROS DE DANO", "damage_numbers", "numbers")
	if Profile.owns("relic_music"):
		_track_picker()


const TRACKS := [["auto", "AUTOMÁTICA"], ["explore1", "RECIFE ENSOLARADO"], ["explore2", "CORRENTE PROFUNDA"],
	["explore3", "FLORESTA DE KELP"], ["explore4", "ABISMO AZUL"], ["explore5", "MARÉ ALTA"],
	["horde", "HORDA"], ["boss", "MANDÍBULAS"], ["final", "DEVORADOR"], ["menu", "CANÇÃO DAS MARÉS"]]


## Caixa de Música: pick the track that plays during runs.
func _track_picker() -> void:
	var h := UIKit.hbox(6)
	h.add_child(UIKit.icon_rect("relic_music", 16))
	var l := UIKit.label("TRILHA", 8)
	l.custom_minimum_size.x = 120
	h.add_child(l)
	var cur: String = str(Profile.settings.get("music_track", "auto"))
	var idx := 0
	for i in TRACKS.size():
		if TRACKS[i][0] == cur:
			idx = i
	var b := UIKit.button(TRACKS[idx][1], "", 110)
	b.pressed.connect(func():
		idx = (idx + 1) % TRACKS.size()
		b.text = TRACKS[idx][1]
		Profile.set_setting("music_track", TRACKS[idx][0])
		Sfx.play("click"))
	h.add_child(b)
	add_child(h)


## Language picker (English / Português). The menu rebuilds itself on change.
func _language() -> void:
	var h := UIKit.hbox(6)
	h.add_child(UIKit.icon_rect("book", 16))
	var l := UIKit.label("IDIOMA / LANGUAGE", 8)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.custom_minimum_size.x = 120
	h.add_child(l)
	var idx := 0
	for i in I18n.LANGUAGES.size():
		if I18n.LANGUAGES[i][0] == I18n.lang():
			idx = i
	var b := UIKit.button(I18n.LANGUAGES[idx][1], "", 110)
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.pressed.connect(func():
		idx = (idx + 1) % I18n.LANGUAGES.size()
		b.text = I18n.LANGUAGES[idx][1]
		Sfx.play("click")
		I18n.set_lang(I18n.LANGUAGES[idx][0]))
	h.add_child(b)
	add_child(h)


func _slider(text: String, key: String, icon: String) -> void:
	var h := UIKit.hbox(6)
	h.add_child(UIKit.icon_rect(icon, 16))
	var l := UIKit.label(text, 8)
	l.custom_minimum_size.x = 120
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(Profile.settings.get(key, 0.7))
	s.custom_minimum_size = Vector2(110, 16)
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(func(v): Profile.settings[key] = v; Profile._apply_audio())
	s.drag_ended.connect(func(_c): Profile.save_game(); Sfx.play("click"))
	h.add_child(s)
	add_child(h)


func _toggle(text: String, key: String, icon: String) -> void:
	var h := UIKit.hbox(6)
	h.add_child(UIKit.icon_rect(icon, 16))
	var l := UIKit.label(text, 8)
	l.custom_minimum_size.x = 120
	h.add_child(l)
	var b := UIKit.button("", "", 70)
	var refresh := func():
		var on: bool = Profile.settings.get(key, true)
		b.text = "LIGADO" if on else "DESLIG."
		b.theme_type_variation = "" if on else "RedButton"
	refresh.call()
	b.pressed.connect(func():
		Profile.set_setting(key, not Profile.settings.get(key, true))
		refresh.call())
	h.add_child(b)
	add_child(h)
