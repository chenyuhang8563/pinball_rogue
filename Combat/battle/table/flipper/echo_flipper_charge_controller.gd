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
## 磨轮每发反弹充能上限（一次弹起到下一次弹起之间），防纯弹射永动。
const WALL_CHARGE_CAP_PER_SHOT: float = 0.5

var _progress: float = 0.0
var _chain: MarbleChain = null
var _has_brown: bool = false

# ---- 遗物（磨轮 / 锻锤 / 破城锥）----

## 本发反弹计数（一次挡板弹起到下一次挡板弹起之间）；锻锤在发射时结算。
var _bounce_count: int = 0
## 本发磨轮壁充能累计（每发封顶 0.5 层）。
var _wall_charge_this_shot: float = 0.0
## 首次挡板弹起前为 false：弹珠出生后第一次撞墙不充能、不计反弹
## （「本发」从第一次挡板弹起开始定义；修复战斗开始莫名 +0.05 蓄力）。
var _shot_started: bool = false
## 遗物 effect 查询源：set_echo_effects() 注入（测试）；默认查 EffectManager autoload。
var _echo_effects_override: Dictionary = {}
var _echo_effects_forced: bool = false


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
	# 新链出生：弹珠首次挡板弹起前墙反弹豁免（修复战斗开始莫名 +0.05 蓄力）。
	_shot_started = false
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
		return
	if collision_type == "wall":
		_handle_wall_bounce()


## 墙面/台面反弹：磨轮或锻锤持有时累计本发反弹计数；磨轮持有时按
## get_charge_per_bounce() 给共享蓄力充能，每发累计 ≤0.5 层封顶。挡板弹起不充能。
func _handle_wall_bounce() -> void:
	# 出生豁免：弹珠从出生到首次挡板弹起前的墙面碰撞不参与「本发」。
	if not _shot_started:
		return
	var grindstone: Variant = _get_echo_effect(&"grindstone")
	var hammer: Variant = _get_echo_effect(&"drop_hammer")
	var has_grindstone: bool = grindstone != null and grindstone.has_method("get_charge_per_bounce")
	var has_hammer: bool = hammer != null and hammer.has_method("get_bonus")
	if not has_grindstone and not has_hammer:
		return
	_bounce_count += 1
	if not has_grindstone or not _has_brown or _progress >= MAX_PROGRESS \
			or _wall_charge_this_shot >= WALL_CHARGE_CAP_PER_SHOT:
		return
	var per_bounce: float = float(grindstone.call("get_charge_per_bounce"))
	var cap: float = float(grindstone.call("get_wall_charge_cap")) \
			if grindstone.has_method("get_wall_charge_cap") else WALL_CHARGE_CAP_PER_SHOT
	var headroom: float = cap - _wall_charge_this_shot
	if headroom <= 0.0:
		return
	var gain: float = minf(per_bounce, headroom)
	_wall_charge_this_shot += gain
	_progress = minf(_progress + gain, MAX_PROGRESS)
	charge_changed.emit(_progress)


## 挡板成功弹起弹珠：
## - 进度 >= 1 层：消费 1 层（尾数保留），追加球速并武装 1 个伤害 token；
## - 满 2 层（红条包裹满）：一次性全部消耗，追加更大球速并武装 2 个伤害 token。
## 每发开始时重置反弹计数与壁充能；锻锤按本发反弹计数武装 token 追加伤害；
## 破城锥持有时按消费层数进入穿透态。
func _on_marble_launched(marble: Marble, applied_impulse: Vector2) -> void:
	# 首次挡板弹起标记本发开始（出生豁免结束）。
	_shot_started = true
	# 先按本发反弹计数结算锻锤加成，再重置每发计数。
	var hammer_bonus: int = _get_drop_hammer_bonus()
	_bounce_count = 0
	_wall_charge_this_shot = 0.0
	if not _has_brown or _progress < 1.0:
		return
	var consume_all := _progress >= MAX_PROGRESS
	var consumed := MAX_PROGRESS if consume_all else 1.0
	_progress -= consumed
	charge_changed.emit(_progress)
	_apply_speed_boost(marble, applied_impulse, consumed)
	if _chain != null and is_instance_valid(_chain) and not _is_doomed(_chain):
		var tokens := roundi(consumed)
		_chain.arm_echo_damage(tokens, hammer_bonus)
		_enter_pierce_state_for_ram()


## 锻锤：把本发反弹计数按等级换算成每 token 追加伤害（每 step 次反弹 +1，封顶 cap）。
func _get_drop_hammer_bonus() -> int:
	var hammer: Variant = _get_echo_effect(&"drop_hammer")
	if hammer == null or not hammer.has_method("get_bonus"):
		return 0
	return int(hammer.call("get_bonus", _bounce_count))


## 破城锥：强力击发射时使弹珠进入穿透态——时长按等级（LV1-3: 3/3.5/4 秒，
## 觉醒 5 秒），穿透伤害倍率随觉醒（觉醒 ×1.5）。
func _enter_pierce_state_for_ram() -> void:
	if _chain == null or not is_instance_valid(_chain) or not _chain.has_method("enter_pierce_state"):
		return
	var ram: Variant = _get_echo_effect(&"battering_ram")
	if ram == null or not ram.has_method("get_pierce_duration"):
		return
	var duration: float = float(ram.call("get_pierce_duration"))
	if duration <= 0.0:
		return
	var multiplier: float = 1.0
	if ram.has_method("get_pierce_damage_multiplier"):
		multiplier = float(ram.call("get_pierce_damage_multiplier"))
	_chain.call("enter_pierce_state", duration, multiplier)


## 测试注入：覆盖遗物 effect 查询源（key = item id，value = effect 实例）。
func set_echo_effects(effects: Dictionary) -> void:
	_echo_effects_override = effects.duplicate()
	_echo_effects_forced = true


## 查询遗物 effect：注入源优先，否则查 EffectManager 当前激活效果。
func _get_echo_effect(item_id: StringName) -> Variant:
	if _echo_effects_forced:
		return _echo_effects_override.get(item_id, null)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var effect_manager: Node = tree.root.get_node_or_null(NodePath(&"EffectManager"))
	if effect_manager == null or not effect_manager.has_method("get_active_effect"):
		return null
	return effect_manager.call("get_active_effect", item_id)


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
