extends Node2D

@onready var line: Line2D = $Line2D
@onready var glow_line: Line2D = $GlowLine2D

var _from_position: Vector2
var _to_position: Vector2


func configure(from_position: Vector2, to_position: Vector2) -> void:
	global_position = Vector2.ZERO
	_from_position = from_position
	_to_position = to_position
	_set_draw_progress(0.0)
	line.modulate.a = 0.0
	glow_line.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_draw_progress, 0.0, 1.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(line, "modulate:a", 1.0, 0.04)
	tween.tween_property(glow_line, "modulate:a", 0.7, 0.04)
	tween.chain().tween_interval(0.06)
	tween.chain().set_parallel(true)
	tween.tween_property(line, "modulate:a", 0.0, 0.16)
	tween.tween_property(glow_line, "modulate:a", 0.0, 0.16)
	tween.finished.connect(queue_free)


func _set_draw_progress(progress: float) -> void:
	var endpoint: Vector2 = _from_position.lerp(_to_position, progress)
	var points := PackedVector2Array([_from_position, endpoint])
	line.points = points
	glow_line.points = points
