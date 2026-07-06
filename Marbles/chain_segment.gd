# 蛇形弹珠链的身体段——纯视觉节点，不参与物理模拟。
# 仅 Head（Marble/RigidBody2D）参与物理；Body 段通过路径历史轨迹跟随 Head。
#
# 与旧版 BrownMarble / BombMarble 的关系：
# 回声堆叠（BROWN）逻辑内置于本段；
# 爆炸（BOMB）逻辑由 [MarbleChain] 统一调度，本段仅作为类型标记存在。

extends Node2D
class_name ChainSegment


## 本段对应的弹珠类型。
@export var segment_type: Marble.MARBLE_TYPE = Marble.MARBLE_TYPE.DEFAULT

## 本段贡献的接触伤害（BOMB 类型自身不贡献接触伤害，由爆炸替代）。
@export var damage: int = 1

# ---- BROWN（回声堆叠）专属字段 ----
@export var max_echo_stacks: int = 3
@export var echo_bonus_damage: int = 2
@export var echo_timeout: float = 5.0

## 当前回声层数。
var echo_stacks: int = 0

@onready var sprite: Sprite2D = $Sprite2D

var _echo_timer: Timer


func _ready() -> void:
	_echo_timer = Timer.new()
	_echo_timer.one_shot = true
	_echo_timer.timeout.connect(_clear_echo_stacks)
	add_child(_echo_timer)
	_update_echo_visual()


## 尝试叠加一层回声。仅对 BROWN 段生效。
func add_echo_stack() -> void:
	if segment_type != Marble.MARBLE_TYPE.BROWN:
		return
	echo_stacks = min(echo_stacks + 1, max_echo_stacks)
	_echo_timer.start(_get_echo_timeout())
	_update_echo_visual()


## 取当前回声加成的伤害。满层时返回 bonus_damage 并清空层数。
func get_echo_damage() -> int:
	if segment_type != Marble.MARBLE_TYPE.BROWN:
		return 0
	var bonus: int = roundi(_get_stat_float("echo_bonus_damage", float(echo_bonus_damage))) if echo_stacks >= max_echo_stacks else 0
	if bonus > 0:
		if _is_echo_awakened():
			echo_stacks = max(0, echo_stacks - 1)
			if echo_stacks > 0 and is_instance_valid(_echo_timer):
				_echo_timer.start(_get_echo_timeout())
			_update_echo_visual()
		else:
			_clear_echo_stacks()
	return bonus


func _clear_echo_stacks() -> void:
	echo_stacks = 0
	if is_instance_valid(_echo_timer):
		_echo_timer.stop()
	_update_echo_visual()


## 用 sprite 的 modulate 反映回声层数（绿色渐深）。
func _update_echo_visual() -> void:
	if sprite == null:
		return
	if segment_type != Marble.MARBLE_TYPE.BROWN:
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		return
	var charge_ratio: float = float(echo_stacks) / float(max_echo_stacks)
	sprite.modulate = Color(1.0, 1.0 + charge_ratio * 0.25, 1.0 - charge_ratio * 0.2)


func _get_echo_timeout() -> float:
	return _get_stat_float("echo_timeout", echo_timeout)


func _is_echo_awakened() -> bool:
	return _get_echo_timeout() >= 15.0


func _get_stat_float(stat_id: String, fallback: float) -> float:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return fallback
	var stat_system: Node = tree.root.get_node_or_null("StatSystem")
	if stat_system == null or not stat_system.has_method("get_stat"):
		return fallback
	return float(stat_system.call("get_stat", stat_id, "marble_chain"))
