extends Node

@onready var sprite: Sprite2D = $"../Sprite2D"

var sprite_material: ShaderMaterial
var hit_flash_tween: Tween
var _default_flash_color: Color = Color.WHITE

func _ready() -> void:
	sprite_material = sprite.material
	if sprite_material != null:
		sprite_material.set_shader_parameter("flash_color", _default_flash_color)

func flash(color: Color = Color.WHITE) -> void:
	if sprite_material == null:
		return
	if hit_flash_tween != null and hit_flash_tween.is_valid():
		hit_flash_tween.kill()

	sprite_material.set_shader_parameter("flash_color", color)
	sprite_material.set_shader_parameter("percent", 1.0)
	hit_flash_tween = create_tween()
	hit_flash_tween.tween_property(sprite_material, "shader_parameter/percent", 0.0, 0.2)


func set_flash_color(color: Color) -> void:
	_default_flash_color = color
	if sprite_material != null:
		sprite_material.set_shader_parameter("flash_color", color)
