extends RigidBody2D

const StatContextScript: GDScript = preload("res://Stats/stat_context.gd")

@export var health: int = 100:
	set(value):
		health = max(0, value)
		if health_label != null:
			health_label.text = str(health)

@export var flash_duration: float = 0.08

@onready var sprite: Sprite2D = $Sprite2D
@onready var hit_flash: Node = $HitFlash
@onready var health_label: Label = $HealthLabel
@onready var buff_host: BuffHost = $BuffHost

var _entity_id: String = ""


func _ready() -> void:
	add_to_group("enemies")
	_entity_id = "enemy_%d" % get_instance_id()
	_register_stat_entity()
	_update_health_label()


func _exit_tree() -> void:
	var stat_system: Node = _get_stat_system()
	if stat_system != null and stat_system.has_method("unregister_entity") and _entity_id != "":
		stat_system.call("unregister_entity", _entity_id)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("marbles"):
		EffectManager.on_enemy_hit_by_marble(self)
		var hit_damage: int = _get_damage_from_body(body)
		take_damage(hit_damage, _get_active_buff_flash_color())


func take_damage(amount: int, flash_color: Color = Color.WHITE) -> void:
	var final_damage: int = amount
	var stat_system: Node = _get_stat_system()
	if stat_system != null and stat_system.has_method("get_stat") and _entity_id != "":
		var context: RefCounted = StatContextScript.new(
			_entity_id,
			"",
			"take_damage",
			{"raw_damage": amount}
		)
		final_damage = int(stat_system.call("get_stat", "damage_received", _entity_id, context))
		var current_health: int = int(stat_system.call("get_stat", "current_health", _entity_id))
		stat_system.call("set_stat_base", _entity_id, "current_health", current_health - final_damage)
		health = int(stat_system.call("get_stat", "current_health", _entity_id))
	else:
		health -= final_damage

	flash_hit_mask(flash_color)

	if health <= 0:
		queue_free()


func add_buff(buff: BuffDef, stacks: int = 1) -> void:
	if buff_host != null:
		buff_host.add_buff(buff, stacks)


func has_buff(buff_id: String) -> bool:
	return buff_host != null and buff_host.has_buff(buff_id)


func flash_hit_mask(flash_color: Color) -> void:
	if hit_flash == null or not hit_flash.has_method("flash"):
		return
	hit_flash.call("flash", flash_color)


func _get_damage_from_body(body: Node) -> int:
	if body.has_method("get_hit_damage"):
		return body.get_hit_damage(self)
	return 1


func _get_active_buff_flash_color() -> Color:
	if buff_host == null:
		return Color.WHITE
	return buff_host.get_active_flash_color()


func get_stat_entity_id() -> String:
	return _entity_id


func _register_stat_entity() -> void:
	var stat_system: Node = _get_stat_system()
	if stat_system == null or not stat_system.has_method("register_entity"):
		return
	stat_system.call("register_entity", _entity_id, ["max_health", "current_health", "armor"])
	stat_system.call("set_stat_base", _entity_id, "max_health", float(health))
	stat_system.call("set_stat_base", _entity_id, "current_health", float(health))


func _update_health_label() -> void:
	if health_label != null:
		health_label.text = str(health)


func _get_stat_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("StatSystem")
