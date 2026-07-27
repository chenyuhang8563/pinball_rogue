class_name CoinPickup
extends Area2D

signal coin_collected(coin: CoinPickup, amount: int, source: Node)
signal coin_expired(coin: CoinPickup, reason: StringName)

enum State {
	SPAWNING,
	AVAILABLE,
	COLLECTED,
	EXPIRED,
}

@export_range(0.01, 5.0, 0.01) var flight_duration: float = 0.35
@export_range(0.0, 30.0, 0.1) var lifetime_seconds: float = 8.0
@export_range(0.0, 128.0, 1.0) var arc_height: float = 24.0
@export_range(1, 99, 1) var amount: int = 1

@onready var lifetime_timer: Timer = $LifetimeTimer
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _state: State = State.SPAWNING
var _source: Node = null
var _spawn_origin: Vector2 = Vector2.ZERO
var _landing_position: Vector2 = Vector2.ZERO
var _flight_elapsed: float = 0.0


func _ready() -> void:
	add_to_group(&"coin_pickups")
	monitoring = false
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if lifetime_timer != null and not lifetime_timer.timeout.is_connected(_on_lifetime_timeout):
		lifetime_timer.timeout.connect(_on_lifetime_timeout)


func _exit_tree() -> void:
	remove_from_group(&"coin_pickups")
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)
	if lifetime_timer != null and lifetime_timer.timeout.is_connected(_on_lifetime_timeout):
		lifetime_timer.timeout.disconnect(_on_lifetime_timeout)


func begin_spawn(source: Node, origin: Vector2, landing_position: Vector2) -> void:
	_source = source
	_spawn_origin = origin
	_landing_position = landing_position
	global_position = origin
	_flight_elapsed = 0.0
	_state = State.SPAWNING
	monitoring = false
	if lifetime_timer != null:
		lifetime_timer.stop()
	if flight_duration <= 0.0:
		_finish_spawn()


func _physics_process(delta: float) -> void:
	if _state != State.SPAWNING or flight_duration <= 0.0:
		return
	_flight_elapsed = minf(_flight_elapsed + delta, flight_duration)
	var progress: float = _flight_elapsed / flight_duration
	var arc_offset := Vector2.UP * (sin(progress * PI) * arc_height)
	global_position = _spawn_origin.lerp(_landing_position, progress) + arc_offset
	if is_equal_approx(progress, 1.0):
		_finish_spawn()


func _finish_spawn() -> void:
	if _state != State.SPAWNING:
		return
	global_position = _landing_position
	_state = State.AVAILABLE
	monitoring = true
	if animation_player != null and animation_player.has_animation(&"land"):
		animation_player.play(&"land")
	if lifetime_timer != null and lifetime_seconds > 0.0:
		lifetime_timer.start(lifetime_seconds)


func collect_from(marble: Node) -> bool:
	if _state != State.AVAILABLE or not _is_head_marble(marble):
		return false
	_state = State.COLLECTED
	# 本函数会在 body_entered 信号回调中执行，直接改 monitoring 会被引擎拦截，必须延迟设置。
	set_deferred(&"monitoring", false)
	if lifetime_timer != null:
		lifetime_timer.stop()
	coin_collected.emit(self, amount, _source)
	queue_free()
	return true


func expire(reason: StringName = &"expired") -> bool:
	if _state == State.COLLECTED or _state == State.EXPIRED:
		return false
	_state = State.EXPIRED
	# 与 collect_from 对称：过期路径也可能落在信号回调上下文中，统一延迟设置。
	set_deferred(&"monitoring", false)
	if lifetime_timer != null:
		lifetime_timer.stop()
	coin_expired.emit(self, reason)
	queue_free()
	return true


func add_amount(extra_amount: int) -> void:
	amount = maxi(1, amount + maxi(0, extra_amount))


func is_available() -> bool:
	return _state == State.AVAILABLE


func state() -> State:
	return _state


func _on_body_entered(body: Node) -> void:
	collect_from(body)


func _on_lifetime_timeout() -> void:
	expire(&"timeout")


func _is_head_marble(body: Node) -> bool:
	return body is Marble and (body as Marble).is_head and body.is_in_group(&"marbles")
