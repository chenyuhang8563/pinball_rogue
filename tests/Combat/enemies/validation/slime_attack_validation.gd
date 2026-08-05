extends Node2D

@export var attack_profile: Resource

@onready var slime: Enemy = $Slime


func _ready() -> void:
	if attack_profile != null:
		slime.configure_attack(attack_profile)
