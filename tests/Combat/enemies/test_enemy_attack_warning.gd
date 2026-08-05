extends GutTest

const NORMAL_PROFILE: EnemyAttackProfile = preload(
	"res://Combat/battle/enemies/attack_warning/normal_profile.tres"
)
const ELITE_PROFILE: EnemyAttackProfile = preload(
	"res://Combat/battle/enemies/attack_warning/elite_profile.tres"
)
const WARNING_SCENE: PackedScene = preload(
	"res://Combat/battle/enemies/attack_warning/enemy_attack_warning.tscn"
)

const TEST_WARNING_RADIUS: float = 80.0
const TEST_WARNING_ANGLE: float = 90.0


func test_invalid_profile_is_rejected_without_starting_a_warning() -> void:
	var warning := add_child_autofree(WARNING_SCENE.instantiate()) as Node
	var phase_before: StringName = warning.call(&"current_phase") as StringName

	assert_false(bool(warning.call(&"configure", Resource.new())))
	assert_eq(warning.call(&"current_phase"), phase_before)
	assert_eq(warning.call(&"fill_progress"), 0.0)


func test_configure_starts_a_left_facing_fill_and_exposes_progress() -> void:
	var warning := add_child_autofree(WARNING_SCENE.instantiate()) as Node
	var profile := _test_profile(0.08, 0.08, 0.04, 0.03)

	assert_true(bool(warning.call(&"configure", profile)))
	assert_eq(warning.call(&"current_phase"), &"filling")
	assert_eq(warning.call(&"current_direction"), EnemyAttackWarning.LEFT_DIRECTION)
	assert_almost_eq(float(warning.call(&"fill_progress")), 0.0, 0.001)

	await wait_physics_frames(2)
	assert_gt(float(warning.call(&"fill_progress")), 0.0)
	var fill := warning.get_node("Fill") as Polygon2D
	assert_gt(_maximum_point_distance(fill.polygon), 0.0)


func test_full_fill_knocks_each_marble_and_emits_one_damage_signal() -> void:
	var warning := add_child_autofree(WARNING_SCENE.instantiate()) as Node2D
	warning.position = Vector2(120.0, 120.0)
	var profile := _test_profile(0.025, 0.08, 0.04, 0.03)
	assert_true(bool(warning.call(&"configure", profile)))

	var first_marble := _add_marble(Vector2(80.0, 120.0))
	var second_marble := _add_marble(Vector2(88.0, 132.0))
	watch_signals(warning)

	await wait_physics_frames(6)
	assert_signal_emitted_with_parameters(warning, &"player_damage_requested", [3])
	assert_signal_emit_count(warning, &"player_damage_requested", 1)
	assert_gt(first_marble.linear_velocity.length(), 0.0)
	assert_gt(second_marble.linear_velocity.length(), 0.0)


func test_empty_area_does_not_emit_damage_when_fill_completes() -> void:
	var warning := add_child_autofree(WARNING_SCENE.instantiate()) as Node
	assert_true(bool(warning.call(&"configure", _test_profile(0.025, 0.08, 0.04, 0.03))))
	watch_signals(warning)

	await wait_physics_frames(6)
	assert_signal_not_emitted(warning, &"player_damage_requested")


func test_interrupt_stuns_clears_fill_and_blocks_the_next_interrupt() -> void:
	var warning := add_child_autofree(WARNING_SCENE.instantiate()) as Node
	var profile := _test_profile(0.08, 0.08, 0.05, 0.2)
	assert_true(bool(warning.call(&"configure", profile)))
	await wait_physics_frames(2)

	assert_true(bool(warning.call(&"interrupt")))
	assert_eq(warning.call(&"current_phase"), &"stunned")
	assert_eq(warning.call(&"fill_progress"), 0.0)
	assert_true(bool(warning.call(&"is_interrupt_immune")))
	assert_false(bool(warning.call(&"interrupt")))

	await wait_physics_frames(8)
	assert_eq(warning.call(&"current_phase"), &"filling")
	assert_eq(warning.call(&"current_direction"), EnemyAttackWarning.RIGHT_DIRECTION)
	assert_true(bool(warning.call(&"is_interrupt_immune")))

	await wait_physics_frames(20)
	assert_false(bool(warning.call(&"is_interrupt_immune")))


