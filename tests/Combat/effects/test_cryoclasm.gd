extends GutTest

## 冰爆（cryoclasm）遗物行为：冻结体高速碰撞 → 碎裂（解冻 + 清空 Frost + 目标存活、
## HP 不变）+ 按等级生成 3/4/6 枚冰碎片、扇区内优先各指向互异敌人（不足时扇区外补位）；
## 有目标碎片只命中其分配目标、命中即消失不分裂、非分配敌人不能截获；觉醒保留 2 霜且
## 碎片命中施霜；分工——冰爆不响应 on_enemy_hit_resolved、碎冰锤不响应 on_frozen_body_impact；
## 与永冻共存时无论分发先后，冰球都碎裂且被撞敌人都吃一次永冻碰撞伤害。

const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")
const ShardScene: PackedScene = preload("res://Combat/effects/cryoclasm/cryoclasm_ice_shard.tscn")
const LoadoutScript: GDScript = preload("res://Loadout/domain/loadout.gd")
const ProgressionScript: GDScript = preload("res://Loadout/application/item_progression.gd")

var _effect_manager: Node = null
var _loadout: RefCounted = null
var _progression: RefCounted = null
## 战斗容器：敌人加到这里，碎片由冰爆挂到 enemy.get_parent()（即本容器），
## 经 add_child_autofree 在 teardown 一并释放，避免 RigidBody2D/RID 泄漏。
var _field: Node2D = null


func before_each() -> void:
	_field = Node2D.new()
	add_child_autofree(_field)


func after_each() -> void:
	if _effect_manager != null and is_instance_valid(_effect_manager):
		_configure_relics([])
	_effect_manager = null
	_loadout = null
	_progression = null
	_field = null


func test_shatter_unfreezes_clears_frost_and_keeps_source_alive() -> void:
	_configure_relics(["cryoclasm"])
	var source: Enemy = _enemy()
	_freeze(source)
	assert_true(source.has_buff("frozen_debuff"))
	_add_frost(source, 5)
	assert_gte(source.get_buff_stacks("frost_debuff"), 1, "frost applied before shatter")
	_place_in_sector(source, 3)
	var hp: int = source.health

	_effect_manager.on_frozen_body_impact(source, null, Vector2(200.0, 0.0), &"world")
	await get_tree().physics_frame

	assert_false(source.has_buff("frozen_debuff"), "shatter removes freeze")
	assert_eq(source.get_buff_stacks("frost_debuff"), 0, "shatter clears frost")
	assert_eq(source.health, hp, "source HP is unchanged by its own shatter")
	assert_true(source.is_alive(), "the shattered target survives")
	assert_eq(_shards().size(), 3, "level 1 spawns 3 shards")
	assert_eq(_shards()[0].get("turn_rate"), 8.0, "shard picks up the configured turn rate")


func test_shards_each_target_a_distinct_in_sector_enemy() -> void:
	_configure_relics(["cryoclasm"])
	var source: Enemy = _enemy()
	_freeze(source)
	var e1: Enemy = _enemy_at(source, Vector2(100.0, 0.0))    # 0°
	var e2: Enemy = _enemy_at(source, Vector2(80.0, 40.0))     # ~26.5°
	var e3: Enemy = _enemy_at(source, Vector2(80.0, -40.0))    # ~-26.5°
	var e_out: Enemy = _enemy_at(source, Vector2(0.0, 100.0))  # 90° → 扇区外

	_effect_manager.on_frozen_body_impact(source, null, Vector2(200.0, 0.0), &"world")
	await get_tree().physics_frame

	var shards: Array = _shards()
	assert_eq(shards.size(), 3, "N=3")
	var target_ids: Dictionary = {}
	for shard: Variant in shards:
		var target: Node2D = shard.get_target()
		assert_not_null(target, "the 3 in-sector enemies fill all 3 shards")
		target_ids[target.get_instance_id()] = true
	assert_eq(target_ids.size(), 3, "each shard targets a distinct enemy")
	assert_true(target_ids.has(e1.get_instance_id()))
	assert_true(target_ids.has(e2.get_instance_id()))
	assert_true(target_ids.has(e3.get_instance_id()))
	assert_false(target_ids.has(e_out.get_instance_id()), "out-of-sector excluded while sector fills N")


