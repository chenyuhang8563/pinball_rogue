extends GutTest

const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")
const StatModifierScript: GDScript = preload("res://Core/stats/stat_modifier.gd")
const MODIFIER_SOURCE: String = "poison_fire_rebalance_test"


class BellowsEnemy:
	extends Node2D

	var burning: bool = false
	var fuel: int = 0

	func has_buff(buff_id: String) -> bool:
		return burning and buff_id == FireBurnDebuff.BURN_ID

	func is_alive() -> bool:
		return true

	func get_buff_stacks(buff_id: String) -> int:
		return fuel if burning and buff_id == FireBurnDebuff.BURN_ID else 0


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
	for _index: int in range(7):
		FireMarble.apply_burn_to_enemy(enemy)
	assert_eq(enemy.get_buff_stacks(FireBurnDebuff.BURN_ID), 10)


func test_burn_fuel_cap_follows_stat() -> void:
	_set_stat("fire_burn_max_stacks", 15.0)
	var enemy: Enemy = _enemy()
	for _index: int in range(12):
		FireMarble.apply_burn_to_enemy(enemy)
	assert_eq(enemy.get_buff_stacks(FireBurnDebuff.BURN_ID), 15, "level II raises the fuel cap to 15")


func test_burn_damage_per_fuel_doubles_via_stat() -> void:
	_set_stat("fire_burn_damage_per_layer", 2.0)
	var enemy: Enemy = _enemy()
	enemy.add_buff(FireBurnDebuff.new(), 2)
	enemy.buff_host._process(1.0)
	assert_eq(enemy.health, 96, "level III deals 2 damage per fuel (2 fuel x 2)")


func test_fire_marble_first_hit_adds_four_fuel_and_followups_add_one() -> void:
	# Regression source: requested burn redesign. Repair: unburned targets receive 4,
	# then every hit during burn adds exactly 1. Boundary: the first follow-up is 5.
	var enemy: Enemy = _enemy()
	FireMarble.apply_burn_to_enemy(enemy)
	assert_eq(enemy.get_buff_stacks(FireBurnDebuff.BURN_ID), 4, "the first fire hit attaches four fuel")
	FireMarble.apply_burn_to_enemy(enemy)
	assert_eq(enemy.get_buff_stacks(FireBurnDebuff.BURN_ID), 5, "a burning target receives one additional fuel")


func test_fire_marble_followup_preserves_the_pending_burn_tick() -> void:
	# Regression source: requested burn redesign. Repair: refreshes add fuel only.
	# Boundary: a hit at 0.5s cannot postpone the tick that is due at 1.0s.
	var enemy: Enemy = _enemy()
	FireMarble.apply_burn_to_enemy(enemy)
	enemy.buff_host._process(0.5)
	FireMarble.apply_burn_to_enemy(enemy)
	enemy.buff_host._process(0.5)
	assert_eq(enemy.health, 95, "the five-fuel tick resolves at the original one-second deadline")
	assert_eq(enemy.get_buff_stacks(FireBurnDebuff.BURN_ID), 4, "the tick consumes one fuel after damage")


func test_fire_marble_burns_four_three_two_one_then_restarts_after_extinguishing() -> void:
	# Regression source: requested burn redesign. Repair: tick pre-consumption fuel then removes one.
	# Boundary: after 4→3→2→1 reaches zero, the next hit is a new four-fuel burn.
	var enemy: Enemy = _enemy()
	FireMarble.apply_burn_to_enemy(enemy)
	var expected_health_after_tick: Array[int] = [96, 93, 91]
	for index: int in range(expected_health_after_tick.size()):
		enemy.buff_host._process(1.0)
		assert_eq(enemy.get_buff_stacks(FireBurnDebuff.BURN_ID), 3 - index)
		assert_eq(enemy.health, expected_health_after_tick[index], "damage resolves from fuel before consuming one")
	enemy.buff_host._process(1.0)
	assert_eq(enemy.health, 90, "four, three, two, one fuel deal ten total burn damage")
	assert_false(enemy.has_buff(FireBurnDebuff.BURN_ID))
	FireMarble.apply_burn_to_enemy(enemy)
	assert_eq(enemy.get_buff_stacks(FireBurnDebuff.BURN_ID), 4, "a new burn starts at four fuel after extinguishing")


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

