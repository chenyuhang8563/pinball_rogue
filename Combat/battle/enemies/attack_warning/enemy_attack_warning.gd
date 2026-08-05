class_name EnemyAttackWarning
extends Node2D

signal player_damage_requested(amount: int)
signal warning_started(direction: Vector2)
signal attack_resolved(direction: Vector2, hit_count: int)
signal interrupted

const LEFT_DIRECTION: Vector2 = Vector2(-0.70710678, 0.70710678)
const RIGHT_DIRECTION: Vector2 = Vector2(0.70710678, 0.70710678)

const PHASE_IDLE: StringName = &"idle"
const PHASE_FILLING: StringName = &"filling"
const PHASE_STUNNED: StringName = &"stunned"
const PHASE_COOLDOWN: StringName = &"cooldown"

var _profile: EnemyAttackProfile = null
var _phase: StringName = PHASE_IDLE
@export var default_profile: EnemyAttackProfile

var _current_direction: Vector2 = LEFT_DIRECTION
var _next_direction_is_left: bool = true
var _fill_elapsed: float = 0.0
var _phase_remaining: float = 0.0
var _interrupt_immunity_remaining: float = 0.0
var _stunned_body: RigidBody2D = null
var _stunned_body_was_frozen: bool = false


func _ready() -> void:
	if _profile == null and default_profile != null:
		configure(default_profile)


func _exit_tree() -> void:
	_end_stun()


func _physics_process(delta: float) -> void:
	if _profile == null:
		return

	_interrupt_immunity_remaining = maxf(
		0.0, _interrupt_immunity_remaining - maxf(delta, 0.0)
	)
	match _phase:
		PHASE_FILLING:
			_fill_elapsed += maxf(delta, 0.0)
			if _fill_elapsed >= _profile.fill_seconds:
				_fill_elapsed = _profile.fill_seconds
				_refresh_visuals()
				_resolve_attack()
			else:
				_refresh_visuals()
		PHASE_STUNNED:
			_phase_remaining -= maxf(delta, 0.0)
			if _phase_remaining <= 0.0:
				_end_stun()
				_start_new_fill()
		PHASE_COOLDOWN:
			_phase_remaining -= maxf(delta, 0.0)
			if _phase_remaining <= 0.0:
				_start_new_fill()


func configure(next_profile: Resource) -> bool:
	if not next_profile is EnemyAttackProfile:
		return false
	var typed_profile: EnemyAttackProfile = next_profile as EnemyAttackProfile
	if not typed_profile.is_valid():
		return false

	_end_stun()
	_profile = typed_profile
	_phase = PHASE_IDLE
	_current_direction = LEFT_DIRECTION
	_next_direction_is_left = true
	_fill_elapsed = 0.0
	_phase_remaining = 0.0
	_interrupt_immunity_remaining = 0.0
	_start_new_fill()
	return true


func interrupt() -> bool:
	if _profile == null or _phase != PHASE_FILLING or is_interrupt_immune():
		return false

	_fill_elapsed = 0.0
	_interrupt_immunity_remaining = _profile.interrupt_immunity_seconds
	if _profile.stun_seconds > 0.0:
		_phase = PHASE_STUNNED
		_phase_remaining = _profile.stun_seconds
		_begin_stun()
	else:
		_start_new_fill()
	_refresh_visuals()
	_play_idle_animation()
	interrupted.emit()
	return true


func current_direction() -> Vector2:
	return _current_direction


func current_phase() -> StringName:
	return _phase


func fill_progress() -> float:
	if _profile == null or _phase != PHASE_FILLING:
		return 0.0
	return clampf(_fill_elapsed / _profile.fill_seconds, 0.0, 1.0)


func is_interrupt_immune() -> bool:
	return _interrupt_immunity_remaining > 0.0


func _start_new_fill() -> void:
	_current_direction = LEFT_DIRECTION if _next_direction_is_left else RIGHT_DIRECTION
	_next_direction_is_left = not _next_direction_is_left
	_fill_elapsed = 0.0
	_phase_remaining = 0.0
	_phase = PHASE_FILLING
	_refresh_visuals()
	_play_idle_animation()
	warning_started.emit(_current_direction)


