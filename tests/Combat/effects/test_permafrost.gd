extends GutTest

## 永冻（permafrost）遗物行为：冻结敌人 → 冰球（放大 / 登记 / 本发内不解冻）、
## 上限淘汰、冰球撞敌的方向性碰撞伤害、on_ball_lost 全部还原、觉醒碰撞施霜与
## 上限 +1，以及与碎冰锤的共存规则（冰球目标吃 AOE 但不解冻）。
## 真实碰撞时序由 tests/Combat/enemies/test_frozen_impact_*.gd 覆盖，这里只验证
## Effect 层逻辑（经 EffectManager 鸭子类型分发）。

const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")
const LoadoutScript: GDScript = preload("res://Loadout/domain/loadout.gd")
const ProgressionScript: GDScript = preload("res://Loadout/application/item_progression.gd")

var _effect_manager: Node = null
var _loadout: RefCounted = null
var _progression: RefCounted = null


func after_each() -> void:
	if _effect_manager != null and is_instance_valid(_effect_manager):
		_configure_relics([])
	_effect_manager = null
	_loadout = null
	_progression = null


func test_freeze_turns_enemy_into_registered_enlarged_ice_ball() -> void:
	_configure_relics(["permafrost"])
	var enemy: Enemy = _enemy()
	var base_scale: Vector2 = enemy.scale

	_freeze(enemy)

	assert_eq(enemy.scale, base_scale * 1.5, "ice ball enlarges the enemy")
	assert_true(bool(enemy.get_meta(&"ice_ball", false)), "ice ball meta flag is set")
	assert_eq(_permafrost().get_ice_ball_count(), 1)
	assert_gt(
		enemy.buff_host.get_buff_remaining_time("frozen_debuff"), 3500.0,
		"frozen duration is extended far past the 4s base so it survives this ball"
	)


func test_ice_ball_stays_frozen_past_base_duration() -> void:
	_configure_relics(["permafrost"])
	var enemy: Enemy = _enemy()
	_freeze(enemy)

	# 超过 FrozenDebuff.DEFAULT_DURATION（4.0s）：无永冻时此刻应已解冻。
	enemy.buff_host._process(4.1)

	assert_true(enemy.has_buff("frozen_debuff"), "still frozen past the base 4s duration")
	assert_true(bool(enemy.get_meta(&"ice_ball", false)))
	assert_eq(_permafrost().get_ice_ball_count(), 1)


func test_ice_ball_cap_culls_oldest() -> void:
	_configure_relics(["permafrost"])
	var a: Enemy = _enemy()
	var b: Enemy = _enemy()
	var c: Enemy = _enemy()
	var base_scale: Vector2 = a.scale

	_freeze(a)
	_freeze(b)
	_freeze(c)

	assert_eq(_permafrost().get_ice_ball_count(), 2, "base cap keeps two ice balls")
	assert_false(a.has_buff("frozen_debuff"), "oldest ice ball is culled")
	assert_false(bool(a.get_meta(&"ice_ball", false)))
	assert_eq(a.scale, base_scale, "culled ball restores its base scale")
	for ball: Enemy in [b, c]:
		assert_true(ball.has_buff("frozen_debuff"))
		assert_true(bool(ball.get_meta(&"ice_ball", false)))


func test_impact_from_ice_ball_damages_hit_enemy() -> void:
	_configure_relics(["permafrost"])
	var ball: Enemy = _enemy()
	var target: Enemy = _enemy()
	_freeze(ball)
	var target_hp: int = target.health
	var ball_hp: int = ball.health

	_effect_manager.on_frozen_body_impact(ball, target, Vector2(150.0, 0.0), &"enemy", true)

	assert_eq(target_hp - target.health, 4, "level 1 impact damage from relic config")
	assert_eq(ball.health, ball_hp, "the ice ball itself takes no damage")


func test_impact_guards_snapshot_kind_and_target() -> void:
	_configure_relics(["permafrost"])
	var ball: Enemy = _enemy()
	var target: Enemy = _enemy()
	_freeze(ball)
	var hp: int = target.health

	_effect_manager.on_frozen_body_impact(ball, target, Vector2(150.0, 0.0), &"enemy", false)
	assert_eq(target.health, hp, "was_ice_ball=false snapshot deals no damage")

	_effect_manager.on_frozen_body_impact(ball, null, Vector2(150.0, 0.0), &"world", true)
	assert_eq(target.health, hp, "world impacts deal no damage")

	_effect_manager.on_frozen_body_impact(ball, ball, Vector2(150.0, 0.0), &"enemy", true)
	assert_eq(ball.health, 100, "self impact deals no damage")


