extends GutTest

const PausePanelScene: PackedScene = preload("res://UI/pause_panel.tscn")

var _previous_locale: String = ""


func before_each() -> void:
	_previous_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")


func after_each() -> void:
	TranslationServer.set_locale(_previous_locale)
	get_tree().paused = false


func test_pause_panel_scene_has_expected_controls() -> void:
	var panel: Control = add_child_autofree(PausePanelScene.instantiate())

	assert_not_null(panel.get_node_or_null("Center/Panel/MarginContainer/Layout/ButtonRow/ContinueButton"))
	assert_not_null(panel.get_node_or_null("Center/Panel/MarginContainer/Layout/ButtonRow/SettingsButton"))
	assert_not_null(panel.get_node_or_null("Center/Panel/MarginContainer/Layout/ButtonRow/ExitButton"))
	assert_not_null(panel.get_node_or_null("Center/Panel/MarginContainer/Layout/SettingsPanel/LanguageRow/LanguageButton"))
	assert_false((panel.get_node("Center/Panel/MarginContainer/Layout/SettingsPanel/MasterVolumeRow/MasterVolumeSlider") as HSlider).editable)
	assert_false((panel.get_node("Center/Panel/MarginContainer/Layout/SettingsPanel/MusicVolumeRow/MusicVolumeSlider") as HSlider).editable)
	assert_false((panel.get_node("Center/Panel/MarginContainer/Layout/SettingsPanel/SfxVolumeRow/SfxVolumeSlider") as HSlider).editable)


func test_escape_toggles_pause_and_continue_resumes_game() -> void:
	var panel: Control = add_child_autofree(PausePanelScene.instantiate())

	panel._unhandled_input(_escape_event())
	assert_true(panel.visible)
	assert_true(get_tree().paused)

	var continue_button := panel.get_node("Center/Panel/MarginContainer/Layout/ButtonRow/ContinueButton") as Button
	continue_button.pressed.emit()

	assert_false(panel.visible)
	assert_false(get_tree().paused)


func test_settings_language_switch_refreshes_pause_labels() -> void:
	var panel: Control = add_child_autofree(PausePanelScene.instantiate())

	var settings_button := panel.get_node("Center/Panel/MarginContainer/Layout/ButtonRow/SettingsButton") as Button
	settings_button.pressed.emit()
	assert_true(panel.get_node("Center/Panel/MarginContainer/Layout/SettingsPanel").visible)

	assert_eq(_label_text(panel, "Center/Panel/MarginContainer/Layout/TitleLabel"), "暂停")
	assert_eq(_button_text(panel, "Center/Panel/MarginContainer/Layout/ButtonRow/ContinueButton"), "继续")

	var language_button := panel.get_node("Center/Panel/MarginContainer/Layout/SettingsPanel/LanguageRow/LanguageButton") as OptionButton
	language_button.select(1)
	language_button.item_selected.emit(1)

	assert_eq(TranslationServer.get_locale(), "en")
	assert_eq(_label_text(panel, "Center/Panel/MarginContainer/Layout/TitleLabel"), "Paused")
	assert_eq(_button_text(panel, "Center/Panel/MarginContainer/Layout/ButtonRow/ContinueButton"), "Continue")


func test_exit_button_emits_request_without_quitting_when_disabled() -> void:
	var panel: Control = add_child_autofree(PausePanelScene.instantiate())
	panel.quit_on_exit = false
	watch_signals(panel)

	var exit_button := panel.get_node("Center/Panel/MarginContainer/Layout/ButtonRow/ExitButton") as Button
	exit_button.pressed.emit()

	assert_signal_emitted(panel, "exit_requested")


func _escape_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	return event


func _label_text(root: Node, path: String) -> String:
	var label := root.get_node_or_null(path) as Label
	assert_not_null(label)
	return "" if label == null else label.text


func _button_text(root: Node, path: String) -> String:
	var button := root.get_node_or_null(path) as Button
	assert_not_null(button)
	return "" if button == null else button.text
