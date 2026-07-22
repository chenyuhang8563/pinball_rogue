extends GutTest

const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")
const StatModifierScript: GDScript = preload("res://Core/stats/stat_modifier.gd")
const MODIFIER_SOURCE: String = "poison_fire_rebalance_test"


class BellowsEnemy:
	extends Node2D

	var burning: bool = false
	var added_stacks: int = 0

	func has_buff(buff_id: String) -> bool:
		return burning and buff_id == FireBurnDebuff.BURN_ID

	func add_buff(_buff: BuffDef, stacks: int = 1, _packet: DamagePacket = null) -> void:
		added_stacks += stacks

	func is_alive() -> bool:
		return true


func after_each() -> void:
	var stat_system: Node = get_node_or_null("/root/StatSystem")
	if stat_system != null:
		stat_system.call("remove_modifiers_by_source", "marble_chain", MODIFIER_SOURCE)


# ---- Burn (fuel model) ----

func test_burn_single_fuel_deals_one_total_damage_then_extinguishes() -> void:
	var enemy: Enemy = _enemy()
	enemy.add_buff(FireBurnDebuff.new(), 1)
	enemy.buff_host._process(1.0)
	assert_eq(enemy.health, 99, "one fuel deals 1 total damage then extinguishes")
	assert_false(enemy.has_buff(FireBurnDebuff.BURN_ID))


func test_burn_fuel_deals_decreasing_damage_then_extinguishes() -> void:
	# Regression source: burn is now a consumable fuel. Boundary: 3 fuel deals
	# 3 + 2 + 1 = 6 total damage across three seconds, then removes itself.
	var enemy: Enemy = _enemy()
	enemy.add_buff(FireBurnDebuff.new(), 3)
	assert_eq(enemy.get_buff_stacks(FireBurnDebuff.BURN_ID), 3)
	enemy.buff_host._process(1.0)
	assert_eq(enemy.health, 97, "3 fuel deals 3 damage, 2 fuel left")
	enemy.buff_host._process(1.0)
	assert_eq(enemy.health, 95, "2 fuel deals 2 damage, 1 fuel left")
	enemy.buff_host._process(1.0)
	assert_eq(enemy.health, 94, "1 fuel deals 1 damage, fuel spent")
	assert_false(enemy.has_buff(FireBurnDebuff.BURN_ID))


func test_burn_fuel_caps_at_base_ten() -> void:
	var enemy: Enemy = _enemy()
	for _index: int in range(12):
		FireMarble.apply_burn_to_enemy(enemy)
	assert_eq(enemy.get_buff_stacks(FireBurnDebuff.BURN_ID), 10)


func test_burn_fuel_cap_follows_stat() -> void:
	_set_stat("fire_burn_max_stacks", 15.0)
	var enemy: Enemy = _enemy()
	for _index: int in range(20):
		FireMarble.apply_burn_to_enemy(enemy)
	assert_eq(enemy.get_buff_stacks(FireBurnDebuff.BURN_ID), 15, "level II raises the fuel cap to 15")


func test_burn_damage_per_fuel_doubles_via_stat() -> void:
	_set_stat("fire_burn_damage_per_layer", 2.0)
	var enemy: Enemy = _enemy()
	enemy.add_buff(FireBurnDebuff.new(), 2)
	enemy.buff_host._process(1.0)
	assert_eq(enemy.health, 96, "level III deals 2 damage per fuel (2 fuel x 2)")


func test_fire_marble_applies_two_fuel_when_awakened_and_caps() -> void:
	_set_stat("fire_fuel_per_hit", 2.0)
	var enemy: Enemy = _enemy()
	FireMarble.apply_burn_to_enemy(enemy)
	assert_eq(enemy.get_buff_stacks(FireBurnDebuff.BURN_ID), 2, "awakened fire marble applies 2 fuel")
	for _index: int in range(5):
		FireMarble.apply_burn_to_enemy(enemy)
	assert_eq(enemy.get_buff_stacks(FireBurnDebuff.BURN_ID), 10, "fuel still caps at base 10")


func test_burn_death_does_not_spread() -> void:
	var dying: Enemy = _enemy()
	var neighbor: Enemy = _enemy()
	neighbor.global_position = dying.global_position + Vector2(24.0, 0.0)
	dying.add_buff(FireBurnDebuff.new(), 5)
	assert_true(dying.defeat(&"no_spread"))
	assert_false(neighbor.has_buff(FireBurnDebuff.BURN_ID), "ember death spread was removed")


# ---- Poison ----

func test_poison_stacks_to_base_ten_and_refreshes_five_seconds() -> void:
	# Regression source: poison now caps at 10 by default and shares a 5 second
	# timer that refreshes on every application.
	var enemy: Enemy = _enemy()
	GreenMarble.apply_poison_to_enemy(enemy)
	assert_eq(enemy.get_buff_stacks("poison_debuff"), 1)
	enemy.buff_host._process(2.0)
	var shortened_time: float = enemy.buff_host.get_buff_remaining_time("poison_debuff")
	assert_lt(shortened_time, 5.0)
	GreenMarble.apply_poison_to_enemy(enemy)
	assert_eq(enemy.get_buff_stacks("poison_debuff"), 2)
	assert_gt(enemy.buff_host.get_buff_remaining_time("poison_debuff"), shortened_time)
	for _index: int in range(20):
		GreenMarble.apply_poison_to_enemy(enemy)
	assert_eq(enemy.get_buff_stacks("poison_debuff"), 10, "base poison cap is 10")


