# RadialDamage —— 共享的径向范围造伤工具。
#
# 将 MarbleChain._damage_enemies_in_radius 的目标收集/造伤事件语义提取为静态工具，
# 供普通炸弹爆炸（marble_chain）与小炸弹弹珠（small_bomb_marble）共用：
#   - 快照 enemies 组目标 → 过滤已排入删除（含祖先）→ 按半径筛选
#   - 一次 AOE 共享一个非零 event_id；最近目标标记 is_event_main
#   - 优先走 apply_damage_packet 流水线；非 Enemy 测试替身回退 take_damage
# 不负责 VFX / ExplosionContext / EffectManager 分发（由调用方各自处理），
# 保证独立结算边界（小炸弹不触发 on_explosion*/modify_explosion）。

class_name RadialDamage
extends RefCounted

const DamagePacketScript: GDScript = preload("res://Combat/damage/damage_packet.gd")


## 快照目标 → 过滤待删除 → 共享 event_id → 唯一 main target → 构造 DamagePacket。
## is_relic：小炸弹为 true；is_marble 原样写入 packet，与调用方事件语义一致。
## 不构造/分发 ExplosionContext。
static func damage_enemies_in_radius(
	center: Vector2,
	radius: float,
	damage: int,
	is_relic: bool = false,
	is_marble: bool = true,
) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var targets: Array[Node2D] = []
	for enemy: Node in tree.get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy) or _is_doomed(enemy):
			continue
		if not enemy is Node2D:
			continue
		var enemy_node: Node2D = enemy as Node2D
		if enemy_node.global_position.distance_to(center) > radius:
			continue
		targets.append(enemy_node)
	var event_id: int = DamagePacketScript.next_event_id()
	var main_target: Node2D = null
	for target: Node2D in targets:
		if main_target == null or target.global_position.distance_squared_to(center) \
				< main_target.global_position.distance_squared_to(center):
			main_target = target
	for enemy_node: Node2D in targets:
		if enemy_node.has_method("apply_damage_packet"):
			var packet: DamagePacket = DamagePacketScript.new(&"bomb", float(damage), &"physical")
			packet.is_marble = is_marble
			packet.is_relic = is_relic
			packet.target = enemy_node
			packet.event_id = event_id
			packet.is_event_main = enemy_node == main_target
			enemy_node.call("apply_damage_packet", packet)
		elif enemy_node.has_method("take_damage"):
			# Compatibility for non-Enemy test doubles. Real enemies use the packet
			# path above and retain the old multiplier-before-armor result.
			var direct_damage := roundi(float(damage) * _damage_multiplier())
			enemy_node.call("take_damage", direct_damage)


## queue_free() 只标记根节点；子节点需向上检查祖先。返回自身或任一祖先已排入删除。
static func _is_doomed(node: Node) -> bool:
	var current: Node = node
	while current != null:
		if current.is_queued_for_deletion():
			return true
		current = current.get_parent()
	return false


## 非 Enemy 测试替身分支使用的全局倍率，实体与弹珠链一致（marble_chain）。
static func _damage_multiplier() -> float:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return 1.0
	var stat_system: Node = tree.root.get_node_or_null("StatSystem")
	if stat_system == null or not stat_system.has_method("get_stat"):
		return 1.0
	return float(stat_system.call("get_stat", "damage_multiplier", "marble_chain"))