func test_ball_lost_restores_all_ice_balls() -> void:
	_configure_relics(["permafrost"])
	var a: Enemy = _enemy()
	var b: Enemy = _enemy()
	var target: Enemy = _enemy()
	var base_scale: Vector2 = a.scale
	_freeze(a)
	_freeze(b)

	_effect_manager.on_ball_lost()

	assert_eq(_permafrost().get_ice_ball_count(), 0)
	for ball: Enemy in [a, b]:
		assert_false(ball.has_buff("frozen_debuff"), "ice ball restored at ball loss")
		assert_false(bool(ball.get_meta(&"ice_ball", false)))
		assert_eq(ball.scale, base_scale)

	# 还原后即退出登记表：即使快照声称 was_ice_ball 也不再造成伤害。
	var hp: int = target.health
	_effect_manager.on_frozen_body_impact(a, target, Vector2(150.0, 0.0), &"enemy", true)
	assert_eq(target.health, hp, "restored balls are no longer registered ice balls")
	_effect_manager.on_ball_lost()  # 幂等


func test_awakened_impact_applies_frost_to_hit_enemy() -> void:
	_configure_relics(["permafrost"])
	_permafrost().set_awakened(true)
	var ball: Enemy = _enemy()
	var target: Enemy = _enemy()
	_freeze(ball)

	_effect_manager.on_frozen_body_impact(ball, target, Vector2(150.0, 0.0), &"enemy", true)

	assert_true(target.has_buff("frost_debuff"), "awakened impact applies frost")
	assert_gte(target.get_buff_stacks("frost_debuff"), 1)


func test_awakened_cap_allows_three_ice_balls() -> void:
	_configure_relics(["permafrost"])
	_permafrost().set_awakened(true)
	var a: Enemy = _enemy()
	var b: Enemy = _enemy()
	var c: Enemy = _enemy()

	_freeze(a)
	_freeze(b)
	_freeze(c)

	assert_eq(_permafrost().get_ice_ball_count(), 3, "awakened cap is 3")
	for ball: Enemy in [a, b, c]:
		assert_true(ball.has_buff("frozen_debuff"))


func test_ice_hammer_combo_aoe_without_thawing_ice_ball() -> void:
	_configure_relics(["permafrost", "ice_hammer"])
	var target: Enemy = _enemy()
	var neighbor: Enemy = _enemy()
	neighbor.global_position = target.global_position + Vector2(24.0, 0.0)
	_freeze(target)
	assert_true(bool(target.get_meta(&"ice_ball", false)), "permafrost converts the frozen target")
	var target_hp: int = target.health
	var neighbor_hp: int = neighbor.health
	var enlarged_scale: Vector2 = target.scale

	# 模拟 Head 命中冻结目标（碎冰锤链路）。
	_effect_manager.on_enemy_hit_resolved(target, false, true)

	assert_lt(target.health, target_hp, "ice ball still takes shatter AOE damage")
	assert_lt(neighbor.health, neighbor_hp, "nearby enemy takes shatter AOE damage")
	assert_true(target.has_buff("frozen_debuff"), "ice ball must not thaw on Head hit")
	assert_true(bool(target.get_meta(&"ice_ball", false)))
	assert_eq(target.scale, enlarged_scale, "scale stays enlarged after the combo")


func test_ice_hammer_alone_still_shatters_regular_frozen() -> void:
	_configure_relics(["ice_hammer"])
	var target: Enemy = _enemy()
	_freeze(target)

	_effect_manager.on_enemy_hit_resolved(target, false, true)

	assert_false(
		target.has_buff("frozen_debuff"),
		"without permafrost, regular frozen targets still shatter on Head hit"
	)


func test_ignores_other_status_events() -> void:
	_configure_relics(["permafrost"])
	var enemy: Enemy = _enemy()

	_effect_manager.on_status_applied(enemy, &"frost_debuff", 1, null)

	assert_eq(_permafrost().get_ice_ball_count(), 0)
	assert_false(bool(enemy.get_meta(&"ice_ball", false)))


func test_on_enemy_defeated_prunes_registry() -> void:
	_configure_relics(["permafrost"])
	var enemy: Enemy = _enemy()
	_freeze(enemy)
	assert_eq(_permafrost().get_ice_ball_count(), 1)

	_effect_manager.on_enemy_defeated(enemy, null)

	assert_eq(_permafrost().get_ice_ball_count(), 0)


func _configure_relics(relic_ids: Array) -> void:
	_loadout = LoadoutScript.new()
	for relic_id: String in relic_ids:
		var relic := Item.new()
		relic.id = relic_id
		relic.type = Item.ItemType.RELIC
		assert_true(_loadout.call("add", relic), "loadout accepts relic %s" % relic_id)
	_progression = ProgressionScript.new(_loadout)
	_effect_manager = get_node_or_null("/root/EffectManager")
	assert_not_null(_effect_manager)
	assert_true(_effect_manager.configure(_loadout, _progression))


func _permafrost() -> RefCounted:
	var effect: RefCounted = _effect_manager._active_effects.get(&"permafrost")
	assert_not_null(effect, "permafrost effect should be active")
	return effect


func _enemy() -> Enemy:
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	add_child_autofree(enemy)
	return enemy


func _freeze(enemy: Enemy) -> void:
	var registry: Node = get_node_or_null("/root/BuffRegistry")
	assert_not_null(registry)
	var frozen_def: BuffDef = registry.call("get_buff_def", "frozen_debuff") as BuffDef
	assert_not_null(frozen_def)
	enemy.add_buff(frozen_def)
	assert_true(enemy.has_buff("frozen_debuff"))
