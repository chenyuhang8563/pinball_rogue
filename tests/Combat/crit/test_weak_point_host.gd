extends GutTest

## Pure-logic coverage for WeakPointHost: direction/angle resolution (incl. wrap and
## tolerance boundary), atomic consume-and-relocate rules, prism lifetime, and the
## assassin_weak_point_count -> weak-point presence/visibility mapping. Direction
## assertions are rule-based (not random-value based); RNG is seeded for stability.

const TEST_SOURCE: String = "wp_test"

var _stat_system: Node
var _parent: Node2D
var _host: WeakPointHost


func before_each() -> void:
	_stat_system = get_node_or_null("/root/StatSystem")
	assert_not_null(_stat_system)
	_parent = Node2D.new()
	add_child_autofree(_parent)
	_host = WeakPointHost.new()
	_host.name = "WeakPointHost"
	_parent.add_child(_host)
	_host.seed_rng(1234)


func after_each() -> void:
	if _stat_system != null and is_instance_valid(_stat_system):
		_stat_system.remove_modifiers_by_source("marble_chain", TEST_SOURCE)


func _force_point(direction: int) -> void:
	_host.weak_points.clear()
	_host.weak_points.append(WeakPoint.new(direction, WeakPoint.Kind.BASE, -1.0))


func _set_assassin_count(count: int) -> void:
	_stat_system.add_modifier(
		"marble_chain",
		StatModifier.new(
			"%s:count" % TEST_SOURCE, "assassin_weak_point_count",
			StatModifier.ModOp.OVERRIDE, float(count), TEST_SOURCE
		)
	)


func _base_count() -> int:
	var n: int = 0
	for wp: Variant in _host.weak_points:
		if wp is WeakPoint and (wp as WeakPoint).kind == WeakPoint.Kind.BASE:
			n += 1
	return n


func _prism_count() -> int:
	var n: int = 0
	for wp: Variant in _host.weak_points:
		if wp is WeakPoint and (wp as WeakPoint).kind == WeakPoint.Kind.PRISM:
			n += 1
	return n


func test_weak_point_center_angle_map() -> void:
	assert_eq(WeakPoint.new(WeakPoint.Direction.UP).center_angle_deg(), -90.0)
	assert_eq(WeakPoint.new(WeakPoint.Direction.RIGHT).center_angle_deg(), 0.0)
	assert_eq(WeakPoint.new(WeakPoint.Direction.DOWN).center_angle_deg(), 90.0)
	assert_eq(WeakPoint.new(WeakPoint.Direction.LEFT).center_angle_deg(), 180.0)


func test_hit_at_center_is_crit_with_base_multiplier() -> void:
	# 问题来源：暴击流派调优要求基础暴击提高至 200%。
	# 修复/边界：中心命中必须使用 ×2；完美切入由独立用例覆盖。
	_force_point(WeakPoint.Direction.RIGHT)
	var info: Dictionary = _host.try_resolve_crit(0.0)
	assert_false(info.is_empty())
	assert_true(bool(info.get("is_crit")))
	assert_eq(float(info.get("multiplier")), 2.0)
	assert_eq(int(info.get("direction")), int(WeakPoint.Direction.RIGHT))


func test_hit_outside_tolerance_is_not_crit() -> void:
	_force_point(WeakPoint.Direction.RIGHT)
	# 45 degrees off; nearest base direction is 90 apart so nothing is within 15.
	var info: Dictionary = _host.try_resolve_crit(deg_to_rad(45.0))
	assert_true(info.is_empty())


func test_tolerance_boundary_is_inclusive() -> void:
	# 问题来源：前期破绽命中次数偏少，基础容差扩大到 ±20°。
	# 修复/边界：精确边界仍命中，紧邻的 21° 必须保持非暴击。
	_force_point(WeakPoint.Direction.RIGHT)
	assert_false(_host.try_resolve_crit(deg_to_rad(20.0)).is_empty(), "exactly at tolerance")
	assert_true(_host.try_resolve_crit(deg_to_rad(21.0)).is_empty(), "beyond tolerance")


func test_angle_wraps_around_180() -> void:
	_force_point(WeakPoint.Direction.LEFT)  # center 180
	assert_false(_host.try_resolve_crit(deg_to_rad(170.0)).is_empty(), "just below 180")
	assert_false(_host.try_resolve_crit(deg_to_rad(-170.0)).is_empty(), "wrap across -180/180")
	assert_true(_host.try_resolve_crit(deg_to_rad(0.0)).is_empty(), "opposite direction")