func _resolve_attack() -> void:
	var area: Area2D = get_node_or_null(^"Area2D") as Area2D
	var hit_count: int = 0
	if area != null and area.monitoring:
		for body: Node2D in area.get_overlapping_bodies():
			var marble: RigidBody2D = body as RigidBody2D
			if marble == null or not marble.is_in_group(&"marbles"):
				continue
			_apply_knockback(marble)
			hit_count += 1

		if hit_count > 0:
			player_damage_requested.emit(_profile.damage)
	attack_resolved.emit(_current_direction, hit_count)
	_play_attack_animation()

	_phase = PHASE_COOLDOWN
	_phase_remaining = _profile.attack_cooldown_seconds
	_fill_elapsed = 0.0
	_refresh_visuals()
	if _phase_remaining <= 0.0:
		_start_new_fill()


func _apply_knockback(marble: RigidBody2D) -> void:
	var impulse_direction: Vector2 = marble.global_position - global_position
	if impulse_direction.length_squared() <= 0.0001:
		impulse_direction = _current_direction
	else:
		impulse_direction = impulse_direction.normalized()
	marble.set_sleeping(false)
	marble.apply_central_impulse(impulse_direction * _profile.knockback_impulse)


func _begin_stun() -> void:
	var body: RigidBody2D = get_parent() as RigidBody2D
	if body == null:
		return
	_stunned_body = body
	_stunned_body_was_frozen = body.freeze
	body.freeze = true
	body.linear_velocity = Vector2.ZERO
	body.angular_velocity = 0.0


func _end_stun() -> void:
	if _stunned_body == null or not is_instance_valid(_stunned_body):
		_stunned_body = null
		return
	_stunned_body.freeze = _stunned_body_was_frozen
	_stunned_body = null


func _refresh_visuals() -> void:
	var area: Area2D = get_node_or_null(^"Area2D") as Area2D
	var collision_polygon: CollisionPolygon2D = get_node_or_null(
		^"Area2D/CollisionPolygon2D"
	) as CollisionPolygon2D
	var fill: Polygon2D = get_node_or_null(^"Fill") as Polygon2D
	var border: Line2D = get_node_or_null(^"Border") as Line2D
	if _profile == null:
		return

	var sector: PackedVector2Array = _sector_polygon(
		_profile.warning_radius, _profile.warning_angle_degrees
	)
	var angle: float = _current_direction.angle()
	if area != null:
		area.set_deferred("rotation", angle)
		if not area.monitoring:
			area.set_deferred("monitoring", true)
	if collision_polygon != null:
		collision_polygon.set_deferred("polygon", sector)
	if fill != null:
		fill.rotation = angle
		fill.polygon = _sector_polygon(
			_profile.warning_radius * fill_progress(), _profile.warning_angle_degrees
		)
		fill.visible = _phase == PHASE_FILLING
	if border != null:
		border.rotation = angle
		border.points = _sector_outline(
			_profile.warning_radius, _profile.warning_angle_degrees
		)
		border.visible = _phase == PHASE_FILLING


func _sector_polygon(radius: float, angle_degrees: float) -> PackedVector2Array:
	var points := PackedVector2Array([Vector2.ZERO])
	var half_angle: float = deg_to_rad(angle_degrees * 0.5)
	var arc_angle: float = deg_to_rad(angle_degrees)
	var segment_count: int = maxi(8, ceili(angle_degrees / 12.0))
	for index: int in range(segment_count + 1):
		var progress: float = float(index) / float(segment_count)
		points.append(
			Vector2.RIGHT.rotated(-half_angle + arc_angle * progress) * radius
		)
	return points


func _sector_outline(radius: float, angle_degrees: float) -> PackedVector2Array:
	var points := _sector_polygon(radius, angle_degrees)
	points.append(Vector2.ZERO)
	return points


func _play_attack_animation() -> void:
	var player: AnimationPlayer = get_parent().get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if player == null:
		return
	var animation_name: StringName = &"attack_left" \
			if _current_direction.x < 0.0 else &"attack_right"
	if player.has_animation(animation_name):
		player.play(animation_name)


func _play_idle_animation() -> void:
	var player: AnimationPlayer = get_parent().get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if player != null and player.has_animation(&"idle"):
		player.play(&"idle")
