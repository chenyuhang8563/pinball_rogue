extends Marble
class_name FireMarble

const FIRE_BURN_DEBUFF_SCRIPT: GDScript = preload("res://Buffs/buffs/fire_burn_debuff.gd")


static func apply_burn_to_enemy(enemy: Node) -> void:
	if enemy == null or not enemy.has_method("add_buff"):
		return
	var burn: BuffDef = FIRE_BURN_DEBUFF_SCRIPT.new() as BuffDef
	enemy.call("add_buff", burn)


func _ready() -> void:
	marble_type = MARBLE_TYPE.FIRE
	super()


func get_hit_damage(target: Node) -> int:
	apply_burn_to_enemy(target)
	return super(target)
