extends Marble
class_name BrownMarble

@export var max_echo_stacks: int = 3
@export var echo_bonus_damage: int = 2
@export var echo_timeout: float = 5.0

var echo_stacks: int = 0

@onready var sprite: Sprite2D = $Sprite2D

var _echo_timer: Timer

func _ready() -> void:
	marble_type = MARBLE_TYPE.BROWN
	super()
	body_entered.connect(_on_body_entered)

	_echo_timer = Timer.new()
	_echo_timer.one_shot = true
	_echo_timer.timeout.connect(_clear_echo_stacks)
	add_child(_echo_timer)
	_update_echo_visual()


func get_hit_damage(_target: Node) -> int:
	var hit_damage: int = damage
	if echo_stacks >= max_echo_stacks:
		hit_damage += echo_bonus_damage
		_clear_echo_stacks()
	return hit_damage


func _on_body_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("enemies"):
		return
	_add_echo_stack()


func _add_echo_stack() -> void:
	echo_stacks = min(echo_stacks + 1, max_echo_stacks)
	_echo_timer.start(echo_timeout)
	_update_echo_visual()


func _clear_echo_stacks() -> void:
	echo_stacks = 0
	if is_instance_valid(_echo_timer):
		_echo_timer.stop()
	_update_echo_visual()


func _update_echo_visual() -> void:
	if sprite == null:
		return
	var charge_ratio: float = float(echo_stacks) / float(max_echo_stacks)
	sprite.modulate = Color(1.0, 1.0 + charge_ratio * 0.25, 1.0 - charge_ratio * 0.2)
