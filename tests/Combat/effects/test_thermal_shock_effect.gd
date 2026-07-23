extends GutTest

const ThermalShockEffectScript: GDScript = preload("res://Combat/effects/thermal_shock/thermal_shock.gd")
const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")


func test_thermal_shock_triggers_when_burn_applied_to_frozen_enemy() -> void:
	var enemy: Enemy = _enemy()
	enemy.add_buff(FrostDebuff.new(), 6)
	assert_true(enemy.has_buff("frozen_debuff"))
	enemy.add_buff(FireBurnDebuff.new(), 3)
	var effect := ThermalShockEffect.new()
	effect.on_status_applied(enemy, &"fire_burn_debuff", 3)
	assert_false(enemy.has_buff("frozen_debuff"))
	assert_false(enemy.has_buff(FireBurnDebuff.BURN_ID))


func test_thermal_shock_triggers_when_frozen_applied_to_burning_enemy() -> void:
	var enemy: Enemy = _enemy()
	enemy.add_buff(FireBurnDebuff.new(), 3)
	enemy.add_buff(FrostDebuff.new(), 6)
	var effect := ThermalShockEffect.new()
	effect.on_status_applied(enemy, &"frozen_debuff", 1)
	assert_false(enemy.has_buff("frozen_debuff"))
	assert_false(enemy.has_buff(FireBurnDebuff.BURN_ID))


func test_thermal_shock_deals_fixed_damage() -> void:
	var enemy: Enemy = _enemy()
	enemy.add_buff(FrostDebuff.new(), 6)
	enemy.add_buff(FireBurnDebuff.new(), 3)
	var hp_before: int = enemy.health
	var effect := ThermalShockEffect.new()
	effect.on_status_applied(enemy, &"fire_burn_debuff", 3)
	assert_eq(enemy.health, hp_before - 30)


func test_thermal_shock_does_not_trigger_without_both_statuses() -> void:
	var enemy: Enemy = _enemy()
	enemy.add_buff(FireBurnDebuff.new(), 3)
	var hp_before: int = enemy.health
	var effect := ThermalShockEffect.new()
	effect.on_status_applied(enemy, &"fire_burn_debuff", 3)
	assert_eq(enemy.health, hp_before)
	assert_true(enemy.has_buff(FireBurnDebuff.BURN_ID))


func _enemy() -> Enemy:
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	add_child_autofree(enemy)
	return enemy