func test_out_of_sector_fills_when_in_sector_insufficient() -> void:
	_configure_relics(["cryoclasm"])
	var source: Enemy = _enemy()
	_freeze(source)
	var in_foe: Enemy = _enemy_at(source, Vector2(100.0, 0.0))   # 扇区内
	var out1: Enemy = _enemy_at(source, Vector2(0.0, 100.0))     # 扇区外
	var out2: Enemy = _enemy_at(source, Vector2(0.0, -100.0))    # 扇区外

	_effect_manager.on_frozen_body_impact(source, null, Vector2(200.0, 0.0), &"world")
	await get_tree().physics_frame

	var shards: Array = _shards()
	assert_eq(shards.size(), 3)
	var target_ids: Dictionary = {}
	for shard: Variant in shards:
		var target: Node2D = shard.get_target()
		assert_not_null(target, "out-of-sector enemies fill the remaining shard slots")
		target_ids[target.get_instance_id()] = true
	assert_eq(target_ids.size(), 3)
	assert_true(target_ids.has(in_foe.get_instance_id()), "in-sector is preferred")
	assert_true(target_ids.has(out1.get_instance_id()))
	assert_true(target_ids.has(out2.get_instance_id()))


func test_shard_count_scales_with_level() -> void:
	var expected := {1: 3, 2: 4, 3: 6}
	for level: int in [1, 2, 3]:
		_configure_relics(["cryoclasm"])  # 每个等级全新遗物实例（_live_shards 独立）
		_cryoclasm().set_level(level)
		var source: Enemy = _enemy()
		_freeze(source)
		_effect_manager.on_frozen_body_impact(source, null, Vector2(200.0, 0.0), &"world")
		await get_tree().physics_frame
		assert_eq(
			_cryoclasm().get_live_shard_count(), expected[level],
			"level %d spawns the configured shard count" % level
		)


func test_targeted_shard_hits_assigned_once_and_frees() -> void:
	_configure_relics(["cryoclasm"])
	var source: Enemy = _enemy()
	_freeze(source)
	var foe: Enemy = _enemy_at(source, Vector2(100.0, 0.0))
	var source_hp: int = source.health

	_effect_manager.on_frozen_body_impact(source, null, Vector2(200.0, 0.0), &"world")
	await get_tree().physics_frame

	assert_eq(_shards().size(), 3, "1 foe + N=3 → 1 targeted + 2 visual")
	var targeted: Variant = null
	for shard: Variant in _shards():
		if shard.get_target() == foe:
			targeted = shard
	assert_not_null(targeted, "one shard is assigned the in-sector foe")

	# 真实命中与命中即销毁由下方物理测试覆盖；这里验证延后激活后仍保留分配的伤害参数。
	assert_eq(targeted.damage, 3, "level 1 shard retains its configured damage")
	assert_eq(source.health, source_hp, "source HP stays stable after shard flight")


func test_shard_physically_passes_through_non_target_to_hit_assigned_target() -> void:
	# 真实物理验证：碎片是 RigidBody2D，仅靠回调跳过伤害不足以"穿透"——必须对非分配
	# 敌人加碰撞例外。这里用真实位置 + 物理帧 + 真实 body_entered 证明：挡在目标前方的
	# 非分配敌人既不受伤害、也不会阻止碎片命中其分配目标（顺带覆盖 homing / CCD /
	# 碰撞层 / 命中即销毁）。冻结 blocker 与 target 的物理体使几何稳定、排除重力漂移。
	_configure_relics([])
	var target: Enemy = _enemy_at_pos(Vector2(80.0, 0.0))
	var blocker: Enemy = _enemy_at_pos(Vector2(40.0, 0.0))  # 位于碎片到目标的路径上
	target.freeze = true
	blocker.freeze = true
	var shard: CryoclasmIceShard = ShardScene.instantiate() as CryoclasmIceShard
	_field.add_child(shard)
	shard.global_position = Vector2(0.0, 0.0)
	assert_true(shard.initialize(target, Vector2(1.0, 0.0), 3, 400.0, 3.0, 8.0, 1, 0, null))
	var target_hp: int = target.health
	var blocker_hp: int = blocker.health

	var reached: bool = false
	for _frame: int in range(180):
		await get_tree().physics_frame
		if not is_instance_valid(shard) or shard.is_queued_for_deletion():
			reached = true
			break

	assert_eq(blocker.health, blocker_hp, "non-target blocker takes no damage (physical pass-through)")
	assert_true(reached, "the shard reached its assigned target within the frame budget")
	assert_eq(
		target_hp - target.health, 3,
		"assigned target takes the shard damage via a real collision"
	)


