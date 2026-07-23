extends GutTest

const CremationEffectScript: GDScript = preload("res://Combat/effects/cremation/cremation.gd")
const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")
const ShockwaveScene: PackedScene = preload("res://Combat/effects/cremation/cremation_shockwave.tscn")


func test_cremation_does_not_trigger_below_threshold() -> void:
	var enemy: Enemy = _enemy()
	enemy.add_buff(FireBurnDebuff.new(), 5)
	var effect := CremationEffect.new()
	effect.on_enemy_hit_resolved(enemy, true, false)
	assert_eq(enemy.get_buff_stacks(FireBurnDebuff.BURN_ID), 5)


func test_cremation_triggers_at_threshold_and_consumes_all_fuel() -> void:
	var enemy: Enemy = _enemy()
	enemy.add_buff(FireBurnDebuff.new(), 6)
	var effect := CremationEffect.new()
	effect.on_enemy_hit_resolved(enemy, true, false)
	assert_eq(enemy.get_buff_stacks(FireBurnDebuff.BURN_ID), 0)
	assert_false(enemy.has_buff(FireBurnDebuff.BURN_ID))


func test_cremation_deals_damage_to_nearby_enemies() -> void:
	var center: Enemy = _enemy()
	var neighbor: Enemy = _enemy()
	neighbor.global_position = center.global_position + Vector2(40.0, 0.0)
	center.add_buff(FireBurnDebuff.new(), 6)
	var hp_before: int = neighbor.health
	var effect := CremationEffect.new()
	effect.on_enemy_hit_resolved(center, true, false)
	assert_eq(neighbor.health, hp_before - 18)


func test_cremation_does_not_damage_enemies_outside_radius() -> void:
	var center: Enemy = _enemy()
	var far_enemy: Enemy = _enemy()
	far_enemy.global_position = center.global_position + Vector2(200.0, 0.0)
	center.add_buff(FireBurnDebuff.new(), 6)
	var hp_before: int = far_enemy.health
	var effect := CremationEffect.new()
	effect.on_enemy_hit_resolved(center, true, false)
	assert_eq(far_enemy.health, hp_before)


func test_cremation_shockwave_uses_a_one_shot_particle_explosion() -> void:
	var shockwave: Node2D = ShockwaveScene.instantiate() as Node2D
	add_child_autofree(shockwave)
	var particles: CPUParticles2D = shockwave.get_node_or_null("ExplosionParticles") as CPUParticles2D
	assert_not_null(particles)
	assert_true(particles.one_shot, "cremation is a single detonation, not a looping effect")
	assert_eq(particles.texture.resource_path, "res://Assets/Effects/fire/cremation_burst.png")
	assert_eq(particles.texture.get_width(), 32)
	assert_eq(particles.texture.get_height(), 32)
	assert_eq(particles.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	var material: CanvasItemMaterial = particles.material as CanvasItemMaterial
	assert_not_null(material)
	assert_eq(material.blend_mode, CanvasItemMaterial.BLEND_MODE_ADD)
	assert_null(shockwave.get_node_or_null("Ring"), "the old fire sprite is no longer present")


func _enemy() -> Enemy:
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	add_child_autofree(enemy)
	return enemy