func test_fire_bellows_selects_unburned_neighbor_before_burning_neighbors() -> void:
	var source := BellowsEnemy.new()
	var burning_neighbor := BellowsEnemy.new()
	var unburned_neighbor := BellowsEnemy.new()
	add_child_autofree(source)
	add_child_autofree(burning_neighbor)
	add_child_autofree(unburned_neighbor)
	source.add_to_group("enemies")
	burning_neighbor.add_to_group("enemies")
	unburned_neighbor.add_to_group("enemies")
	source.burning = true
	burning_neighbor.burning = true
	burning_neighbor.fuel = 1
	source.global_position = Vector2.ZERO
	burning_neighbor.global_position = Vector2(12.0, 0.0)
	unburned_neighbor.global_position = Vector2(48.0, 0.0)

	var bellows := FireBellowsEffect.new()
	assert_eq(bellows._find_spark_target(source), unburned_neighbor)


func test_fire_bellows_spark_count_scales_with_level_and_awakening() -> void:
	var bellows := FireBellowsEffect.new()
	assert_eq(bellows._get_spark_count(), 1)
	bellows.set_level(2)
	assert_eq(bellows._get_spark_count(), 2)
	bellows.set_level(3)
	assert_eq(bellows._get_spark_count(), 3)
	bellows.set_awakened(true)
	assert_eq(bellows._get_spark_count(), 4)


func test_fire_bellows_defers_spark_area_spawn_until_after_physics_callback() -> void:
	# Regression source: Godot reported a physics-query flush error from fire_bellows.gd:52.
	# Repair: defer adding the spark Area2D. Boundary: it appears and initializes next frame.
	var scene := Node2D.new()
	var source := BellowsEnemy.new()
	var target := BellowsEnemy.new()
	get_tree().root.add_child(scene)
	scene.add_child(source)
	scene.add_child(target)
	source.add_to_group("enemies")
	target.add_to_group("enemies")
	source.burning = true
	source.global_position = Vector2(12.0, 18.0)
	target.global_position = Vector2(60.0, 18.0)
	var previous_scene: Node = get_tree().current_scene
	get_tree().current_scene = scene

	var bellows := FireBellowsEffect.new()
	bellows.on_enemy_hit_resolved(source, true, false)
	assert_eq(_count_spark_projectiles(scene), 0, "spark Area2D must not join the scene during the hit callback")

	await get_tree().process_frame
	assert_eq(_count_spark_projectiles(scene), 1, "spark Area2D joins on the following frame")
	get_tree().current_scene = previous_scene
	scene.queue_free()


func test_fire_bellows_spark_uses_a_world_space_particle_trail() -> void:
	var spark: SparkProjectile = preload("res://Combat/effects/fire_bellows/spark_projectile.tscn").instantiate() as SparkProjectile
	add_child_autofree(spark)
	var particles: CPUParticles2D = spark.get_node_or_null("SparkTrailParticles") as CPUParticles2D
	assert_not_null(particles)
	assert_false(particles.one_shot, "the projectile emits sparks throughout its flight")
	assert_false(particles.local_coords, "emitted sparks remain behind the moving projectile")
	assert_eq(particles.texture.resource_path, "res://Assets/Effects/fire/fire_bellows_spark.png")
	assert_eq(particles.texture.get_width(), 32)
	assert_eq(particles.texture.get_height(), 32)
	assert_eq(particles.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	var material: CanvasItemMaterial = particles.material as CanvasItemMaterial
	assert_not_null(material)
	assert_eq(material.blend_mode, CanvasItemMaterial.BLEND_MODE_ADD)
	assert_null(spark.get_node_or_null("Sprite2D"), "the old fire sprite is no longer present")


func _count_spark_projectiles(scene: Node) -> int:
	var spark_count: int = 0
	for child: Node in scene.get_children():
		if child is SparkProjectile:
			spark_count += 1
	return spark_count


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
