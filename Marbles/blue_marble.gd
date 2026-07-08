extends Marble
class_name BlueMarble

const FROST_DEBUFF_SCRIPT: GDScript = preload("res://Buffs/buffs/frost_debuff.gd")


static func apply_frost_to_enemy(enemy: Node) -> void:
	if enemy == null:
		return
	if enemy.has_method("add_buff"):
		var frost_debuff: BuffDef = FROST_DEBUFF_SCRIPT.new() as BuffDef
		enemy.call("add_buff", frost_debuff)


func _ready() -> void:
	marble_type = MARBLE_TYPE.BLUE
	super()


func get_hit_damage(target: Node) -> int:
	apply_frost_to_enemy(target)
	return super(target)
