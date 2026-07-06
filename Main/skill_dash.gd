extends Panel
# Dash skill slot — click to dash toward the nearest enemy.
# Manages a charge system with timed recharge per charge.

const COOLDOWN_OVERLAY_ALPHA_MAX: float = 0.5

@export var max_charges: int = 3
@export var recharge_time: float = 5.0

var current_charges: int:
	set(value):
		current_charges = clampi(value, 0, max_charges)
		_update_ui()
		if current_charges < max_charges and _recharge_timer != null and _recharge_timer.is_stopped():
			_recharge_timer.start(recharge_time)

var _recharge_timer: Timer
var _cooldown_overlay: ColorRect
var _label: Label


func _ready() -> void:
	_recharge_timer = Timer.new()
	_recharge_timer.one_shot = true
	_recharge_timer.timeout.connect(_on_recharge_timer_timeout)
	add_child(_recharge_timer)

	_cooldown_overlay = $CooldownOverlay
	_label = $Label

	current_charges = max_charges
	_update_ui()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	_try_activate()


func _shortcut_input(event: InputEvent) -> void:
	if _is_dash_key_event(event) and _try_activate():
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _is_dash_key_event(event):
		_try_activate()


## Attempt to consume a charge and activate the dash.
## Returns true if the dash was triggered, false otherwise.
func _try_activate() -> bool:
	if current_charges <= 0:
		return false

	# Check whether any enemies exist before consuming a charge.
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return false

	# Consume a charge and fire the dash signal.
	current_charges -= 1
	_start_cooldown_overlay()
	var event_bus: Node = _get_event_bus()
	if event_bus != null and event_bus.has_signal(&"dash_skill_activated"):
		event_bus.emit_signal(&"dash_skill_activated")
	return true


func _is_dash_key_event(event: InputEvent) -> bool:
	return event is InputEventKey and event.keycode == KEY_Q and event.pressed and not event.echo


func _on_recharge_timer_timeout() -> void:
	current_charges += 1
	if current_charges < max_charges:
		_recharge_timer.start(recharge_time)


func _start_cooldown_overlay() -> void:
	if _cooldown_overlay == null:
		return
	_cooldown_overlay.color = Color(0, 0, 0, COOLDOWN_OVERLAY_ALPHA_MAX)
	var tween: Tween = create_tween()
	tween.tween_property(_cooldown_overlay, "color:a", 0.0, recharge_time)


func _update_ui() -> void:
	if _label == null:
		return
	_label.text = str(current_charges)
	# Dim the skill slot when charges are exhausted.
	if current_charges <= 0:
		modulate = Color(0.5, 0.5, 0.5, 0.5)
	else:
		modulate = Color(1, 1, 1, 1)


func _get_event_bus() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("Event")