func test_perfect_crit_gated_by_flag() -> void:
	_force_point(WeakPoint.Direction.RIGHT)
	var normal: Dictionary = _host.try_resolve_crit(0.0)
	assert_false(bool(normal.get("is_perfect")))
	assert_eq(float(normal.get("multiplier")), 2.0)

	_host.perfect_crit_enabled = true
	var perfect: Dictionary = _host.try_resolve_crit(0.0)
	assert_true(bool(perfect.get("is_perfect")))
	assert_eq(float(perfect.get("multiplier")), 2.25)

	# Outside the perfect window but inside tolerance -> normal crit again.
	var edge: Dictionary = _host.try_resolve_crit(deg_to_rad(12.0))
	assert_true(bool(edge.get("is_crit")))
	assert_false(bool(edge.get("is_perfect")))


func test_consume_relocates_base_away_from_original() -> void:
	_force_point(WeakPoint.Direction.RIGHT)
	var point: WeakPoint = _host.weak_points[0]
	var info: Dictionary = _host.try_resolve_crit(0.0)
	_host.consume_crit(info)
	assert_ne(int(point.direction), int(WeakPoint.Direction.RIGHT), "must leave the hit side")
	assert_eq(_base_count(), 1, "still exactly one base weak point")


func test_consume_relocate_avoids_occupied_direction() -> void:
	_host.weak_points.clear()
	_host.weak_points.append(WeakPoint.new(WeakPoint.Direction.UP, WeakPoint.Kind.BASE, -1.0))
	_host.weak_points.append(WeakPoint.new(WeakPoint.Direction.DOWN, WeakPoint.Kind.BASE, -1.0))
	var hit_point: WeakPoint = _host.weak_points[0]  # UP
	_host.consume_crit({"is_crit": true, "weak_point": hit_point})
	var other: WeakPoint = _host.weak_points[1]  # DOWN stays
	assert_ne(int(hit_point.direction), int(WeakPoint.Direction.UP), "not the hit side")
	assert_ne(int(hit_point.direction), int(other.direction), "not the occupied side")


func test_consume_prism_removes_only_the_prism() -> void:
	_host.weak_points.clear()
	_host.weak_points.append(WeakPoint.new(WeakPoint.Direction.RIGHT, WeakPoint.Kind.PRISM, 10.0))
	var prism: WeakPoint = _host.weak_points[0]
	var info: Dictionary = _host.try_resolve_crit(0.0)
	assert_eq(int(info.get("kind")), int(WeakPoint.Kind.PRISM))
	_host.consume_crit(info)
	assert_eq(_prism_count(), 0)


func test_prism_expires_after_duration() -> void:
	_host.weak_points.clear()
	_host.add_prism(WeakPoint.Direction.RIGHT, 0.5)
	assert_eq(_prism_count(), 1)
	_host._process(0.6)
	assert_eq(_prism_count(), 0)


func test_count_zero_hides_weak_points() -> void:
	_set_assassin_count(1)
	_host.sync_to_assassin()
	assert_eq(_base_count(), 1)
	_set_assassin_count(0)
	_host.sync_to_assassin()
	assert_eq(_base_count(), 0)
	assert_eq(_host.weak_points.size(), 0)


func test_count_two_creates_distinct_base_directions() -> void:
	_set_assassin_count(2)
	_host.sync_to_assassin()
	assert_eq(_base_count(), 2)
	var a: WeakPoint = _host.weak_points[0]
	var b: WeakPoint = _host.weak_points[1]
	assert_ne(int(a.direction), int(b.direction))


func test_sync_count_zero_removes_all_weak_points_including_prisms() -> void:
	_set_assassin_count(1)
	_host.sync_to_assassin()
	_host.add_prism(WeakPoint.Direction.LEFT, 10.0)
	assert_eq(_prism_count(), 1)

	_set_assassin_count(0)
	_host.sync_to_assassin()
	assert_eq(_base_count(), 0, "base cleared")
	assert_eq(_prism_count(), 0, "prism clears with assassin departure")


func test_spawn_prism_avoids_occupied_and_hit_directions() -> void:
	_host.weak_points.clear()
	_host.weak_points.append(WeakPoint.new(WeakPoint.Direction.RIGHT, WeakPoint.Kind.BASE, -1.0))
	assert_true(_host.try_spawn_prism(WeakPoint.Direction.UP, 2.0))
	assert_eq(_prism_count(), 1)
	var prism: WeakPoint = _host.weak_points.filter(func(wp: Variant) -> bool: return wp is WeakPoint and (wp as WeakPoint).kind == WeakPoint.Kind.PRISM)[0]
	assert_ne(int(prism.direction), int(WeakPoint.Direction.RIGHT))
	assert_ne(int(prism.direction), int(WeakPoint.Direction.UP))


func test_spawn_prism_refreshes_existing_without_rerolling() -> void:
	_host.add_prism(WeakPoint.Direction.LEFT, 1.0)
	var prism: WeakPoint = _host.weak_points[0]
	assert_true(_host.try_spawn_prism(WeakPoint.Direction.RIGHT, 4.0))
	assert_eq(_prism_count(), 1)
	assert_eq(int(prism.direction), int(WeakPoint.Direction.LEFT))
	assert_eq(prism.remaining_time, 4.0)
	assert_eq(prism.total_time, 4.0)
