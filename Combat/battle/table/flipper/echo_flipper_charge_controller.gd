# EchoFlipperChargeController —— 表级共享回响蓄力模块。
#
# 回响弹珠机制（BROWN 门控 + 累计进度）：
#   - 仅当当前链中存在 BROWN（大地）弹珠时生效：无 BROWN 时不充能、
#     不消费，挡板不显示任何蓄力轮廓。
#   - 每次敌人碰撞使共享蓄力进度 +CHARGE_PER_HIT（0.25），4 次碰撞累计满 1 层，
#     进度 0..MAX_PROGRESS(2.0)（8 次碰撞满 2 层）。
#   - 任一挡板成功弹起弹珠（marble_launched）且进度 >= 1.0（至少 1 个完整层）时：
#       消费 1.0 进度（不足整层的尾数保留），
#       · 追加速度冲量（按 echo_flipper_speed_multiplier 倍率），
#       · 通知当前链武装 1 个待结算伤害 token；
#   - 后续敌人碰撞结算时消费 1 个 token 并附加回响伤害；墙面/挡板碰撞不消费。
#
# 视觉（由 charge_changed 驱动，脚本不写节点视觉属性）：
#   - progress < 1：黄色轮廓从挡板一端增长，包裹满 = 1 层；
#   - progress >= 1：黄色包裹满后，红色轮廓开始增长，包裹满 = 2 层。
#
# 生命周期：
#   - 预置于 table_base.tscn。每场战斗重新实例化 → 蓄力从 0 开始（换桌清零）。
#   - 掉球导致 MarbleChain 重建时，新链通过 group 重新 bind_chain()，进度保留。

extends Node
class_name EchoFlipperChargeController

signal charge_changed(progress: float)

const GROUP_NAME: StringName = &"echo_charge_controller"
const CHAIN_GROUP_NAME: StringName = &"marble_chain"
## 每次敌人碰撞累计的进度（4 次 = 1 层）。
const CHARGE_PER_HIT: float = 0.25
## 总进度上限（2 层）。
const MAX_PROGRESS: float = 2.0
const DEFAULT_SPEED_MULTIPLIER: float = 1.5

var _progress: float = 0.0
var _chain: MarbleChain = null
var _has_brown: bool = false


func _ready() -> void:
	add_to_group(GROUP_NAME)
	_bind_flippers()
	_bind_current_chain()


func _exit_tree() -> void:
	unbind_chain()
	remove_from_group(GROUP_NAME)


## 当前共享蓄力进度（0..MAX_PROGRESS）。
func get_progress() -> float:
	return _progress


## 当前完整蓄力层数（0..2）：floor(progress)。
func get_layers() -> int:
	return floori(_progress)


## 当前链是否包含 BROWN 弹珠（机制是否激活）。
func has_brown() -> bool:
	return _has_brown


## 敌人碰撞入口：叠加一段进度，满进度后忽略。返回叠加后的进度。
func add_charge() -> float:
	if not _has_brown or _progress >= MAX_PROGRESS:
		return _progress
	_progress = minf(_progress + CHARGE_PER_HIT, MAX_PROGRESS)
	charge_changed.emit(_progress)
	return _progress


## 清空蓄力进度（用于表切换/重置；新表实例化时天然从 0 开始）。
func reset() -> void:
	if _progress == 0.0:
		return
	_progress = 0.0
	charge_changed.emit(_progress)


## 绑定当前弹珠链：监听其 chain_collision 事件并持有其引用以便武装伤害 token。
## 掉球重建链后，新链调用本方法完成重绑；进度保留。
func bind_chain(chain: MarbleChain) -> void:
	if chain == null or not is_instance_valid(chain) or _is_doomed(chain):
		return
	if chain == _chain:
		return
	unbind_chain()
	_chain = chain
	if not chain.chain_collision.is_connected(_on_chain_collision):
		chain.chain_collision.connect(_on_chain_collision)
	_has_brown = chain.has_brown_marble()
	if not _has_brown and _progress != 0.0:
		_progress = 0.0
		charge_changed.emit(_progress)


