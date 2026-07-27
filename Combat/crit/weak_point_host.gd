extends Node
class_name WeakPointHost

## Runtime component that owns an enemy's directional weak points (the assassin's
## "方位破绽"). Analogous to BuffHost but deliberately NOT a buff: weak points are a
## set of directions with independent lifetimes that relocate on hit and appear only
## while an assassin marble is in the chain.
##
## Presence and tuning are read from the `marble_chain` stat entity:
##   - assassin_weak_point_count: 0 hidden / 1 normal / 2 awakened (written by
##     ItemProgression from the live chain + awakening state)
##   - weak_point_tolerance_deg / weak_point_crit_multiplier / perfect_crit_window_deg
##     / perfect_crit_multiplier
##
## Resolution contract: `try_resolve_crit()` is a pure query (no mutation); the enemy
## writes the result into the DamagePacket and then calls `consume_crit()`, which
## atomically relocates a consumed BASE weak point and emits `crit_landed`.

signal crit_landed(enemy: Node2D, info: Dictionary)

const WeakPointVisualScene: PackedScene = preload("res://Combat/crit/weak_point_visual.tscn")

const STAT_ASSASSIN_WEAK_POINT_COUNT: String = "assassin_weak_point_count"
const STAT_WEAK_POINT_TOLERANCE_DEG: String = "weak_point_tolerance_deg"
const STAT_WEAK_POINT_CRIT_MULTIPLIER: String = "weak_point_crit_multiplier"
const STAT_PERFECT_CRIT_WINDOW_DEG: String = "perfect_crit_window_deg"
const STAT_PERFECT_CRIT_MULTIPLIER: String = "perfect_crit_multiplier"
const STAT_PERFECT_CRIT_ENABLED: String = "perfect_crit_enabled"

const ALL_DIRECTIONS: Array = [
	WeakPoint.Direction.UP,
	WeakPoint.Direction.RIGHT,
	WeakPoint.Direction.DOWN,
	WeakPoint.Direction.LEFT,
]

## Active weak points (WeakPoint instances). BASE points are owned by the assassin
## presence sync; PRISM points (milestone 2) are timed additions.
var weak_points: Array = []

## Perfect crits are gated behind the whetstone awakening (milestone 2). Exposed as a
## settable flag so pure-logic tests can exercise the perfect window while the runtime
## default stays disabled.
var perfect_crit_enabled: bool = false

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _visual: Node2D = null

@onready var _host: Node2D = get_parent()


func _process(delta: float) -> void:
	_tick_prisms(delta)


## Reconciles the number of BASE weak points with assassin_weak_point_count. Never
## touches PRISM points. count 0 hides the weak points entirely.
func sync_to_assassin() -> void:
	var target_count: int = _assassin_weak_point_count()
	var base_points: Array = _base_weak_points()
	if target_count <= 0:
		weak_points.clear()
		_refresh_visual()
		return
	while base_points.size() > target_count:
		var removed: WeakPoint = base_points.pop_back()
		weak_points.erase(removed)
	while base_points.size() < target_count:
		var new_point := WeakPoint.new(_random_free_base_direction(), WeakPoint.Kind.BASE, -1.0)
		weak_points.append(new_point)
		base_points.append(new_point)
	_refresh_visual()


## Pure query: finds the weak point whose center angle is within tolerance of the
## contact angle (in radians, enemy-local). Returns {} when nothing matches, otherwise
## {is_crit, is_perfect, multiplier, kind, direction, weak_point}. Does not mutate.
func try_resolve_crit(contact_angle_rad: float) -> Dictionary:
	var tolerance: float = _stat_float(STAT_WEAK_POINT_TOLERANCE_DEG, 20.0)
	var contact_deg: float = rad_to_deg(contact_angle_rad)
	var best_point: WeakPoint = null
	var best_distance: float = INF
	for wp: Variant in weak_points:
		if not wp is WeakPoint:
			continue
		var point: WeakPoint = wp as WeakPoint
		var distance: float = _angle_distance_deg(contact_deg, point.center_angle_deg())
		if distance <= tolerance and distance < best_distance:
			best_point = point
			best_distance = distance
	if best_point == null:
		return {}
	var perfect_window: float = _stat_float(STAT_PERFECT_CRIT_WINDOW_DEG, 5.0)
	var is_perfect: bool = (perfect_crit_enabled or _stat_float(STAT_PERFECT_CRIT_ENABLED, 0.0) >= 1.0) and best_distance <= perfect_window
	var multiplier: float = _stat_float(STAT_PERFECT_CRIT_MULTIPLIER, 2.25) if is_perfect \
		else _stat_float(STAT_WEAK_POINT_CRIT_MULTIPLIER, 2.0)
	return {
		"is_crit": true,
		"is_perfect": is_perfect,
		"multiplier": multiplier,
		"kind": best_point.kind,
		"direction": best_point.direction,
		"weak_point": best_point,
	}


## Atomic post-hit mutation: relocates a consumed BASE weak point to a free direction
## (never the one just hit) and emits crit_landed. PRISM points are left to expire on
## their own timer. Called by the enemy after it writes the crit into the packet.
func consume_crit(info: Dictionary) -> void:
	if info.is_empty():
		return
	var point: Variant = info.get("weak_point")
	if point is WeakPoint:
		if (point as WeakPoint).kind == WeakPoint.Kind.PRISM:
			weak_points.erase(point)
		else:
			_relocate_if_base(point as WeakPoint)
	crit_landed.emit(_host, info)
	_refresh_visual()


