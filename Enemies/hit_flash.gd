extends Node

@onready var sprite: Sprite2D = $"../Sprite2D"

var sprite_material: ShaderMaterial
var hit_flash_tween: Tween

func _ready() -> void:
	sprite_material = sprite.material

func flash() -> void:
	if hit_flash_tween != null and hit_flash_tween.is_valid():
		hit_flash_tween.kill()

	sprite_material.set_shader_parameter("percent", 1.0)
	hit_flash_tween = create_tween()
	hit_flash_tween.tween_property(sprite_material, "shader_parameter/percent", 0.0, 0.2)
