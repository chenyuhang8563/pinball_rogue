extends Area2D
class_name SparkProjectile

## 火星弹射物：从燃烧敌人飞向邻近目标，抵达后施加 1 层燃烧燃料。
## 使用 Tween 驱动抛物线飞行，不依赖物理引擎。

const FIRE_BURN_DEBUFF_ID: String = "fire_burn_debuff"
const FLIGHT_DURATION: float = 0.22
const ARC_HEIGHT: float = 28.0

var _target: WeakRef = WeakRef.new()
var _start_pos: Vector2 = Vector2.ZERO
var _end_pos: Vector2 = Vector2.ZERO
var _progress: float = 0.0
var _arrived: bool = false


func spawn_from(scene: Node, source_pos: Vector2, target: Node2D) -> void:
	if scene == null or not is_instance_valid(scene) or target == null or not is_instance_valid(target):
		queue_free()
		return
	scene.add_child(self)
	setup(source_pos, target)


func setup(source_pos: Vector2, target: Node2D) -> void:
	_start_pos = source_pos
	_target = weakref(target)
	_end_pos = target.global_position
	global_position = source_pos
	rotation = source_pos.angle_to_point(_end_pos)
	var tween: Tween = create_tween()
	tween.tween_property(self, "_progress", 1.0, FLIGHT_DURATION)
	tween.tween_callback(_on_arrive)


func _process(_delta: float) -> void:
	if _arrived:
		return
	var t: float = _progress
	var linear_pos: Vector2 = _start_pos.lerp(_end_pos, t)
	var arc_offset: float = -ARC_HEIGHT * sin(PI * t)
	global_position = linear_pos + Vector2(0.0, arc_offset)


func _on_arrive() -> void:
	_arrived = true
	var target: Node2D = _target.get_ref() as Node2D
	if target != null and is_instance_valid(target):
		if not (target.has_method("is_alive") and not bool(target.call("is_alive"))):
			if target.has_method("add_buff"):
				var burn: BuffDef = _make_buff(FIRE_BURN_DEBUFF_ID)
				if burn != null:
					target.call("add_buff", burn, 1)
	queue_free()


func _make_buff(buff_id: String) -> BuffDef:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var registry: Node = tree.root.get_node_or_null("BuffRegistry")
	if registry == null or not registry.has_method("get_buff_def"):
		return null
	return registry.call("get_buff_def", buff_id) as BuffDef