func unbind_chain() -> void:
	if _chain != null and is_instance_valid(_chain):
		if _chain.chain_collision.is_connected(_on_chain_collision):
			_chain.chain_collision.disconnect(_on_chain_collision)
	_chain = null
	_has_brown = false


## 查找并绑定与挡板同属当前 TableBase 的链。链本身在 build/adopt 时也会反向
## 查找本控制器，两个方向都幂等，顺序无关。
func _bind_current_chain() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for node: Node in tree.get_nodes_in_group(CHAIN_GROUP_NAME):
		if node == null or not is_instance_valid(node) or _is_doomed(node):
			continue
		if not node is MarbleChain:
			continue
		bind_chain(node as MarbleChain)
		return


## 连接 TableBase 下的左右挡板：接收 marble_launched，并向其派发 charge_changed。
## 以信号契约而非节点名识别挡板，避免耦合 TableBase 的具体命名。
func _bind_flippers() -> void:
	if get_parent() == null:
		return
	for child: Node in get_parent().get_children():
		if child == self or not child.has_signal(&"marble_launched"):
			continue
		if not child.is_connected(&"marble_launched", _on_marble_launched):
			child.connect(&"marble_launched", _on_marble_launched)
		if child.has_method(&"set_echo_charge"):
			var visual_handler := Callable(child, &"set_echo_charge")
			if not is_connected(&"charge_changed", visual_handler):
				connect(&"charge_changed", visual_handler)


func _on_chain_collision(_collider: Node, collision_type: String) -> void:
	if collision_type == "enemy":
		add_charge()


## 挡板成功弹起弹珠：
## - 进度 >= 1 层：消费 1 层（尾数保留），追加球速并武装 1 个伤害 token；
## - 满 2 层（红条包裹满）：一次性全部消耗，追加更大球速并武装 2 个伤害 token。
func _on_marble_launched(marble: Marble, applied_impulse: Vector2) -> void:
	if not _has_brown or _progress < 1.0:
		return
	var consume_all := _progress >= MAX_PROGRESS
	var consumed := MAX_PROGRESS if consume_all else 1.0
	_progress -= consumed
	charge_changed.emit(_progress)
	_apply_speed_boost(marble, applied_impulse, consumed)
	if _chain != null and is_instance_valid(_chain) and not _is_doomed(_chain):
		_chain.arm_echo_damage(roundi(consumed))


## 追加球速冲量：倍率由 echo_flipper_speed_multiplier 统计驱动，不硬编码在挡板逻辑。
## 满层全消耗时按消费层数放大（2 层冲量加成是 1 层的两倍）。
func _apply_speed_boost(marble: Marble, applied_impulse: Vector2, layers: float = 1.0) -> void:
	if marble == null or not is_instance_valid(marble) or applied_impulse.is_zero_approx():
		return
	var multiplier := _get_stat_float("echo_flipper_speed_multiplier", DEFAULT_SPEED_MULTIPLIER)
	if multiplier <= 0.0:
		return
	marble.set_sleeping(false)
	marble.apply_central_impulse(applied_impulse * (multiplier - 1.0) * layers)


func _get_stat_float(stat_id: String, fallback: float) -> float:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return fallback
	var stat_system: Node = tree.root.get_node_or_null(NodePath(&"StatSystem"))
	if stat_system == null or not stat_system.has_method("get_stat"):
		return fallback
	return float(stat_system.call("get_stat", stat_id, "marble_chain"))


## queue_free() 只标记根节点；子节点需向上检查祖先。返回自身或任一祖先已排入删除。
static func _is_doomed(node: Node) -> bool:
	var current: Node = node
	while current != null:
		if current.is_queued_for_deletion():
			return true
		current = current.get_parent()
	return false