func test_completed_fill_enters_cooldown_then_alternates_direction() -> void:
	var warning := add_child_autofree(WARNING_SCENE.instantiate()) as Node
	var profile := _test_profile(0.025, 0.08, 0.04, 0.03)
	assert_true(bool(warning.call(&"configure", profile)))

	await wait_physics_frames(4)
	assert_eq(warning.call(&"current_phase"), &"cooldown")
	assert_eq(warning.call(&"current_direction"), EnemyAttackWarning.LEFT_DIRECTION)
	assert_eq(warning.call(&"fill_progress"), 0.0)

	await wait_physics_frames(8)
	assert_eq(warning.call(&"current_phase"), &"filling")
	assert_eq(warning.call(&"current_direction"), EnemyAttackWarning.RIGHT_DIRECTION)


func _test_profile(
	fill_seconds: float,
	cooldown_seconds: float,
	stun_seconds: float,
	immunity_seconds: float,
) -> EnemyAttackProfile:
	var profile := EnemyAttackProfile.new()
	profile.warning_radius = TEST_WARNING_RADIUS
	profile.warning_angle_degrees = TEST_WARNING_ANGLE
	profile.fill_seconds = fill_seconds
	profile.damage = 3
	profile.attack_cooldown_seconds = cooldown_seconds
	profile.stun_seconds = stun_seconds
	profile.interrupt_immunity_seconds = immunity_seconds
	profile.knockback_impulse = 40.0
	return profile


func _add_marble(world_position: Vector2) -> RigidBody2D:
	var marble := RigidBody2D.new()
	marble.add_to_group(&"marbles")
	marble.collision_layer = 2
	marble.collision_mask = 0
	marble.position = world_position
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	shape.shape = circle
	marble.add_child(shape)
	add_child_autofree(marble)
	return marble


func _maximum_point_distance(points: PackedVector2Array) -> float:
	var maximum: float = 0.0
	for point: Vector2 in points:
		maximum = maxf(maximum, point.length())
	return maximum


func test_normal_and_elite_profiles_match_the_attack_contract() -> void:
	_assert_profile(NORMAL_PROFILE, 24.0, 90.0, 3.0, 1, 1.5, 0.8, 2.0, 100.0)
	_assert_profile(ELITE_PROFILE, 32.0, 120.0, 2.25, 2, 1.25, 0.8, 3.0, 140.0)


func test_scene_prebuilds_detection_and_warning_visuals() -> void:
	var warning := WARNING_SCENE.instantiate() as Node2D
	add_child_autofree(warning)

	assert_not_null(warning.get_node_or_null("Area2D"))
	assert_not_null(warning.get_node_or_null("Area2D/CollisionPolygon2D"))
	assert_not_null(warning.get_node_or_null("Fill"))
	assert_not_null(warning.get_node_or_null("Border"))


func _assert_profile(
	profile: EnemyAttackProfile,
	warning_radius: float,
	warning_angle_degrees: float,
	fill_seconds: float,
	damage: int,
	attack_cooldown_seconds: float,
	stun_seconds: float,
	interrupt_immunity_seconds: float,
	knockback_impulse: float,
) -> void:
	assert_true(profile.is_valid())
	assert_eq(profile.warning_radius, warning_radius)
	assert_eq(profile.warning_angle_degrees, warning_angle_degrees)
	assert_eq(profile.fill_seconds, fill_seconds)
	assert_eq(profile.damage, damage)
	assert_eq(profile.attack_cooldown_seconds, attack_cooldown_seconds)
	assert_eq(profile.stun_seconds, stun_seconds)
	assert_eq(profile.interrupt_immunity_seconds, interrupt_immunity_seconds)
	assert_eq(profile.knockback_impulse, knockback_impulse)
