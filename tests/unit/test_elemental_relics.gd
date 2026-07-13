extends GutTest

const FireBellowsScript: GDScript = preload("res://Effects/fire_bellows/fire_bellows.gd")
const PoisonCultureScript: GDScript = preload("res://Effects/poison_culture/poison_culture.gd")
const IceHammerScript: GDScript = preload("res://Effects/ice_hammer/ice_hammer.gd")
const FireBurnScript: GDScript = preload("res://Buffs/buffs/fire_burn_debuff.gd")


class FakeEnemy:
	extends Node2D

	var damage_taken: int = 0
	var alive: bool = true
	var buffs: Dictionary = {}
	var added_buff_stacks: Dictionary = {}
	var fire_trigger_calls: Array[Dictionary] = []

	func take_damage(amount: int, _flash_color: Color = Color.WHITE, _style: StringName = &"default") -> void:
		damage_taken += amount

	func is_alive() -> bool:
		return alive

	func has_buff(buff_id: String) -> bool:
		return buffs.has(buff_id)

	func add_buff(buff: BuffDef, stacks: int = 1) -> void:
		buffs[buff.id] = buff.duration
		added_buff_stacks[buff.id] = stacks

	func remove_buff(buff_id: String) -> void:
		buffs.erase(buff_id)

	func trigger_fire_relic_hit(hit_threshold: int, preserve_ticks: bool) -> bool:
		fire_trigger_calls.append({
			"threshold": hit_threshold,
			"preserve_ticks": preserve_ticks,
		})
		return true


func test_fire_bellows_uses_level_threshold_and_awakened_preservation() -> void:
	var enemy: FakeEnemy = add_child_autofree(FakeEnemy.new())
	var effect: RefCounted = FireBellowsScript.new()
	effect.call("set_level", 3)
	effect.call("set_awakened", true)
	effect.call("on_enemy_hit_resolved", enemy, true, false)

	assert_eq(enemy.fire_trigger_calls.size(), 1)
	assert_eq(int(enemy.fire_trigger_calls[0]["threshold"]), 2)
	assert_true(bool(enemy.fire_trigger_calls[0]["preserve_ticks"]))


func test_fire_bellows_requires_preexisting_burn() -> void:
	var enemy: FakeEnemy = add_child_autofree(FakeEnemy.new())
	var effect: RefCounted = FireBellowsScript.new()
	effect.call("on_enemy_hit_resolved", enemy, false, false)

	assert_true(enemy.fire_trigger_calls.is_empty())


func test_fire_burn_extra_tick_consumes_pending_tick_before_damage() -> void:
	var enemy: FakeEnemy = add_child_autofree(FakeEnemy.new())
	var burn: BuffDef = FireBurnScript.new() as BuffDef
	var state: Dictionary = {"pending_ticks": 3}
	for _hit: int in range(4):
		burn.call("trigger_relic_hit", enemy, state, 4, false)

	assert_eq(enemy.damage_taken, 3)
	assert_eq(int(state["pending_ticks"]), 2)


func test_awakened_fire_burn_extra_tick_preserves_pending_ticks() -> void:
	var enemy: FakeEnemy = add_child_autofree(FakeEnemy.new())
	var burn: BuffDef = FireBurnScript.new() as BuffDef
	var state: Dictionary = {"pending_ticks": 3}
	for _hit: int in range(2):
		burn.call("trigger_relic_hit", enemy, state, 2, true)

	assert_eq(enemy.damage_taken, 3)
	assert_eq(int(state["pending_ticks"]), 3)


func test_poison_culture_spreads_to_nearest_unpoisoned_targets_at_level_two() -> void:
	var source: FakeEnemy = _make_enemy(Vector2.ZERO)
	var nearest: FakeEnemy = _make_enemy(Vector2(10.0, 0.0))
	var second: FakeEnemy = _make_enemy(Vector2(20.0, 0.0))
	var third: FakeEnemy = _make_enemy(Vector2(30.0, 0.0))
	third.buffs["poison_debuff"] = 4.0
	var effect: RefCounted = PoisonCultureScript.new()
	effect.call("set_level", 2)
	for _tick: int in range(3):
		effect.call("on_poison_tick", source)

	assert_true(nearest.has_buff("poison_debuff"))
	assert_true(second.has_buff("poison_debuff"))
	assert_eq(float(nearest.buffs["poison_debuff"]), 10.0)
	assert_eq(float(third.buffs["poison_debuff"]), 4.0)


func test_awakened_poison_culture_refreshes_existing_poison() -> void:
	var source: FakeEnemy = _make_enemy(Vector2.ZERO)
	var target: FakeEnemy = _make_enemy(Vector2(10.0, 0.0))
	target.buffs["poison_debuff"] = 2.0
	var effect: RefCounted = PoisonCultureScript.new()
	effect.call("set_awakened", true)
	for _tick: int in range(3):
		effect.call("on_poison_tick", source)

	assert_eq(float(target.buffs["poison_debuff"]), 10.0)


func test_ice_hammer_shatters_frozen_enemy_and_applies_frost_in_radius() -> void:
	var center: FakeEnemy = _make_enemy(Vector2.ZERO)
	center.buffs["frozen_debuff"] = 4.0
	var nearby: FakeEnemy = _make_enemy(Vector2(100.0, 0.0))
	var outside: FakeEnemy = _make_enemy(Vector2(101.0, 0.0))
	var effect: RefCounted = IceHammerScript.new()
	effect.call("set_level", 3)
	effect.call("on_enemy_hit_resolved", center, false, true)

	assert_false(center.has_buff("frozen_debuff"))
	assert_eq(center.damage_taken, 12)
	assert_eq(nearby.damage_taken, 12)
	assert_eq(outside.damage_taken, 0)
	assert_eq(int(center.added_buff_stacks["frost_debuff"]), 1)
	assert_eq(int(nearby.added_buff_stacks["frost_debuff"]), 1)


func test_awakened_ice_hammer_applies_three_frost_stacks() -> void:
	var center: FakeEnemy = _make_enemy(Vector2.ZERO)
	center.buffs["frozen_debuff"] = 4.0
	var effect: RefCounted = IceHammerScript.new()
	effect.call("set_awakened", true)
	effect.call("on_enemy_hit_resolved", center, false, true)

	assert_eq(int(center.added_buff_stacks["frost_debuff"]), 3)


func test_elemental_relic_resources_have_distinct_effect_types() -> void:
	var fire: Item = preload("res://Resources/fire_bellows.tres")
	var poison: Item = preload("res://Resources/poison_culture.tres")
	var ice: Item = preload("res://Resources/ice_hammer.tres")

	assert_eq(fire.effect_type, Item.EffectType.FIRE_BELLOWS)
	assert_eq(poison.effect_type, Item.EffectType.POISON_CULTURE)
	assert_eq(ice.effect_type, Item.EffectType.ICE_HAMMER)
	assert_ne(fire.effect_type, poison.effect_type)
	assert_ne(poison.effect_type, ice.effect_type)


func _make_enemy(position: Vector2) -> FakeEnemy:
	var enemy: FakeEnemy = add_child_autofree(FakeEnemy.new())
	enemy.global_position = position
	enemy.add_to_group("enemies")
	return enemy
