extends GutTest

## 0a regression: packet migration must preserve the legacy rule that DOT
## bypasses the marble-chain global multiplier while still using Enemy armor.

const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")
const StatModifierScript: GDScript = preload("res://Core/stats/stat_modifier.gd")


func test_poison_tick_uses_armor_but_not_global_damage_multiplier() -> void:
	var enemy: Enemy = _enemy()
	_set_high_global_multiplier()
	var poison := PoisonDebuff.new()
	var state: Dictionary = {}
	poison.on_apply(enemy, state)
	poison.on_process(enemy, state, 1.0)

	var per_layer: float = _stat_value(&"poison_damage_per_layer")
	var expected: int = maxi(0, roundi(per_layer))
	assert_eq(enemy.health, 100 - expected,
		"one poison layer deals one fixed per-layer damage")


func test_burn_tick_uses_armor_but_not_global_damage_multiplier() -> void:
	# Regression source: Phase 0b removed pending/instant burn ticks. Boundary:
	# the first elapsed-second tick still bypasses the marble global multiplier.
	# Per-layer damage follows the fire_burn_damage_per_layer stat value (its
	# base_value when no modifier is present), not the global multiplier.
	var enemy: Enemy = _enemy()
	_set_high_global_multiplier()
	var burn := FireBurnDebuff.new()
	var state: Dictionary = {}
	burn.on_apply(enemy, state)
	burn.on_process(enemy, state, 1.0)

	var per_layer: float = _stat_value(&"fire_burn_damage_per_layer")
	var expected: int = maxi(0, roundi(per_layer))
	assert_eq(enemy.health, 100 - expected,
		"one fuel layer deals the configured per-layer damage")


func after_each() -> void:
	var stat_system: Node = get_node_or_null("/root/StatSystem")
	if stat_system != null:
		stat_system.remove_modifiers_by_source("marble_chain", "dot_packet_test")


func _set_high_global_multiplier() -> void:
	var stat_system: Node = get_node_or_null("/root/StatSystem")
	assert_not_null(stat_system)
	stat_system.add_modifier(
		"marble_chain",
		StatModifierScript.new("dot_packet_multiplier", "damage_multiplier", StatModifier.ModOp.OVERRIDE, 5.0, "dot_packet_test")
	)


## 读取指定 stat 在 marble_chain 实体上的当前值（无 modifier 时即 base_value），
## 期望伤害据此动态计算——调整 .tres 基础数值不应破坏本测试。
func _stat_value(stat_id: StringName) -> float:
	var stat_system: Node = get_node_or_null("/root/StatSystem")
	assert_not_null(stat_system)
	return float(stat_system.call("get_stat", stat_id, "marble_chain"))


func _enemy() -> Enemy:
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	add_child_autofree(enemy)
	return enemy
