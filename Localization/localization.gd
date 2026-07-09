extends Node

signal locale_changed(locale_code: String)

const DEFAULT_LOCALE: String = "zh_CN"
const TRANSLATION_CSV_PATH: String = "res://translations/game.csv"
const SETTINGS_SECTION: String = "locale"
const SETTINGS_KEY_CODE: String = "code"

@export var settings_path: String = "user://settings.cfg"

var _supported_locales: Array[Dictionary] = [
	{"code": "zh_CN", "name": "中文"},
	{"code": "en", "name": "English"},
]
var _translations: Array[Translation] = []


func _ready() -> void:
	_load_translations()
	TranslationServer.set_locale(_load_saved_locale())


func _exit_tree() -> void:
	for translation: Translation in _translations:
		TranslationServer.remove_translation(translation)
	_translations.clear()


func get_supported_locales() -> Array[Dictionary]:
	return _supported_locales.duplicate(true)


func get_locale() -> String:
	var locale := TranslationServer.get_locale()
	return locale if _is_supported_locale(locale) else DEFAULT_LOCALE


func set_locale(locale_code: String) -> void:
	if not _is_supported_locale(locale_code):
		locale_code = DEFAULT_LOCALE
	TranslationServer.set_locale(locale_code)
	_save_locale(locale_code)
	locale_changed.emit(locale_code)


func _load_translations() -> void:
	if not _translations.is_empty():
		return
	var file := FileAccess.open(TRANSLATION_CSV_PATH, FileAccess.READ)
	if file == null:
		push_warning("Localization: missing translation CSV at %s" % TRANSLATION_CSV_PATH)
		return

	var header: PackedStringArray = file.get_csv_line()
	if header.size() < 2:
		return

	var translations_by_column: Dictionary = {}
	for column: int in range(1, header.size()):
		var locale_code := String(header[column])
		if locale_code.is_empty() or locale_code.begins_with("_") or locale_code.begins_with("?"):
			continue
		var translation := Translation.new()
		translation.locale = locale_code
		translations_by_column[column] = translation

	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.is_empty():
			continue
		var key := String(row[0])
		if key.is_empty() or key.begins_with("#"):
			continue
		for column: int in translations_by_column.keys():
			if column < row.size():
				(translations_by_column[column] as Translation).add_message(key, String(row[column]))

	for translation: Translation in translations_by_column.values():
		TranslationServer.add_translation(translation)
		_translations.append(translation)


func _load_saved_locale() -> String:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return DEFAULT_LOCALE
	var locale_code := String(config.get_value(SETTINGS_SECTION, SETTINGS_KEY_CODE, DEFAULT_LOCALE))
	return locale_code if _is_supported_locale(locale_code) else DEFAULT_LOCALE


func _save_locale(locale_code: String) -> void:
	var config := ConfigFile.new()
	if FileAccess.file_exists(settings_path):
		config.load(settings_path)
	config.set_value(SETTINGS_SECTION, SETTINGS_KEY_CODE, locale_code)
	if config.save(settings_path) != OK:
		push_warning("Localization: could not save locale to %s" % settings_path)


func _is_supported_locale(locale_code: String) -> bool:
	for locale: Dictionary in _supported_locales:
		if String(locale.get("code", "")) == locale_code:
			return true
	return false