func test_poison_cap_reaches_twenty_via_stat() -> void:
	_set_stat("poison_max_stacks", 20.0)
	var enemy: Enemy = _enemy()
	for _index: int in range(25):
		GreenMarble.apply_poison_to_enemy(enemy)
	assert_eq(enemy.get_buff_stacks("poison_debuff"), 20, "level III / awakened cap is 20")


func test_poison_tick_deals_one_damage_per_layer() -> void:
	var enemy: Enemy = _enemy()
	enemy.add_buff(PoisonDebuff.new(), 2)
	enemy.buff_host._process(1.0)
	assert_eq(enemy.health, 98, "two poison layers deal 2 x 1 damage")


func test_green_marble_applies_two_layers_when_awakened() -> void:
	_set_stat("poison_stacks_per_hit", 2.0)
	var enemy: Enemy = _enemy()
	GreenMarble.apply_poison_to_enemy(enemy)
	assert_eq(enemy.get_buff_stacks("poison_debuff"), 2, "awakened green marble applies 2 layers")


func test_poison_expires_after_five_seconds_without_refresh() -> void:
	var enemy: Enemy = _enemy()
	GreenMarble.apply_poison_to_enemy(enemy)
	assert_true(enemy.has_buff("poison_debuff"))
	enemy.buff_host._process(5.1)
	assert_false(enemy.has_buff("poison_debuff"), "poison expires once the shared 5s timer lapses")


func test_poison_culture_spread_inherits_current_layers() -> void:
	var source: Enemy = _enemy()
	var neighbor: Enemy = _enemy()
	neighbor.global_position = source.global_position + Vector2(24.0, 0.0)
	var culture := PoisonCultureEffect.new()

	for _index: int in range(3):
		culture.on_poison_tick(source, 4)

	assert_eq(neighbor.get_buff_stacks("poison_debuff"), 4)


func test_poison_culture_spread_clamps_to_target_cap() -> void:
	var source: Enemy = _enemy()
	var neighbor: Enemy = _enemy()
	neighbor.global_position = source.global_position + Vector2(24.0, 0.0)
	var culture := PoisonCultureEffect.new()

	for _index: int in range(3):
		culture.on_poison_tick(source, 15)

	assert_eq(neighbor.get_buff_stacks("poison_debuff"), 10, "spread clamps to the target base cap")


# ---- Frost (unchanged) ----

func test_frost_uses_the_configured_two_second_duration() -> void:
	var frost: BuffDef = FrostDebuff.new()
	assert_almost_eq(frost.duration, 2.0, 0.001)


# ---- Fire bellows ----

func test_fire_bellows_counts_first_burning_hit_and_adds_a_layer_at_threshold() -> void:
	var enemy := BellowsEnemy.new()
	add_child_autofree(enemy)
	var bellows := FireBellowsEffect.new()

	enemy.burning = true
	for _index: int in range(3):
		bellows.on_enemy_hit_resolved(enemy, false, false)
	assert_eq(enemy.added_stacks, 0, "the first burning hit counts toward the threshold")
	bellows.on_enemy_hit_resolved(enemy, false, false)
	assert_eq(enemy.added_stacks, 1, "threshold hit adds one fuel")


func test_fire_bellows_threshold_scales_down_at_higher_levels() -> void:
	# Level thresholds are config [4, 3, 2]: level 2 fires on the 3rd hit.
	var level_two_enemy := BellowsEnemy.new()
	add_child_autofree(level_two_enemy)
	var level_two_bellows := FireBellowsEffect.new()
	level_two_bellows.set_level(2)
	level_two_enemy.burning = true
	for _index: int in range(2):
		level_two_bellows.on_enemy_hit_resolved(level_two_enemy, false, false)
	assert_eq(level_two_enemy.added_stacks, 0)
	level_two_bellows.on_enemy_hit_resolved(level_two_enemy, false, false)
	assert_eq(level_two_enemy.added_stacks, 1, "level 2 adds fuel on the 3rd hit")

	# Level 3 fires on the 2nd hit.
	var level_three_enemy := BellowsEnemy.new()
	add_child_autofree(level_three_enemy)
	var level_three_bellows := FireBellowsEffect.new()
	level_three_bellows.set_level(3)
	level_three_enemy.burning = true
	level_three_bellows.on_enemy_hit_resolved(level_three_enemy, false, false)
	assert_eq(level_three_enemy.added_stacks, 0)
	level_three_bellows.on_enemy_hit_resolved(level_three_enemy, false, false)
	assert_eq(level_three_enemy.added_stacks, 1, "level 3 adds fuel on the 2nd hit")


func _set_stat(stat_id: String, value: float) -> void:
	var stat_system: Node = get_node_or_null("/root/StatSystem")
	assert_not_null(stat_system)
	stat_system.call(
		"add_modifier",
		"marble_chain",
		StatModifierScript.new("rebalance_%s" % stat_id, stat_id, StatModifier.ModOp.OVERRIDE, value, MODIFIER_SOURCE)
	)


func _enemy() -> Enemy:
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	add_child_autofree(enemy)
	return enemy
