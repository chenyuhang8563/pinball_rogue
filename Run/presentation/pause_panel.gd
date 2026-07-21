extends Control
class_name PausePanel

signal exit_requested

const PAUSE_ACTION: StringName = &"pause_game"

@export var quit_on_exit: bool = true

var _settings_visible: bool = false
var _locales: Array[Dictionary] = [
	{"code": "zh_CN", "name": "中文"},
	{"code": "en", "name": "English"},
]


func _ready() -> void:
	_ensure_pause_action()
	_ensure_supported_locale()
	_connect_localization()
	_bind_signals()
	_setup_language_button()
	_apply_text()
	close_pause()


func _unhandled_input(event: InputEvent) -> void:
	if _is_pause_event(event):
		toggle_pause()
		get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	if visible:
		close_pause()
	else:
		open_pause()


func open_pause() -> void:
	show()
	_settings_visible = false
	_set_settings_visible(false)
	get_tree().paused = true
	_grab_default_focus()


func close_pause() -> void:
	hide()
	get_tree().paused = false


func _bind_signals() -> void:
	var continue_button: Button = _node("Center/Panel/MarginContainer/Layout/ButtonRow/ContinueButton") as Button
	if continue_button != null and not continue_button.pressed.is_connected(close_pause):
		continue_button.pressed.connect(close_pause)

	var settings_button: Button = _node("Center/Panel/MarginContainer/Layout/ButtonRow/SettingsButton") as Button
	if settings_button != null and not settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)

	var exit_button: Button = _node("Center/Panel/MarginContainer/Layout/ButtonRow/ExitButton") as Button
	if exit_button != null and not exit_button.pressed.is_connected(_on_exit_pressed):
		exit_button.pressed.connect(_on_exit_pressed)


func _on_settings_pressed() -> void:
	_settings_visible = not _settings_visible
	_set_settings_visible(_settings_visible)


func _on_exit_pressed() -> void:
	exit_requested.emit()
	if quit_on_exit:
		get_tree().quit()


func _setup_language_button() -> void:
	var language_button: OptionButton = _node("Center/Panel/MarginContainer/Layout/SettingsPanel/LanguageRow/LanguageButton") as OptionButton
	if language_button == null:
		return
	_locales = _get_supported_locales()
	language_button.clear()
	for locale: Dictionary in _locales:
		language_button.add_item(String(locale.get("name", locale.get("code", ""))))
	var callback := Callable(self, "_on_language_selected")
	if not language_button.item_selected.is_connected(callback):
		language_button.item_selected.connect(callback)
	_sync_language_button()


func _on_language_selected(index: int) -> void:
	if index < 0 or index >= _locales.size():
		return
	var locale_code := String(_locales[index].get("code", "zh_CN"))
	var localization := _get_localization()
	if localization != null and localization.has_method("set_locale"):
		localization.call("set_locale", locale_code)
	else:
		TranslationServer.set_locale(locale_code)
		_apply_text()
	_sync_language_button()


func _apply_text() -> void:
	_set_label_text("Center/Panel/MarginContainer/Layout/TitleLabel", "UI_PAUSE_TITLE")
	_set_button_text("Center/Panel/MarginContainer/Layout/ButtonRow/ContinueButton", "UI_CONTINUE")
	_set_button_text("Center/Panel/MarginContainer/Layout/ButtonRow/SettingsButton", "UI_SETTINGS_TITLE")
	_set_button_text("Center/Panel/MarginContainer/Layout/ButtonRow/ExitButton", "UI_EXIT")
	_set_label_text("Center/Panel/MarginContainer/Layout/SettingsPanel/LanguageRow/LanguageLabel", "UI_LANGUAGE")
	_set_label_text("Center/Panel/MarginContainer/Layout/SettingsPanel/MasterVolumeRow/MasterVolumeLabel", "UI_MASTER_VOLUME")
	_set_label_text("Center/Panel/MarginContainer/Layout/SettingsPanel/MusicVolumeRow/MusicVolumeLabel", "UI_MUSIC_VOLUME_PLACEHOLDER")
	_set_label_text("Center/Panel/MarginContainer/Layout/SettingsPanel/SfxVolumeRow/SfxVolumeLabel", "UI_SFX_VOLUME")


func _set_label_text(path: String, key: String) -> void:
	var label: Label = _node(path) as Label
	if label == null:
		return
	label.text = tr(key)


func _set_button_text(path: String, key: String) -> void:
	var button: Button = _node(path) as Button
	if button == null:
		return
	button.text = tr(key)


func _set_settings_visible(should_show: bool) -> void:
	var settings_panel: Control = _node("Center/Panel/MarginContainer/Layout/SettingsPanel") as Control
	if settings_panel != null:
		settings_panel.visible = should_show


func _sync_language_button() -> void:
	var language_button: OptionButton = _node("Center/Panel/MarginContainer/Layout/SettingsPanel/LanguageRow/LanguageButton") as OptionButton
	if language_button == null:
		return
	var current_locale := _current_locale()
	for index: int in range(_locales.size()):
		if String(_locales[index].get("code", "")) == current_locale:
			language_button.select(index)
			return


func _is_pause_event(event: InputEvent) -> bool:
	if event.is_action_pressed(PAUSE_ACTION) or event.is_action_pressed(&"ui_cancel"):
		return true
	if not event is InputEventKey:
		return false
	var key_event: InputEventKey = event as InputEventKey
	return key_event.pressed and not key_event.echo and (key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE)


func _ensure_pause_action() -> void:
	if not InputMap.has_action(PAUSE_ACTION):
		InputMap.add_action(PAUSE_ACTION)
	if not _action_has_key(PAUSE_ACTION, KEY_ESCAPE):
		var event := InputEventKey.new()
		event.physical_keycode = KEY_ESCAPE
		InputMap.action_add_event(PAUSE_ACTION, event)


func _action_has_key(action: StringName, key: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			if key_event.keycode == key or key_event.physical_keycode == key:
				return true
	return false


func _grab_default_focus() -> void:
	var continue_button: Button = _node("Center/Panel/MarginContainer/Layout/ButtonRow/ContinueButton") as Button
	if continue_button != null and is_inside_tree():
		continue_button.grab_focus()


func _ensure_supported_locale() -> void:
	var locale := TranslationServer.get_locale()
	if locale != "zh_CN" and locale != "en":
		TranslationServer.set_locale("zh_CN")


func _current_locale() -> String:
	var localization := _get_localization()
	if localization != null and localization.has_method("get_locale"):
		return String(localization.call("get_locale"))
	return "en" if TranslationServer.get_locale() == "en" else "zh_CN"


func _connect_localization() -> void:
	var localization := _get_localization()
	if localization == null or not localization.has_signal(&"locale_changed"):
		return
	var callback := Callable(self, "_on_locale_changed")
	if not localization.is_connected(&"locale_changed", callback):
		localization.connect(&"locale_changed", callback)


func _on_locale_changed(_locale_code: String) -> void:
	_apply_text()
	_sync_language_button()


func _get_supported_locales() -> Array[Dictionary]:
	var localization := _get_localization()
	if localization != null and localization.has_method("get_supported_locales"):
		var locales: Variant = localization.call("get_supported_locales")
		if locales is Array:
			var typed_locales: Array[Dictionary] = []
			for locale: Variant in locales:
				if locale is Dictionary:
					typed_locales.append(locale)
			return typed_locales
	return _locales


func _get_localization() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("Localization")


func _node(path: String) -> Node:
	return get_node_or_null(path)
