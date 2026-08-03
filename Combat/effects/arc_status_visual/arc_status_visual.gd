extends Node2D
class_name ArcStatusVisual

@onready var _arc: AnimatedSprite2D = $Arc

var _remaining_time: float = ArcDebuff.DURATION_SECONDS


func _process(_delta: float) -> void:
	_arc.modulate.a = 1.0 if _remaining_time >= 1.0 else (1.0 if fmod(Time.get_ticks_msec() / 1000.0, 0.22) < 0.11 else 0.25)


func set_arc_state(_stacks: int, remaining_time: float) -> void:
	_remaining_time = maxf(0.0, remaining_time)
