extends Control
class_name RunFailurePanel

signal restart_requested

@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _title_label: Label = $Center/Panel/MarginContainer/Layout/TitleLabel
@onready var _confirm_button: Button = $Center/Panel/MarginContainer/Layout/ConfirmButton


func _ready() -> void:
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_connect_localization()
	_apply_text()
	_animation_player.play(&"hide_failure")


func _unhandled_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()


func open_failure() -> void:
	if visible:
		return
	_animation_player.play(&"show_failure")
	get_tree().paused = true
	_confirm_button.call_deferred(&"grab_focus")


func close_failure() -> void:
	_animation_player.play(&"hide_failure")
	get_tree().paused = false


func _on_confirm_pressed() -> void:
	restart_requested.emit()


func _connect_localization() -> void:
	var localization: Node = get_tree().root.get_node_or_null("Localization")
	if localization == null or not localization.has_signal(&"locale_changed"):
		return
	var callback: Callable = Callable(self, "_on_locale_changed")
	if not localization.is_connected(&"locale_changed", callback):
		localization.connect(&"locale_changed", callback)


func _on_locale_changed(_locale_code: String) -> void:
	_apply_text()


func _apply_text() -> void:
	_title_label.text = tr("RUN_FAILED_TITLE")
	_confirm_button.text = tr("RUN_FAILED_CONFIRM")
