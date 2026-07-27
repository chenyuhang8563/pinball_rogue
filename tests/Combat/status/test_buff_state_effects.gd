extends GutTest

const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")

var _registry: Node


func before_each() -> void:
	_registry = get_node_or_null("/root/BuffRegistry")
	assert_not_null(_registry)


func test_registry_is_the_single_source_for_all_enemy_debuffs() -> void:
	for buff_id: String in ["poison_debuff", "frost_debuff", "frozen_debuff", "fire_burn_debuff"]:
		var definition: BuffDef = _registry.get_buff_def(buff_id)
		assert_not_null(definition, buff_id)
		assert_eq(definition.id, buff_id)
		assert_true(_registry.has_buff(buff_id))
	assert_null(_registry.get_buff_def("not_a_buff"))
	assert_false(_registry.has_buff("not_a_buff"))
	# Removed global buffs must no longer be registered.
	assert_false(_registry.has_buff("damage_up"))
	assert_false(_registry.has_buff("speed_up"))
	assert_false(_registry.has_buff("shield"))


func test_marbles_apply_debuffs_through_the_registry() -> void:
	var enemy: Enemy = _enemy()
	GreenMarble.apply_poison_to_enemy(enemy)
	assert_true(enemy.has_buff("poison_debuff"))
	BlueMarble.apply_frost_to_enemy(enemy)
	assert_true(enemy.has_buff("frost_debuff"))
	FireMarble.apply_burn_to_enemy(enemy)
	assert_true(enemy.has_buff("fire_burn_debuff"))


func test_frost_stacks_accumulate_and_convert_to_frozen_at_max() -> void:
	var enemy: Enemy = _enemy()
	for i: int in range(FrostDebuff.MAX_FROST_STACKS - 1):
		BlueMarble.apply_frost_to_enemy(enemy)
	assert_true(enemy.has_buff("frost_debuff"))
	assert_eq(enemy.get_buff_stacks("frost_debuff"), FrostDebuff.MAX_FROST_STACKS - 1)

	BlueMarble.apply_frost_to_enemy(enemy)
	assert_true(enemy.has_buff("frozen_debuff"), "full frost converts to frozen via registry")
	assert_false(enemy.has_buff("frost_debuff"))
	assert_eq(BlueMarble.apply_frost_to_enemy(enemy), 0, "frozen enemy takes no more frost")


func test_burn_from_registry_is_fuel_based_and_expires_when_spent() -> void:
	var enemy: Enemy = _enemy()
	var burn: BuffDef = _registry.get_buff_def("fire_burn_debuff")
	assert_not_null(burn)
	assert_true(burn.is_permanent(), "burn is a permanent fuel, not a timed debuff")
	enemy.add_buff(burn, 1)
	assert_true(enemy.has_buff("fire_burn_debuff"))

	enemy.buff_host._process(1.0)
	assert_false(enemy.has_buff("fire_burn_debuff"), "burn extinguishes once its single fuel is consumed")


func _enemy() -> Enemy:
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	add_child_autofree(enemy)
	return enemy
