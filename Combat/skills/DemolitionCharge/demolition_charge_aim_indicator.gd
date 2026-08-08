extends Node2D
class_name DemolitionChargeAimIndicator

## 抛射炸弹瞄准指示器：无方向箭头，只画一条从弹珠 Head 到鼠标落点的虚线
## 抛物线预览，以及落点小圈。鼠标直接定位，距离钳制到 aim_max_distance。
## process_mode=ALWAYS：慢镜头（Engine.time_scale<1）下仍按真实时间刷新。

var _head: Node2D = null
var _max_distance: float = 160.0
var _arc_height: float = 60.0
var _arc_steps: int = 24
var _target_pos: Vector2 = Vector2.ZERO
var _manual_target: Vector2 = Vector2.ZERO
var _has_manual_target: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func configure(head: Node2D, max_distance: float, arc_height: float, arc_steps: int) -> void:
	_head = head
	_max_distance = maxf(16.0, max_distance)
	_arc_height = maxf(0.0, arc_height)
	_arc_steps = maxi(8, arc_steps)
	_update_target_position()
	queue_redraw()


func _process(_delta: float) -> void:
	if _update_target_position():
		queue_redraw()


## 计算鼠标落点（含距离钳制）。返回 true 表示目标有变化（触发重绘）。
func _update_target_position() -> bool:
	if _head == null or not is_instance_valid(_head):
		return false
	var raw: Vector2
	if _has_manual_target:
		raw = _manual_target
	else:
		var viewport := get_viewport()
		if viewport == null:
			raw = _head.global_position + Vector2(_max_distance, 0.0)
		else:
			raw = get_global_mouse_position()
	var offset: Vector2 = raw - _head.global_position
	if offset.length() > _max_distance:
		offset = offset.normalized() * _max_distance
	var next_target: Vector2 = _head.global_position + offset
	var changed: bool = next_target != _target_pos
	_target_pos = next_target
	return changed


func get_aim_target() -> Vector2:
	return _target_pos


func has_valid_target() -> bool:
	return _head != null and is_instance_valid(_head) and _head.is_inside_tree()


## 测试注入：固定落点，绕过 get_global_mouse_position（无鼠标的 headless 环境）。
func set_manual_target(target: Vector2) -> void:
	_manual_target = target
	_has_manual_target = true
	_update_target_position()
	queue_redraw()


func clear_manual_target() -> void:
	_has_manual_target = false
	queue_redraw()


func _draw() -> void:
	if _head == null or not is_instance_valid(_head):
		return
	var start: Vector2 = _head.global_position
	var end: Vector2 = _target_pos
	var color := Color(1.0, 0.6, 0.25, 0.9)
	# 隔段绘制成虚线：每段命中则画，否则跳过。
	var dash_on := true
	var last_local: Vector2 = to_local(start)
	var step: float = 1.0 / float(maxi(1, _arc_steps))
	for index: int in range(1, _arc_steps + 1):
		var t: float = step * index
		var point_local: Vector2 = to_local(_parabola_point(start, end, t))
		if dash_on:
			draw_line(last_local, point_local, color, 2.0)
		dash_on = not dash_on
		last_local = point_local
	draw_arc(to_local(end), 6.0, 0.0, TAU, 24, color, 2.0)


func _parabola_point(start: Vector2, end: Vector2, t: float) -> Vector2:
	return start.lerp(end, t) + Vector2(0.0, -_arc_height * sin(PI * t))
