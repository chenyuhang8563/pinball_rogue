extends GutTest

const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")


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


func test_burn_adds_layers_to_ten_and_refreshes_duration() -> void:
	var enemy: Enemy = _enemy()
	FireMarble.apply_burn_to_enemy(enemy)
	enemy.buff_host._process(1.25)
	var shortened_time: float = enemy.buff_host.get_buff_remaining_time(FireBurnDebuff.BURN_ID)
	FireMarble.apply_burn_to_enemy(enemy)

	assert_eq(enemy.get_buff_stacks(FireBurnDebuff.BURN_ID), 2)
	assert_gt(enemy.buff_host.get_buff_remaining_time(FireBurnDebuff.BURN_ID), shortened_time)
	for _index: int in range(8):
		FireMarble.apply_burn_to_enemy(enemy)
	assert_eq(enemy.get_buff_stacks(FireBurnDebuff.BURN_ID), FireBurnDebuff.MAX_BURN_LAYERS)


func test_burn_tick_uses_layers_times_per_layer_stat() -> void:
	# Regression source: burn is elapsed-second DOT, not an immediate pending
	# tick. Boundary: one tick scales linearly with all current layers.
	var enemy: Enemy = _enemy()
	enemy.add_buff(FireBurnDebuff.new(), 4)
	enemy.buff_host._process(1.0)
	assert_eq(enemy.health, 96, "four layers deal 4 x 1 burn damage after one second")


func test_ember_spreads_half_of_current_layers_rounded_up() -> void:
	var dying: Enemy = _enemy()
	var neighbor: Enemy = _enemy()
	neighbor.global_position = dying.global_position + Vector2(24.0, 0.0)
	var burn: BuffDef = FireBurnDebuff.new()
	burn.params["ember_spread_enabled"] = true
	dying.add_buff(burn, 5)

	assert_true(dying.defeat(&"phase0b_ember"))
	assert_eq(neighbor.get_buff_stacks(FireBurnDebuff.BURN_ID), 3)


func test_poison_stacks_to_fifteen_and_refreshes_duration() -> void:
	# Regression source: Phase 0b replaced the old three-stage poison model.
	# Boundary: repeated applications clamp exactly at the 15-stack cap.
	var enemy: Enemy = _enemy()
	GreenMarble.apply_poison_to_enemy(enemy)
	enemy.buff_host._process(2.0)
	var shortened_time: float = enemy.buff_host.get_buff_remaining_time("poison_debuff")
	GreenMarble.apply_poison_to_enemy(enemy)

	assert_eq(enemy.get_buff_stacks("poison_debuff"), 2)
	assert_gt(enemy.buff_host.get_buff_remaining_time("poison_debuff"), shortened_time)
	for _index: int in range(20):
		GreenMarble.apply_poison_to_enemy(enemy)
	assert_eq(enemy.get_buff_stacks("poison_debuff"), PoisonDebuff.MAX_POISON_STACKS)


func test_poison_tick_uses_layers_times_per_layer_stat() -> void:
	var enemy: Enemy = _enemy()
	enemy.add_buff(PoisonDebuff.new(), 2)
	enemy.buff_host._process(1.0)
	assert_eq(enemy.health, 96, "two poison layers deal 2 x 2 damage")


func test_poison_culture_spread_inherits_current_layers() -> void:
	var source: Enemy = _enemy()
	var neighbor: Enemy = _enemy()
	neighbor.global_position = source.global_position + Vector2(24.0, 0.0)
	var culture := PoisonCultureEffect.new()

	for _index: int in range(3):
		culture.on_poison_tick(source, 4)

	assert_eq(neighbor.get_buff_stacks("poison_debuff"), 4)


func test_frost_uses_the_configured_two_second_duration() -> void:
	var frost: BuffDef = FrostDebuff.new()
	assert_almost_eq(frost.duration, 2.0, 0.001)


func test_fire_bellows_counts_first_burning_hit_and_adds_a_layer_at_threshold() -> void:
	var enemy := BellowsEnemy.new()
	add_child_autofree(enemy)
	var bellows := FireBellowsEffect.new()

	enemy.burning = true
	for _index: int in range(3):
		bellows.on_enemy_hit_resolved(enemy, false, false)
	assert_eq(enemy.added_stacks, 0, "the first burning hit counts toward the threshold")
	bellows.on_enemy_hit_resolved(enemy, false, false)
	assert_eq(enemy.added_stacks, 1, "threshold hit adds one burn layer")


func _enemy() -> Enemy:
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	add_child_autofree(enemy)
	return enemy
