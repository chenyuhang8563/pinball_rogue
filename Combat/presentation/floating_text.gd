extends Node2D

signal animation_finished

@onready var label: Label = $Label

var position_tween: Tween = null
var scale_tween: Tween = null


func _ready() -> void:
	scale = Vector2.ZERO


## Kills all in-flight tweens. Called when the text is forcibly recycled
## (e.g. battle transition) before the animation naturally completes.
func kill_tweens() -> void:
	if position_tween != null and position_tween.is_valid():
		position_tween.kill()
		position_tween = null
	if scale_tween != null and scale_tween.is_valid():
		scale_tween.kill()
		scale_tween = null


func display_damage_text(damage_amount: int) -> void:
	if position_tween != null and position_tween.is_valid():
		position_tween.kill()
	if scale_tween != null and scale_tween.is_valid():
		scale_tween.kill()

	label.text = str(damage_amount)
	scale = Vector2.ZERO
	var start_position: Vector2 = global_position

	position_tween = create_tween()
	scale_tween = create_tween()

	position_tween.tween_property(self, "global_position", start_position + Vector2.UP * 16.0, 0.3)
	scale_tween.tween_property(self, "scale", Vector2.ONE * 2, 0.15)
	scale_tween.tween_property(self, "scale", Vector2.ONE, 0.15)
	position_tween.tween_property(self, "global_position", start_position + Vector2.UP * 25.0, 0.3)
	scale_tween.tween_property(self, "scale", Vector2.ZERO, 0.3)
	scale_tween.finished.connect(_on_animation_tween_finished)


func _on_animation_tween_finished() -> void:
	position_tween = null
	scale_tween = null
	animation_finished.emit()
