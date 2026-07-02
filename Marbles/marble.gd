# 基础弹珠 —— 链中唯一的 RigidBody2D（Head）。
# 当作为 MarbleChain 的 Head 时，碰撞伤害委托给 MarbleChain.get_total_damage() 聚合所有 Body 段。
# 非链模式（legacy）时回退到自身的 damage 值。
#
# Body 段为 ChainSegment（纯视觉 Node2D），不再继承本类。

extends RigidBody2D
class_name Marble

@export var damage: int = 1
@export var max_speed := 800.0

@export var dash_impulse: float = 200.0
@export var dash_max_speed: float = 850.0
@export var dash_duration: float = 0.3

enum MARBLE_TYPE {
	DEFAULT,
	BROWN,
	BOMB,
	GREEN
}

@export var marble_type: MARBLE_TYPE = MARBLE_TYPE.DEFAULT

## 标记本节点为 MarbleChain 的 Head。由 MarbleChain.build_chain() 设置。
var is_head: bool = false

var init_position: Vector2
var _dash_active: bool = false
var _dash_timer: Timer


func _ready() -> void:
	init_position = position
	_dash_timer = Timer.new()
	_dash_timer.one_shot = true
	_dash_timer.timeout.connect(_on_dash_timer_timeout)
	add_child(_dash_timer)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var speed_limit: float = dash_max_speed if _dash_active else max_speed
	if state.linear_velocity.length() > speed_limit:
		state.linear_velocity = state.linear_velocity.normalized() * speed_limit


## 接触伤害。Head 模式下委托给 MarbleChain 聚合所有段；非链模式回退到自身 damage。
func get_hit_damage(_target: Node) -> int:
	var parent_node: Node = get_parent()
	if parent_node is MarbleChain:
		return (parent_node as MarbleChain).get_total_damage(_target)
	return damage


func dash_toward(direction: Vector2) -> void:
	if _dash_active:
		return
	_dash_active = true
	# 唤醒休眠的物理体，否则 apply_central_impulse 不会生效
	set_sleeping(false)
	# Clear existing velocity so the impulse isn't diluted by prior momentum.
	linear_velocity = Vector2.ZERO
	apply_central_impulse(direction * dash_impulse)
	_dash_timer.start(dash_duration)


func _on_dash_timer_timeout() -> void:
	_dash_active = false
