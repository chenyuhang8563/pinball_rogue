extends GutTest

## Verifies the plague infection gate: poison reaching the stack threshold tips a
## host into permanent infection, which survives the poison DoT decaying.

const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")


func test_no_infection_below_threshold() -> void:
	var enemy: Enemy = _enemy()
	enemy.add_buff(_buff("poison_debuff"), 3)
	assert_true(enemy.has_buff("poison_debuff"))
	assert_false(enemy.has_buff("infection_debuff"), "3 stacks is below the threshold of 4")


func test_infection_applies_at_threshold() -> void:
	var enemy: Enemy = _enemy()
	enemy.add_buff(_buff("poison_debuff"), 4)
	assert_true(enemy.has_buff("infection_debuff"), "4 poison stacks triggers infection")


func test_infection_applies_when_stacks_cross_threshold_on_refresh() -> void:
	var enemy: Enemy = _enemy()
	enemy.add_buff(_buff("poison_debuff"), 3)
	assert_false(enemy.has_buff("infection_debuff"))
	enemy.add_buff(_buff("poison_debuff"), 1)
	assert_eq(enemy.get_buff_stacks("poison_debuff"), 4)
	assert_true(enemy.has_buff("infection_debuff"), "refreshing to 4 stacks infects")


func test_infection_is_permanent_after_poison_decays() -> void:
	var enemy: Enemy = _enemy()
	enemy.add_buff(_buff("poison_debuff"), 4)
	assert_true(enemy.has_buff("infection_debuff"))
	# Poison duration is 5s; process well past it so the DoT expires.
	enemy.buff_host._process(6.0)
	assert_false(enemy.has_buff("poison_debuff"), "poison DoT decayed")
	assert_true(enemy.has_buff("infection_debuff"), "infection is permanent")


func test_infection_is_not_stackable() -> void:
	var enemy: Enemy = _enemy()
	enemy.add_buff(_buff("poison_debuff"), 4)
	enemy.add_buff(_buff("poison_debuff"), 3)
	assert_eq(enemy.get_buff_stacks("infection_debuff"), 1, "infection never stacks")


func _buff(buff_id: String) -> BuffDef:
	var registry: Node = get_node_or_null("/root/BuffRegistry")
	assert_not_null(registry, "BuffRegistry autoload present in GUT")
	return registry.call("get_buff_def", buff_id) as BuffDef


func _enemy() -> Enemy:
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	add_child_autofree(enemy)
	return enemy
