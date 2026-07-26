extends Control

const GAME_SCENE: String = "res://Game/Bootstrap/main.tscn"

@onready var start_button: Button = $StartButton
@onready var resume_button: Button = $ResumeButton
@onready var exit_button: Button = $ExitButton
@onready var settings_button: Button = $SettingsButton
@onready var settings_panel: SettingsPanel = $SettingsPanel


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	settings_panel.continue_requested.connect(_on_settings_closed)
	settings_panel.back_requested.connect(_on_settings_closed)
	settings_panel.exit_requested.connect(_on_exit_pressed)


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_settings_pressed() -> void:
	settings_panel.present(false)


func _on_settings_closed() -> void:
	settings_panel.dismiss()


func _on_exit_pressed() -> void:
	get_tree().quit()
