extends Node
## Languages (autoload "I18n"). English is the default; Portuguese (Brazil)
## is the language the game text is written in.
##
## The Portuguese strings in the code are the message ids: the English
## catalog (assets/i18n/en.json, {pt: en}) is loaded into a Translation, so
## Labels and Buttons translate their text on their own, and code that
## builds text uses tr("...") / I18n.t("...") on the template before
## formatting. Every entry is also registered in UPPER CASE, because much of
## the UI shows names with .to_upper().

signal language_changed

const LANGUAGES := [["en", "ENGLISH"], ["pt_BR", "PORTUGUÊS"]]
const CATALOG := "res://assets/i18n/en.json"

var _en: Translation


func _ready() -> void:
	_en = Translation.new()
	_en.locale = "en"
	var f := FileAccess.open(CATALOG, FileAccess.READ)
	if f:
		var data = JSON.parse_string(f.get_as_text())
		if typeof(data) == TYPE_DICTIONARY:
			for pt in data:
				var en := String(data[pt])
				_en.add_message(pt, en)
				var up := String(pt).to_upper()
				if up != pt:
					_en.add_message(up, en.to_upper())
	TranslationServer.add_translation(_en)
	apply(lang())


func lang() -> String:
	return String(Profile.settings.get("lang", "en"))


func apply(code: String) -> void:
	TranslationServer.set_locale(code)


func set_lang(code: String) -> void:
	Profile.set_setting("lang", code)
	apply(code)
	language_changed.emit()


func is_english() -> bool:
	return lang() == "en"


## Translate from anywhere (static functions and data classes included).
static func t(s: String) -> String:
	return TranslationServer.translate(s)
