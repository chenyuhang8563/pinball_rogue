extends Node2D
class_name ArcStatusVisual

@export var ring_radius: float = 13.0
@export var node_radius: float = 1.35
@export var stable_color: Color = Color(0.45, 0.82, 1.0, 0.95)
@export var core_color: Color = Color(0.9, 0.98, 1.0, 1.0)

var _stacks: int = 1
var _remaining_time: float = ArcDebuff.DURATION_SECONDS


func _process(_delta: float) -> void:
	queue_redraw()


func set_arc_state(stacks: int, remaining_time: float) -> void:
	_stacks = clampi(stacks, 1, ArcDebuff.HARD_MAX_STACKS)
	_remaining_time = maxf(0.0, remaining_time)
	queue_redraw()


func _draw() -> void:
	var flash_alpha: float = 1.0
	if _remaining_time < 1.0:
		flash_alpha = 1.0 if fmod(Time.get_ticks_msec() / 1000.0, 0.22) < 0.11 else 0.25
	var color := Color(stable_color, stable_color.a * flash_alpha)
	var segment_angle: float = TAU / float(ArcDebuff.HARD_MAX_STACKS)
	for index: int in range(_stacks):
		var angle: float = -PI * 0.5 + segment_angle * float(index)
		var point := Vector2.from_angle(angle) * ring_radius
		draw_circle(point, node_radius + 0.8, Color(stable_color, 0.28 * flash_alpha))
		draw_circle(point, node_radius, core_color)
		if index > 0:
			var previous_angle: float = angle - segment_angle
			var previous := Vector2.from_angle(previous_angle) * ring_radius
			draw_arc(Vector2.ZERO, ring_radius, previous_angle, angle, 8, color, 0.8, true)
	if _stacks >= ArcDebuff.HARD_MAX_STACKS:
		draw_arc(Vector2.ZERO, ring_radius, -PI * 0.5, TAU - PI * 0.5, 32, color, 1.1, true)
