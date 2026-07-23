extends GutTest

const MiasmaEffectScript: GDScript = preload("res://Combat/effects/miasma/miasma.gd")
const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")


func test_miasma_triggers_when_burn_applied_to_poisoned_enemy() -> void:
	var enemy: Enemy = _enemy()
	enemy.add_buff(PoisonDebuff.new(), 3)
	enemy.add_buff(FireBurnDebuff.new(), 2)
	var effect := MiasmaEffect.new()
	effect.on_status_applied(enemy, &"fire_burn_debuff", 2)
	assert_false(enemy.has_buff("poison_debuff"))
	assert_true(enemy.has_buff(FireBurnDebuff.BURN_ID))


func test_miasma_triggers_when_poison_applied_to_burning_enemy() -> void:
	var enemy: Enemy = _enemy()
	enemy.add_buff(FireBurnDebuff.new(), 2)
	enemy.add_buff(PoisonDebuff.new(), 3)
	var effect := MiasmaEffect.new()
	effect.on_status_applied(enemy, &"poison_debuff", 3)
	assert_false(enemy.has_buff("poison_debuff"))
	assert_true(enemy.has_buff(FireBurnDebuff.BURN_ID))


func test_miasma_deals_area_damage_to_nearby_enemies() -> void:
	var center: Enemy = _enemy()
	var neighbor: Enemy = _enemy()
	neighbor.global_position = center.global_position + Vector2(40.0, 0.0)
	center.add_buff(PoisonDebuff.new(), 3)
	center.add_buff(FireBurnDebuff.new(), 2)
	var hp_before: int = neighbor.health
	var effect := MiasmaEffect.new()
	effect.on_status_applied(center, &"fire_burn_debuff", 2)
	assert_eq(neighbor.health, hp_before - 20)


func test_miasma_does_not_damage_enemies_outside_radius() -> void:
	var center: Enemy = _enemy()
	var far_enemy: Enemy = _enemy()
	far_enemy.global_position = center.global_position + Vector2(100.0, 0.0)
	center.add_buff(PoisonDebuff.new(), 3)
	center.add_buff(FireBurnDebuff.new(), 2)
	var hp_before: int = far_enemy.health
	var effect := MiasmaEffect.new()
	effect.on_status_applied(center, &"fire_burn_debuff", 2)
	assert_eq(far_enemy.health, hp_before)


func test_miasma_does_not_clear_burn() -> void:
	var enemy: Enemy = _enemy()
	enemy.add_buff(PoisonDebuff.new(), 3)
	enemy.add_buff(FireBurnDebuff.new(), 5)
	var effect := MiasmaEffect.new()
	effect.on_status_applied(enemy, &"fire_burn_debuff", 5)
	assert_eq(enemy.get_buff_stacks(FireBurnDebuff.BURN_ID), 5)


func _enemy() -> Enemy:
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	add_child_autofree(enemy)
	return enemy
