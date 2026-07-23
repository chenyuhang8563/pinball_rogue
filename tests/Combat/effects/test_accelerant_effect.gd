extends GutTest

const AccelerantEffectScript: GDScript = preload("res://Combat/effects/accelerant/accelerant.gd")


class BurningEnemy:
	extends Node2D

	var is_burning: bool = true
	var added_fuel: int = 0

	func has_buff(buff_id: String) -> bool:
		return is_burning and buff_id == "fire_burn_debuff"

	func is_alive() -> bool:
		return true

	func add_buff(_buff: BuffDef, stacks: int) -> void:
		added_fuel += stacks


func after_each() -> void:
	var stat_system: Node = get_node_or_null("/root/StatSystem")
	if stat_system != null:
		stat_system.call("remove_modifier", "marble_chain", "accelerant_fire_burn_tick_seconds")


func test_accelerant_adds_configured_fuel_only_to_burning_targets() -> void:
	var effect: AccelerantEffect = AccelerantEffectScript.new()
	var burning_enemy := BurningEnemy.new()
	add_child_autofree(burning_enemy)

	effect.on_enemy_hit_resolved(burning_enemy, true, false)
	assert_eq(burning_enemy.added_fuel, 1)

	effect.set_level(3)
	effect.set_awakened(true)
	effect.on_enemy_hit_resolved(burning_enemy, true, false)
	assert_eq(burning_enemy.added_fuel, 4, "level III and awakened add 2 + 1 fuel")

	var unburned_enemy := BurningEnemy.new()
	unburned_enemy.is_burning = false
	add_child_autofree(unburned_enemy)
	effect.on_enemy_hit_resolved(unburned_enemy, false, false)
	assert_eq(unburned_enemy.added_fuel, 0)


func test_accelerant_halves_fire_burn_tick_interval_through_stat_system() -> void:
	var stat_system: Node = get_node_or_null("/root/StatSystem")
	assert_not_null(stat_system)
	assert_true(stat_system.call("has_stat", "fire_burn_tick_seconds"))

	var effect: AccelerantEffect = AccelerantEffectScript.new()
	effect.set_level(1)
	assert_almost_eq(
		float(stat_system.call("get_stat", "fire_burn_tick_seconds", "marble_chain")),
		0.5,
		0.001
	)
	assert_almost_eq(FireBurnDebuff.new()._get_fire_burn_tick_seconds(), 0.5, 0.001)
