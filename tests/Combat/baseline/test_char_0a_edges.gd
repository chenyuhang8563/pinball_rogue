extends GutTest

## 0a behavior-freeze baseline.
## These assertions use only pre-existing public Enemy/Buff entry points so the
## later packet migration must preserve their observed damage semantics.

const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")
const StatModifierScript: GDScript = preload("res://Core/stats/stat_modifier.gd")


func test_untyped_damage_is_mitigated_by_armor_and_clamped_at_zero() -> void:
	var enemy: Enemy = _enemy()
	var stat_system: Node = get_node_or_null("/root/StatSystem")
	assert_not_null(stat_system)
	stat_system.add_modifier(
		enemy.get_stat_entity_id(),
		StatModifierScript.new("baseline_armor", "armor", StatModifier.ModOp.OVERRIDE, 10.0, "baseline")
	)

	enemy.take_damage(4)
	assert_eq(enemy.health, 100, "armor larger than raw damage must clamp damage at zero")
	enemy.take_damage(13)
	assert_eq(enemy.health, 97, "untyped damage is reduced by armor exactly once")


func test_health_depletion_emits_defeat_once_even_when_damaged_again() -> void:
	var enemy: Enemy = _enemy()
	var causes: Array[StringName] = []
	enemy.defeated.connect(func(_defeated_enemy: Enemy, cause: StringName) -> void:
		causes.append(cause)
	)

	enemy.take_damage(100)
	enemy.take_damage(1)

	assert_eq(causes, [&"health_depleted"])


func _enemy() -> Enemy:
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	add_child_autofree(enemy)
	return enemy