## Milestone 2 hook (skeleton): adds a timed PRISM weak point at a direction.
func try_spawn_prism(avoid_direction: int, duration: float) -> bool:
	for wp: Variant in weak_points:
		if wp is WeakPoint and (wp as WeakPoint).kind == WeakPoint.Kind.PRISM:
			var existing: WeakPoint = wp as WeakPoint
			existing.remaining_time = duration
			existing.total_time = duration
			_refresh_visual()
			return true
	var occupied: Array = []
	for wp: Variant in weak_points:
		if wp is WeakPoint:
			occupied.append((wp as WeakPoint).direction)
	var candidates: Array = []
	for direction: Variant in ALL_DIRECTIONS:
		if int(direction) != avoid_direction and not occupied.has(direction):
			candidates.append(direction)
	if candidates.is_empty():
		return false
	var selected: WeakPoint.Direction = candidates[_rng.randi_range(0, candidates.size() - 1)] as WeakPoint.Direction
	weak_points.append(WeakPoint.new(selected, WeakPoint.Kind.PRISM, duration))
	_refresh_visual()
	return true


func add_prism(direction: WeakPoint.Direction, duration: float) -> void:
	if weak_points.any(func(wp: Variant) -> bool: return wp is WeakPoint and (wp as WeakPoint).direction == direction):
		return
	weak_points.append(WeakPoint.new(direction, WeakPoint.Kind.PRISM, duration))
	_refresh_visual()


## Test seam: deterministic direction selection.
func seed_rng(value: int) -> void:
	_rng.seed = value


func _base_weak_points() -> Array:
	var result: Array = []
	for wp: Variant in weak_points:
		if wp is WeakPoint and (wp as WeakPoint).kind == WeakPoint.Kind.BASE:
			result.append(wp)
	return result


func _random_free_base_direction() -> WeakPoint.Direction:
	var occupied: Array = []
	for wp: Variant in _base_weak_points():
		occupied.append((wp as WeakPoint).direction)
	var free: Array = []
	for dir_value: Variant in ALL_DIRECTIONS:
		if not occupied.has(dir_value):
			free.append(dir_value)
	if free.is_empty():
		return WeakPoint.Direction.UP
	return free[_rng.randi_range(0, free.size() - 1)] as WeakPoint.Direction


func _relocate_if_base(point: WeakPoint) -> void:
	if point.kind != WeakPoint.Kind.BASE or not weak_points.has(point):
		return
	var old_direction: WeakPoint.Direction = point.direction
	var occupied_by_others: Array = []
	for wp: Variant in weak_points:
		if wp is WeakPoint and wp != point:
			occupied_by_others.append((wp as WeakPoint).direction)
	var candidates: Array = []
	for dir_value: Variant in ALL_DIRECTIONS:
		if dir_value != old_direction and not occupied_by_others.has(dir_value):
			candidates.append(dir_value)
	if candidates.is_empty():
		for dir_value: Variant in ALL_DIRECTIONS:
			if dir_value != old_direction:
				candidates.append(dir_value)
	if candidates.is_empty():
		return
	point.direction = candidates[_rng.randi_range(0, candidates.size() - 1)] as WeakPoint.Direction


func _tick_prisms(delta: float) -> void:
	var expired: Array = []
	for wp: Variant in weak_points:
		if not wp is WeakPoint:
			continue
		var point: WeakPoint = wp as WeakPoint
		if point.kind == WeakPoint.Kind.PRISM and not point.is_permanent():
			point.remaining_time -= delta
			if point.remaining_time <= 0.0:
				expired.append(point)
	for point: Variant in expired:
		weak_points.erase(point)
	if not expired.is_empty():
		_refresh_visual()


func _assassin_weak_point_count() -> int:
	return int(_stat_float(STAT_ASSASSIN_WEAK_POINT_COUNT, 0.0))


func _stat_float(stat_id: String, fallback: float) -> float:
	var stat_system: Node = _get_stat_system()
	if stat_system == null or not stat_system.has_method("get_stat"):
		return fallback
	return float(stat_system.call("get_stat", stat_id, "marble_chain"))


func _angle_distance_deg(a: float, b: float) -> float:
	var diff: float = fposmod(a - b + 180.0, 360.0) - 180.0
	return absf(diff)


func _refresh_visual() -> void:
	if weak_points.is_empty():
		if _visual != null and is_instance_valid(_visual):
			_visual.visible = false
		return
	if _visual == null or not is_instance_valid(_visual):
		if WeakPointVisualScene == null:
			return
		# Parent to the enemy (a Node2D), NOT to this host: the host is a plain Node with no
		# transform, so a Node2D parented to it would not inherit the enemy's position and
		# its markers would draw at the world origin (top-left of the screen).
		if _host == null or not is_instance_valid(_host):
			return
		_visual = WeakPointVisualScene.instantiate() as Node2D
		if _visual == null:
			return
		_visual.name = "WeakPointVisual"
		_host.add_child(_visual)
	_visual.visible = true
	if _visual.has_method("update_weak_points"):
		var data: Array = []
		for wp: Variant in weak_points:
			if wp is WeakPoint:
				var point: WeakPoint = wp as WeakPoint
				data.append({
					"direction": point.direction,
					"kind": point.kind,
					"angle_deg": point.center_angle_deg(),
					"is_perfect": perfect_crit_enabled or _stat_float(STAT_PERFECT_CRIT_ENABLED, 0.0) >= 1.0,
					"remaining_time": point.remaining_time,
					"total_time": point.total_time,
					"is_permanent": point.is_permanent(),
				})
		_visual.call("update_weak_points", data)


func _get_stat_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("StatSystem")