func test_awakened_retains_frost_and_shard_applies_frost() -> void:
	_configure_relics(["cryoclasm"])
	_cryoclasm().set_awakened(true)
	var source: Enemy = _enemy()
	_freeze(source)
	_add_frost(source, 5)
	var foe: Enemy = _enemy_at(source, Vector2(100.0, 0.0))

	_effect_manager.on_frozen_body_impact(source, null, Vector2(200.0, 0.0), &"world")
	await get_tree().physics_frame

	assert_eq(source.get_buff_stacks("frost_debuff"), 2, "awakened retains 2 frost on the source")
	var targeted: Variant = null
	for shard: Variant in _shards():
		if shard.get_target() == foe:
			targeted = shard
	assert_not_null(targeted)
	var frost_shard: CryoclasmIceShard = ShardScene.instantiate() as CryoclasmIceShard
	_field.add_child(frost_shard)
	assert_true(frost_shard.initialize(foe, Vector2.RIGHT, 3, 260.0, 3.0, 8.0, 1, 1, source))
	frost_shard._on_body_entered(foe)
	assert_gte(foe.get_buff_stacks("frost_debuff"), 1, "awakened shard applies frost on its assigned hit")
	assert_true(frost_shard.is_queued_for_deletion(), "shard is consumed after its assigned hit")


func test_cryoclasm_ignores_on_enemy_hit_resolved() -> void:
	_configure_relics(["cryoclasm"])
	var target: Enemy = _enemy()
	_freeze(target)

	_effect_manager.on_enemy_hit_resolved(target, false, true)

	assert_true(
		target.has_buff("frozen_debuff"),
		"cryoclasm must not shatter on the Head-hit channel (that is ice hammer's job)"
	)
	assert_eq(_shards().size(), 0, "no shards from on_enemy_hit_resolved")


func test_ice_hammer_ignores_on_frozen_body_impact() -> void:
	_configure_relics(["ice_hammer"])
	var target: Enemy = _enemy()
	_freeze(target)
	var hp: int = target.health

	_effect_manager.on_frozen_body_impact(target, null, Vector2(200.0, 0.0), &"world")

	assert_true(
		target.has_buff("frozen_debuff"),
		"ice hammer must not act on frozen-body impact (that is cryoclasm's job)"
	)
	assert_eq(target.health, hp)


func test_permafrost_and_cryoclasm_shatter_without_ice_ball_side_effects_regardless_of_dispatch_order() -> void:
	for order: Array in [[&"permafrost", &"cryoclasm"], [&"cryoclasm", &"permafrost"]]:
		_configure_relics(["permafrost", "cryoclasm"])
		_set_dispatch_order(order)
		var a: Enemy = _enemy()
		var base_scale: Vector2 = a.scale
		_freeze(a)
		assert_eq(a.scale, base_scale, "permafrost keeps frozen enemy scale unchanged")
		var b: Enemy = _enemy_at(a, Vector2(80.0, 0.0))
		var a_hp: int = a.health
		var b_hp: int = b.health

		_effect_manager.on_frozen_body_impact(a, b, Vector2(200.0, 0.0), &"enemy")
		assert_eq(b.health, b_hp, "permafrost no longer deals collision damage (order %s)" % str(order))
		await get_tree().physics_frame

		assert_false(a.has_buff("frozen_debuff"), "A shatters (order %s)" % str(order))
		assert_eq(a.scale, base_scale, "A's scale remains unchanged (order %s)" % str(order))
		assert_eq(a.health, a_hp, "A's HP is unchanged (order %s)" % str(order))
		assert_true(a.is_alive())
		assert_eq(_cryoclasm().get_live_shard_count(), 3, "shards still spawn (order %s)" % str(order))


func test_ball_lost_clears_spawned_shards() -> void:
	_configure_relics(["cryoclasm"])
	var source: Enemy = _enemy()
	_freeze(source)
	_enemy_at(source, Vector2(100.0, 0.0))

	_effect_manager.on_frozen_body_impact(source, null, Vector2(200.0, 0.0), &"world")
	assert_eq(_cryoclasm().get_live_shard_count(), 3)

	_effect_manager.on_ball_lost()

	assert_eq(_cryoclasm().get_live_shard_count(), 0)
	await get_tree().process_frame
	assert_eq(_shards().size(), 0, "all shards freed at ball loss")


func test_shard_damage_scales_with_level() -> void:
	var expected := {1: 3, 2: 4, 3: 6}
	for level: int in [1, 2, 3]:
		var foe: Enemy = _enemy()
		var shard: CryoclasmIceShard = ShardScene.instantiate() as CryoclasmIceShard
		_field.add_child(shard)
		assert_true(shard.initialize(foe, Vector2.RIGHT, expected[level], 260.0, 3.0, 8.0, 1, 0, null))
		var foe_hp: int = foe.health
		shard._on_body_entered(foe)
		assert_eq(foe_hp - foe.health, expected[level], "level %d shard deals its configured damage" % level)
		assert_true(shard.is_queued_for_deletion(), "level %d shard is consumed after one hit" % level)


