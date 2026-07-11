extends Node
class_name SkillController

signal skill_changed(item: Item)
signal state_changed(state: State)
signal runtime_changed(current_charges: int, max_charges: int, recharge_progress: float)

enum State {
	IDLE,
	AIMING,
	FIRING,
	RECHARGING,
	CANCELLED,
}

@export var active_skill_action: StringName = &"active_skill"

var state: State = State.IDLE
var equipped_item: Item = null
var definition: SkillDefinition = null
var runtime: SkillRuntime = null
var head_provider: Callable = Callable()
var projectile_parent_provider: Callable = Callable()

var _executor: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_inventory()
	_connect_battle_lifecycle()
	_sync_from_inventory()


func _process(delta: float) -> void:
	if state == State.AIMING:
		if get_tree().paused or _executor == null or not _executor.has_method("has_valid_aim_target"):
			cancel_active_skill("paused_or_executor_missing")
		elif not bool(_executor.call("has_valid_aim_target")):
			cancel_active_skill("head_invalid")
	if get_tree().paused or runtime == null:
		return
	if runtime.advance_recharge(delta) and state == State.RECHARGING and runtime.can_activate():
		_set_state(State.IDLE)
	_emit_runtime_changed()


func _unhandled_input(event: InputEvent) -> void:
	if not InputMap.has_action(active_skill_action):
		return
	if event.is_action_pressed(active_skill_action) and not event.is_echo():
		if press_active_skill():
			get_viewport().set_input_as_handled()
	elif event.is_action_released(active_skill_action):
		if release_active_skill():
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_active_skill("focus_lost")


func _exit_tree() -> void:
	cancel_active_skill("exit_tree")
	clear_projectiles()


func equip_skill(item: Item) -> bool:
	if item == null or item.type != Item.ItemType.SKILL or item.skill_definition == null:
		return false
	var next_definition: SkillDefinition = item.skill_definition as SkillDefinition
	if next_definition == null or next_definition.executor_scene == null:
		return false
	cancel_active_skill("skill_replaced")
	_free_executor()
	equipped_item = item
	definition = next_definition
	runtime = SkillRuntime.new(definition.max_charges, definition.recharge_time)
	_executor = definition.executor_scene.instantiate()
	if _executor == null:
		equipped_item = null
		definition = null
		runtime = null
		return false
	add_child(_executor)
	_set_state(State.IDLE)
	skill_changed.emit(equipped_item)
	_emit_runtime_changed()
	return true


func press_active_skill() -> bool:
	if get_tree().paused or runtime == null or definition == null or _executor == null:
		return false
	if state == State.AIMING or state == State.FIRING or not runtime.can_activate():
		return false
	if definition.activation_mode == SkillDefinition.ActivationMode.INSTANT:
		if not _executor.has_method("execute") or not bool(_executor.call("execute", self, definition)):
			return false
		runtime.try_consume_charge()
		_set_idle_or_recharging()
		_emit_runtime_changed()
		return true
	if not _executor.has_method("begin_aim") or not bool(_executor.call("begin_aim", self, definition)):
		return false
	_set_state(State.AIMING)
	return true


func release_active_skill() -> bool:
	if state != State.AIMING or _executor == null or definition == null or runtime == null:
		return false
	_set_state(State.FIRING)
	var fired: bool = _executor.has_method("release_aim") and bool(_executor.call("release_aim", self, definition))
	if fired:
		runtime.try_consume_charge()
	_set_idle_or_recharging()
	_emit_runtime_changed()
	return fired


func cancel_active_skill(_reason: String = "cancelled") -> void:
	if state != State.AIMING and (_executor == null or not _executor.has_method("is_aiming") or not bool(_executor.call("is_aiming"))):
		return
	_set_state(State.CANCELLED)
	if _executor != null and _executor.has_method("cancel_aim"):
		_executor.call("cancel_aim")
	_set_idle_or_recharging()
	_emit_runtime_changed()


func get_active_head() -> Node:
	if not head_provider.is_valid():
		return null
	var value: Variant = head_provider.call()
	return value as Node


func get_projectile_parent() -> Node:
	if projectile_parent_provider.is_valid():
		var provided: Variant = projectile_parent_provider.call()
		if provided is Node and is_instance_valid(provided):
			return provided as Node
	var tree := get_tree()
	return tree.current_scene if tree != null else null


func find_nearest_enemy(from_position: Vector2) -> Node2D:
	var nearest: Node2D = null
	var nearest_distance: float = INF
	for candidate: Node in get_tree().get_nodes_in_group("enemies"):
		if not candidate is Node2D or not is_instance_valid(candidate):
			continue
		var enemy := candidate as Node2D
		var distance := from_position.distance_squared_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest


func get_current_charges() -> int:
	return runtime.current_charges if runtime != null else 0


func get_max_charges() -> int:
	return runtime.max_charges if runtime != null else 0


func get_recharge_progress() -> float:
	return runtime.get_recharge_progress() if runtime != null else 0.0


func get_aim_direction() -> Vector2:
	if state != State.AIMING or _executor == null or not _executor.has_method("get_aim_direction"):
		return Vector2.ZERO
	return _executor.call("get_aim_direction") as Vector2


func clear_projectiles(_unused: Variant = null) -> void:
	var tree := get_tree()
	if tree == null:
		return
	for projectile: Node in tree.get_nodes_in_group("skill_projectiles"):
		if is_instance_valid(projectile):
			projectile.queue_free()


func _set_idle_or_recharging() -> void:
	_set_state(State.RECHARGING if runtime != null and not runtime.can_activate() else State.IDLE)


func _set_state(next_state: State) -> void:
	if state == next_state:
		return
	state = next_state
	state_changed.emit(state)


func _emit_runtime_changed() -> void:
	if runtime == null:
		runtime_changed.emit(0, 0, 0.0)
		return
	runtime_changed.emit(runtime.current_charges, runtime.max_charges, runtime.get_recharge_progress())


func _free_executor() -> void:
	if _executor == null or not is_instance_valid(_executor):
		_executor = null
		return
	remove_child(_executor)
	_executor.free()
	_executor = null


func _sync_from_inventory() -> void:
	var inventory := _get_autoload_node(&"Inventory")
	if inventory == null:
		return
	var item: Item = inventory.get("skill_item") as Item
	if item != null and (equipped_item == null or equipped_item.id != item.id):
		equip_skill(item)


func _connect_inventory() -> void:
	var inventory := _get_autoload_node(&"Inventory")
	if inventory == null or not inventory.has_signal(&"inventory_changed"):
		return
	var callback := Callable(self, "_sync_from_inventory")
	if not inventory.is_connected(&"inventory_changed", callback):
		inventory.connect(&"inventory_changed", callback)


func _connect_battle_lifecycle() -> void:
	var event_bus := _get_autoload_node(&"Event")
	if event_bus == null:
		return
	if event_bus.has_signal(&"battle_completed"):
		var battle_callback := Callable(self, "_on_battle_completed")
		if not event_bus.is_connected(&"battle_completed", battle_callback):
			event_bus.connect(&"battle_completed", battle_callback)
	if event_bus.has_signal(&"run_completed"):
		var run_callback := Callable(self, "_on_run_completed")
		if not event_bus.is_connected(&"run_completed", run_callback):
			event_bus.connect(&"run_completed", run_callback)


func _on_battle_completed(_group_id: String) -> void:
	cancel_active_skill("battle_completed")
	clear_projectiles()


func _on_run_completed() -> void:
	cancel_active_skill("run_completed")
	clear_projectiles()


func _get_autoload_node(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(node_name))
