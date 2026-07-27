extends Control
class_name SettingsPanel

signal continue_requested
signal back_requested
signal exit_requested

var _pause_context: bool = false
var _locales: Array[Dictionary] = [
	{"code": "zh_CN", "name": "中文"},
	{"code": "en", "name": "English"},
]

@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _continue_button: Button = $Center/Panel/MarginContainer/Layout/ButtonRow/ContinueButton
@onready var _back_button: Button = $Center/Panel/MarginContainer/Layout/ButtonRow/BackButton
@onready var _exit_button: Button = $Center/Panel/MarginContainer/Layout/ButtonRow/ExitButton
@onready var _language_button: OptionButton = $Center/Panel/MarginContainer/Layout/SettingsPanel/LanguageRow/LanguageButton


func _ready() -> void:
	_connect_localization()
	_continue_button.pressed.connect(_on_continue_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_exit_button.pressed.connect(func() -> void: exit_requested.emit())
	_setup_language_button()
	_apply_text()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


func present(pause_game: bool) -> void:
	_pause_context = pause_game
	if _pause_context:
		get_tree().paused = true
	_animation_player.play(&"show_settings")
	_continue_button.call_deferred(&"grab_focus")


func dismiss() -> void:
	_animation_player.play(&"hide_settings")


func _on_continue_pressed() -> void:
	continue_requested.emit()


func _on_back_pressed() -> void:
	back_requested.emit()


func _setup_language_button() -> void:
	_locales = _get_supported_locales()
	_language_button.clear()
	for locale: Dictionary in _locales:
		_language_button.add_item(String(locale.get("name", locale.get("code", ""))))
	if not _language_button.item_selected.is_connected(_on_language_selected):
		_language_button.item_selected.connect(_on_language_selected)
	_sync_language_button()


func _on_language_selected(index: int) -> void:
	if index < 0 or index >= _locales.size():
		return
	var locale_code := String(_locales[index].get("code", "zh_CN"))
	var localization := _get_localization()
	if localization != null and localization.has_method(&"set_locale"):
		localization.call(&"set_locale", locale_code)
	else:
		TranslationServer.set_locale(locale_code)
		_apply_text()
	_sync_language_button()


func _apply_text() -> void:
	_set_label_text("Center/Panel/MarginContainer/Layout/TitleLabel", &"UI_SETTINGS_TITLE")
	_set_button_text("Center/Panel/MarginContainer/Layout/ButtonRow/ContinueButton", &"UI_CONTINUE")
	_set_button_text("Center/Panel/MarginContainer/Layout/ButtonRow/BackButton", &"UI_BACK")
	_set_button_text("Center/Panel/MarginContainer/Layout/ButtonRow/ExitButton", &"UI_EXIT")
	_set_label_text("Center/Panel/MarginContainer/Layout/SettingsPanel/LanguageRow/LanguageLabel", &"UI_LANGUAGE")
	_set_label_text("Center/Panel/MarginContainer/Layout/SettingsPanel/MasterVolumeRow/MasterVolumeLabel", &"UI_MASTER_VOLUME")
	_set_label_text("Center/Panel/MarginContainer/Layout/SettingsPanel/MusicVolumeRow/MusicVolumeLabel", &"UI_MUSIC_VOLUME_PLACEHOLDER")
	_set_label_text("Center/Panel/MarginContainer/Layout/SettingsPanel/SfxVolumeRow/SfxVolumeLabel", &"UI_SFX_VOLUME")


func _set_label_text(path: String, key: StringName) -> void:
	var label := get_node_or_null(path) as Label
	if label != null:
		label.text = tr(key)


func _set_button_text(path: String, key: StringName) -> void:
	var button := get_node_or_null(path) as Button
	if button != null:
		button.text = tr(key)


func _sync_language_button() -> void:
	var current_locale := _current_locale()
	for index: int in range(_locales.size()):
		if String(_locales[index].get("code", "")) == current_locale:
			_language_button.select(index)
			return


func _connect_localization() -> void:
	var localization := _get_localization()
	if localization == null or not localization.has_signal(&"locale_changed"):
		return
	if not localization.is_connected(&"locale_changed", _on_locale_changed):
		localization.connect(&"locale_changed", _on_locale_changed)


func _on_locale_changed(_locale_code: String) -> void:
	_apply_text()
	_sync_language_button()


func _get_supported_locales() -> Array[Dictionary]:
	var localization := _get_localization()
	if localization != null and localization.has_method(&"get_supported_locales"):
		var locales: Variant = localization.call(&"get_supported_locales")
		if locales is Array:
			var typed_locales: Array[Dictionary] = []
			for locale: Variant in locales:
				if locale is Dictionary:
					typed_locales.append(locale)
			return typed_locales
	return _locales


func _current_locale() -> String:
	var localization := _get_localization()
	if localization != null and localization.has_method(&"get_locale"):
		return String(localization.call(&"get_locale"))
	return "en" if TranslationServer.get_locale() == "en" else "zh_CN"


func _get_localization() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Localization") if tree != null else null