func test_zero_speed_impact_shatters() -> void:
	# 问题来源：冰爆要求高速碰撞，未拿冲刺时很难触发。
	# 修复应让任意冻结碰撞碎裂；零速度快照覆盖原速度阈值的下边界。
	_configure_relics(["cryoclasm"])
	var source: Enemy = _enemy()
	_freeze(source)
	_enemy_at(source, Vector2(100.0, 0.0))

	_effect_manager.on_frozen_body_impact(source, null, Vector2.ZERO, &"world")
	await get_tree().physics_frame

	assert_false(source.has_buff("frozen_debuff"), "zero-speed frozen impact still shatters")
	assert_eq(_shards().size(), 3, "zero-speed shatter produces level-1 shards")


func test_shatter_cooldown_prevents_repeat_spawn_within_window() -> void:
	_configure_relics(["cryoclasm"])
	var source: Enemy = _enemy()
	_freeze(source)
	_enemy_at(source, Vector2(100.0, 0.0))

	_effect_manager.on_frozen_body_impact(source, null, Vector2(200.0, 0.0), &"world")
	# 同一敌人在冷却窗内再次收到快照事件 → 被拦截，碎片只生成一次。
	_effect_manager.on_frozen_body_impact(source, null, Vector2(200.0, 0.0), &"world")
	await get_tree().physics_frame

	assert_eq(_shards().size(), 3, "cooldown prevents a second shatter spawn")


func _configure_relics(relic_ids: Array) -> void:
	_effect_manager = get_node_or_null("/root/EffectManager")
	assert_not_null(_effect_manager)
	# 先配置空装束清掉既有遗物，保证每次都是全新遗物实例（独立 _live_shards/_cooldown）。
	var empty: RefCounted = LoadoutScript.new()
	_effect_manager.configure(empty, ProgressionScript.new(empty))
	_loadout = LoadoutScript.new()
	for relic_id: String in relic_ids:
		var relic := Item.new()
		relic.id = relic_id
		relic.type = Item.ItemType.RELIC
		assert_true(_loadout.call("add", relic), "loadout accepts relic %s" % relic_id)
	_progression = ProgressionScript.new(_loadout)
	assert_true(_effect_manager.configure(_loadout, _progression))


func _cryoclasm() -> RefCounted:
	var effect: RefCounted = _effect_manager._active_effects.get(&"cryoclasm")
	assert_not_null(effect, "cryoclasm effect should be active")
	return effect


func _set_dispatch_order(order: Array) -> void:
	var effects: Dictionary = _effect_manager._active_effects
	var rebuilt: Dictionary = {}
	for key: Variant in order:
		if effects.has(key):
			rebuilt[key] = effects[key]
	_effect_manager._active_effects = rebuilt


func _enemy() -> Enemy:
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	_field.add_child(enemy)
	return enemy


func _enemy_at_pos(pos: Vector2) -> Enemy:
	var enemy: Enemy = _enemy()
	enemy.global_position = pos
	return enemy


func _enemy_at(anchor: Enemy, offset: Vector2) -> Enemy:
	var enemy: Enemy = _enemy()
	enemy.global_position = anchor.global_position + offset
	return enemy


func _place_in_sector(source: Enemy, count: int) -> void:
	for k: int in range(count):
		var angle: float = 0.0
		if count > 1:
			angle = deg_to_rad(-45.0 + 90.0 * (float(k) / float(count - 1)))
		_enemy_at(source, Vector2(100.0, 0.0).rotated(angle))


func _add_frost(enemy: Enemy, stacks: int) -> void:
	var registry: Node = get_node_or_null("/root/BuffRegistry")
	assert_not_null(registry)
	var frost_def: BuffDef = registry.call("get_buff_def", "frost_debuff") as BuffDef
	assert_not_null(frost_def)
	enemy.add_buff(frost_def, stacks)


func _freeze(enemy: Enemy) -> void:
	var registry: Node = get_node_or_null("/root/BuffRegistry")
	assert_not_null(registry)
	var frozen_def: BuffDef = registry.call("get_buff_def", "frozen_debuff") as BuffDef
	assert_not_null(frozen_def)
	enemy.add_buff(frozen_def)
	assert_true(enemy.has_buff("frozen_debuff"))


func _shards() -> Array:
	return get_tree().get_nodes_in_group("relic_projectiles")
