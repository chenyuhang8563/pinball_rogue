# AmmoState —— 炸弹系弹药机制的唯一次数状态持有者（Main 的子节点，非 autoload）。
#
# 规则：
#   - 默认弹药上限 5（max_ammo stat 写在 "player" 实体上，缺省回退 5）
#   - 每次挡板发射弹珠弹药回满（refill，绑定额外信号契约 has_signal("marble_launched")）
#   - 爆炸消耗 1 发；弹药 0 时不爆炸，保留 1 点普通碰撞伤害
#   - 弹药袋觉醒：战斗开始弹药 = max + 2（临时超上限），首次发射 refill 后回落到 max
#   - 回收器等补弹不超当前 ceiling（max + battle_start_bonus）
#
# 生命周期：main.gd 在 _setup_run_flow_composition 成功后 configure()，
# _dispose_run_flow_composition 中 unconfigure()；台面每次战斗实例化后由
# reset_battle_state() 调用 bind_launch_sources(active_level_scene)。

extends Node
class_name AmmoState

signal changed(current: int, maximum: int)

const DEFAULT_MAX_AMMO: int = 5
const STAT_ENTITY_PLAYER: String = "player"
const STAT_MAX_AMMO: String = "max_ammo"

var _stat_system: Node = null
var _lifecycle_source: Node = null
var _ammo: int = DEFAULT_MAX_AMMO
var _battle_start_bonus: int = 0
# 本场战斗尚未首次发射弹珠：期间 ceiling 含战斗开始加成（弹药袋觉醒 7），
# 首次发射 refill 后加成失效（ceiling 回落 max），下一场战斗开始再重新激活。
var _first_launch_pending: bool = true
var _bound_sources: Array[Node] = []


## 连接战斗生命周期（battle_started 重置弹药）并初始化当前值。
## 重复调用安全：先 unconfigure 再重新接线。
func configure(stat_system: Node, lifecycle_source: Node) -> void:
	unconfigure()
	_stat_system = stat_system
	_lifecycle_source = lifecycle_source
	if _lifecycle_source != null and is_instance_valid(_lifecycle_source) \
			and _lifecycle_source.has_signal(&"battle_started") \
			and not _lifecycle_source.is_connected(&"battle_started", _on_battle_started):
		_lifecycle_source.connect(&"battle_started", _on_battle_started)
	_first_launch_pending = true
	_ammo = get_max_ammo() + _battle_start_bonus
	changed.emit(_ammo, get_max_ammo())


## 断开生命周期与挡板绑定，恢复默认值。
func unconfigure() -> void:
	unbind_launch_sources()
	if _lifecycle_source != null and is_instance_valid(_lifecycle_source) \
			and _lifecycle_source.has_signal(&"battle_started") \
			and _lifecycle_source.is_connected(&"battle_started", _on_battle_started):
		_lifecycle_source.disconnect(&"battle_started", _on_battle_started)
	_lifecycle_source = null
	_stat_system = null
	_ammo = DEFAULT_MAX_AMMO
	_battle_start_bonus = 0
	_first_launch_pending = true


func get_ammo() -> int:
	return _ammo


## 弹药上限来自 StatSystem 的 max_ammo（player 实体）；stat 缺失或非正时回退默认 5。
func get_max_ammo() -> int:
	if _stat_system == null or not is_instance_valid(_stat_system) \
			or not _stat_system.has_method("get_stat"):
		return DEFAULT_MAX_AMMO
	var value: int = int(_stat_system.call("get_stat", STAT_MAX_AMMO, STAT_ENTITY_PLAYER))
	return value if value > 0 else DEFAULT_MAX_AMMO


## 原子消耗：不足返回 false 且不部分扣减。
func consume(amount: int = 1) -> bool:
	if amount <= 0:
		return true
	if _ammo < amount:
		return false
	_ammo -= amount
	changed.emit(_ammo, get_max_ammo())
	return true


## 补弹，不超当前 ceiling：首次发射前含战斗开始加成，之后回落 max。
func add(amount: int = 1) -> int:
	if amount <= 0:
		return _ammo
	_ammo = mini(_ammo + amount, _ceiling())
	changed.emit(_ammo, get_max_ammo())
	return _ammo


## 挡板发射弹珠：弹药回满；战斗开始加成随之失效（ceiling 回落 max），
## 下一场战斗开始时重新激活。
func refill() -> void:
	_first_launch_pending = false
	_ammo = get_max_ammo()
	changed.emit(_ammo, get_max_ammo())


## 弹药袋等遗物设置战斗开始加成（觉醒 2，其余 0）。ceiling 随之变化。
func set_battle_start_bonus(amount: int) -> void:
	_battle_start_bonus = maxi(0, amount)
	_first_launch_pending = true
	_clamp_to_ceiling()
	changed.emit(_ammo, get_max_ammo())


## max modifier 变化后刷新 ceiling（弹药袋升满等场景）。
func refresh_capacity() -> void:
	_clamp_to_ceiling()
	changed.emit(_ammo, get_max_ammo())


## 递归遍历 root（active_level_scene），连接所有暴露 marble_launched 信号的节点。
## 换台面前先断开旧连接，防止同一节点重复回调。
func bind_launch_sources(root: Node) -> void:
	unbind_launch_sources()
	if root == null or not is_instance_valid(root):
		return
	var sources: Array[Node] = []
	_collect_launch_sources(root, sources)
	for node: Node in sources:
		if node.has_signal(&"marble_launched") \
				and not node.is_connected(&"marble_launched", _on_marble_launched):
			node.connect(&"marble_launched", _on_marble_launched)
			_bound_sources.append(node)


func unbind_launch_sources() -> void:
	for node: Node in _bound_sources:
		if node != null and is_instance_valid(node) \
				and node.is_connected(&"marble_launched", _on_marble_launched):
			node.disconnect(&"marble_launched", _on_marble_launched)
	_bound_sources.clear()


func _collect_launch_sources(node: Node, result: Array[Node]) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.has_signal(&"marble_launched"):
		result.append(node)
	for child: Node in node.get_children():
		_collect_launch_sources(child, result)


func _on_marble_launched(_marble: Node = null, _applied_impulse: Vector2 = Vector2.ZERO) -> void:
	refill()


func _on_battle_started(_token: Variant = null, _plan: Variant = null) -> void:
	_first_launch_pending = true
	_ammo = get_max_ammo() + _battle_start_bonus
	changed.emit(_ammo, get_max_ammo())


func _ceiling() -> int:
	return get_max_ammo() + (_battle_start_bonus if _first_launch_pending else 0)


func _clamp_to_ceiling() -> void:
	_ammo = mini(_ammo, _ceiling())


## 后备查找：独立场景（如 bomb_marble 单场景）从 current_scene 下取 Main 的 AmmoState。
static func find_current() -> AmmoState:
	var scene: Node = Engine.get_main_loop().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("AmmoState") as AmmoState
