extends Control
class_name PausePanel

signal exit_requested

const UI_LABEL_SETTINGS: LabelSettings = preload("res://Themes/new_label_settings.tres")
const EN_FONT: FontFile = preload("res://Assets/Fonts/quaver.ttf")
const UI_FONT_SIZE: int = 12
const PAUSE_ACTION: StringName = &"pause_game"

const LOCALES: Array[Dictionary] = [
	{"code": "zh_CN", "name": "中文"},
	{"code": "en", "name": "English"},
]

const TEXT: Dictionary = {
	"en": {
		"UI_PAUSE_TITLE": "Paused",
		"UI_CONTINUE": "Continue",
		"UI_SETTINGS_TITLE": "Settings",
		"UI_EXIT": "Exit",
		"UI_LANGUAGE": "Language",
		"UI_MASTER_VOLUME": "Total Volume",
		"UI_MUSIC_VOLUME_PLACEHOLDER": "Music (placeholder)",
		"UI_SFX_VOLUME": "SFX Volume",
	},
	"zh_CN": {
		"UI_PAUSE_TITLE": "暂停",
		"UI_CONTINUE": "继续",
		"UI_SETTINGS_TITLE": "设置",
		"UI_EXIT": "退出",
		"UI_LANGUAGE": "语言",
		"UI_MASTER_VOLUME": "总音量",
		"UI_MUSIC_VOLUME_PLACEHOLDER": "音乐（占位）",
		"UI_SFX_VOLUME": "音效大小",
	},
}

@export var quit_on_exit: bool = true

var _settings_visible: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layout_direction = Control.LAYOUT_DIRECTION_LOCALE
	_ensure_pause_action()
	_ensure_supported_locale()
	_bind_signals()
	_setup_language_button()
	_setup_volume_sliders()
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
	if language_button.item_count == 0:
		for locale: Dictionary in LOCALES:
			language_button.add_item(String(locale.get("name", locale.get("code", ""))))
	var callback := Callable(self, "_on_language_selected")
	if not language_button.item_selected.is_connected(callback):
		language_button.item_selected.connect(callback)
	_sync_language_button()
	_apply_option_button_font(language_button)


func _on_language_selected(index: int) -> void:
	if index < 0 or index >= LOCALES.size():
		return
	TranslationServer.set_locale(String(LOCALES[index].get("code", "zh_CN")))
	_apply_text()
	_sync_language_button()


func _setup_volume_sliders() -> void:
	_configure_volume_placeholder("Center/Panel/MarginContainer/Layout/SettingsPanel/MasterVolumeRow/MasterVolumeSlider")
	_configure_volume_placeholder("Center/Panel/MarginContainer/Layout/SettingsPanel/MusicVolumeRow/MusicVolumeSlider")
	_configure_volume_placeholder("Center/Panel/MarginContainer/Layout/SettingsPanel/SfxVolumeRow/SfxVolumeSlider")


func _configure_volume_placeholder(path: String) -> void:
	var slider: HSlider = _node(path) as HSlider
	if slider == null:
		return
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = 1.0
	slider.editable = false


func _apply_text() -> void:
	_set_label_text("Center/Panel/MarginContainer/Layout/TitleLabel", "UI_PAUSE_TITLE")
	_set_button_text("Center/Panel/MarginContainer/Layout/ButtonRow/ContinueButton", "UI_CONTINUE")
	_set_button_text("Center/Panel/MarginContainer/Layout/ButtonRow/SettingsButton", "UI_SETTINGS_TITLE")
	_set_button_text("Center/Panel/MarginContainer/Layout/ButtonRow/ExitButton", "UI_EXIT")
	_set_label_text("Center/Panel/MarginContainer/Layout/SettingsPanel/LanguageRow/LanguageLabel", "UI_LANGUAGE")
	_set_label_text("Center/Panel/MarginContainer/Layout/SettingsPanel/MasterVolumeRow/MasterVolumeLabel", "UI_MASTER_VOLUME")
	_set_label_text("Center/Panel/MarginContainer/Layout/SettingsPanel/MusicVolumeRow/MusicVolumeLabel", "UI_MUSIC_VOLUME_PLACEHOLDER")
	_set_label_text("Center/Panel/MarginContainer/Layout/SettingsPanel/SfxVolumeRow/SfxVolumeLabel", "UI_SFX_VOLUME")
	var language_button: OptionButton = _node("Center/Panel/MarginContainer/Layout/SettingsPanel/LanguageRow/LanguageButton") as OptionButton
	if language_button != null:
		_apply_option_button_font(language_button)


func _set_label_text(path: String, key: String) -> void:
	var label: Label = _node(path) as Label
	if label == null:
		return
	label.text = _translate(key)
	label.label_settings = _label_settings_for_locale()


func _set_button_text(path: String, key: String) -> void:
	var button: Button = _node(path) as Button
	if button == null:
		return
	button.text = _translate(key)
	button.focus_mode = Control.FOCUS_ALL
	_apply_button_font(button)


func _set_settings_visible(should_show: bool) -> void:
	var settings_panel: Control = _node("Center/Panel/MarginContainer/Layout/SettingsPanel") as Control
	if settings_panel != null:
		settings_panel.visible = should_show


func _sync_language_button() -> void:
	var language_button: OptionButton = _node("Center/Panel/MarginContainer/Layout/SettingsPanel/LanguageRow/LanguageButton") as OptionButton
	if language_button == null:
		return
	var current_locale := _current_locale()
	for index: int in range(LOCALES.size()):
		if String(LOCALES[index].get("code", "")) == current_locale:
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


func _translate(key: String) -> String:
	var locale_text: Dictionary = TEXT.get(_current_locale(), TEXT["zh_CN"])
	return String(locale_text.get(key, key))


func _current_locale() -> String:
	return "en" if TranslationServer.get_locale() == "en" else "zh_CN"


func _label_settings_for_locale() -> LabelSettings:
	if _current_locale() == "en":
		return UI_LABEL_SETTINGS
	var settings := LabelSettings.new()
	settings.font_size = UI_FONT_SIZE
	return settings


func _apply_button_font(button: Button) -> void:
	if _current_locale() == "en":
		button.add_theme_font_override(&"font", EN_FONT)
	else:
		button.remove_theme_font_override(&"font")
	button.add_theme_font_size_override(&"font_size", UI_FONT_SIZE)


func _apply_option_button_font(button: OptionButton) -> void:
	if _current_locale() == "en":
		button.add_theme_font_override(&"font", EN_FONT)
		button.get_popup().add_theme_font_override(&"font", EN_FONT)
	else:
		button.remove_theme_font_override(&"font")
		button.get_popup().remove_theme_font_override(&"font")
	button.add_theme_font_size_override(&"font_size", UI_FONT_SIZE)
	button.get_popup().add_theme_font_size_override(&"font_size", UI_FONT_SIZE)


func _node(path: String) -> Node:
	return get_node_or_null(path)
