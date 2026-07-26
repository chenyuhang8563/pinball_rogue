extends Control

const GAME_SCENE: String = "res://Game/Bootstrap/main.tscn"

@onready var start_button: Button = $StartButton
@onready var resume_button: Button = $ResumeButton
@onready var exit_button: Button = $ExitButton
@onready var settings_button: Button = $SettingsButton
@onready var settings_panel: SettingsPanel = $SettingsPanel


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	settings_panel.continue_requested.connect(_on_settings_closed)
	settings_panel.back_requested.connect(_on_settings_closed)
	settings_panel.exit_requested.connect(_on_exit_pressed)
	var repository := _save_repository()
	resume_button.disabled = repository == null or not bool(repository.call("has_valid_save"))


func _on_start_pressed() -> void:
	if _prepare_new_run():
		get_tree().change_scene_to_file(GAME_SCENE)


func _on_resume_pressed() -> void:
	if _prepare_continue_run():
		get_tree().change_scene_to_file(GAME_SCENE)


func _prepare_new_run() -> bool:
	var repository := _save_repository()
	if repository == null:
		return false
	repository.call("delete_save")
	repository.call("request_new_run")
	return true


func _prepare_continue_run() -> bool:
	var repository := _save_repository()
	return repository != null and bool(repository.call("request_continue_run"))


func _on_settings_pressed() -> void:
	settings_panel.present(false)


func _on_settings_closed() -> void:
	settings_panel.dismiss()


func _on_exit_pressed() -> void:
	get_tree().quit()


func _save_repository() -> Node:
	return get_tree().root.get_node_or_null(^"RunSaveRepository")
