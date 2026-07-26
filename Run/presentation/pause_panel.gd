extends Control
class_name PausePanel

signal settings_requested
signal exit_requested

const PAUSE_ACTION: StringName = &"pause_game"

@export var quit_on_exit: bool = true

var _settings_open: bool = false

@onready var _animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_ensure_pause_action()
	_bind_signals()
	_apply_text()
	close_pause()


func _unhandled_input(event: InputEvent) -> void:
	if _settings_open or not _is_pause_event(event):
		return
	toggle_pause()
	get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	if visible:
		close_pause()
	else:
		open_pause()


func open_pause() -> void:
	_settings_open = false
	_animation_player.play(&"show_pause")
	get_tree().paused = true
	_grab_default_focus()


func close_pause() -> void:
	_settings_open = false
	_animation_player.play(&"hide_pause")
	get_tree().paused = false


func hide_for_settings() -> void:
	_settings_open = true
	_animation_player.play(&"hide_pause")


func reopen_from_settings() -> void:
	_settings_open = false
	_animation_player.play(&"show_pause")
	get_tree().paused = true
	_grab_default_focus()


func _bind_signals() -> void:
	var continue_button := _node("Center/Panel/MarginContainer/Layout/ButtonRow/ContinueButton") as Button
	if continue_button != null and not continue_button.pressed.is_connected(close_pause):
		continue_button.pressed.connect(close_pause)
	var settings_button := _node("Center/Panel/MarginContainer/Layout/ButtonRow/SettingsButton") as Button
	if settings_button != null and not settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)
	var exit_button := _node("Center/Panel/MarginContainer/Layout/ButtonRow/ExitButton") as Button
	if exit_button != null and not exit_button.pressed.is_connected(_on_exit_pressed):
		exit_button.pressed.connect(_on_exit_pressed)


func _on_settings_pressed() -> void:
	_settings_open = true
	settings_requested.emit()


func _on_exit_pressed() -> void:
	exit_requested.emit()
	if quit_on_exit:
		get_tree().quit()


func _apply_text() -> void:
	_set_label_text("Center/Panel/MarginContainer/Layout/TitleLabel", &"UI_PAUSE_TITLE")
	_set_button_text("Center/Panel/MarginContainer/Layout/ButtonRow/ContinueButton", &"UI_CONTINUE")
	_set_button_text("Center/Panel/MarginContainer/Layout/ButtonRow/SettingsButton", &"UI_SETTINGS_TITLE")
	_set_button_text("Center/Panel/MarginContainer/Layout/ButtonRow/ExitButton", &"UI_EXIT")


func _set_label_text(path: String, key: StringName) -> void:
	var label := _node(path) as Label
	if label != null:
		label.text = tr(key)


func _set_button_text(path: String, key: StringName) -> void:
	var button := _node(path) as Button
	if button != null:
		button.text = tr(key)


func _is_pause_event(event: InputEvent) -> bool:
	if event.is_action_pressed(PAUSE_ACTION) or event.is_action_pressed(&"ui_cancel"):
		return true
	if not event is InputEventKey:
		return false
	var key_event := event as InputEventKey
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
			var key_event := event as InputEventKey
			if key_event.keycode == key or key_event.physical_keycode == key:
				return true
	return false


func _grab_default_focus() -> void:
	var continue_button := _node("Center/Panel/MarginContainer/Layout/ButtonRow/ContinueButton") as Button
	if continue_button != null and is_inside_tree():
		continue_button.grab_focus()


func _node(path: String) -> Node:
	return get_node_or_null(path)
