extends Marble
class_name GreenMarble

## Green marble applies poison to enemies it hits.

const POISON_DEBUFF_ID: String = "poison_debuff"


static func apply_poison_to_enemy(enemy: Node) -> void:
	if enemy == null or not enemy.has_method("add_buff"):
		return
	var poison_debuff: BuffDef = Marble.make_buff(POISON_DEBUFF_ID)
	if poison_debuff != null:
		enemy.call("add_buff", poison_debuff)


func _ready() -> void:
	marble_type = MARBLE_TYPE.GREEN
	super()


func get_hit_damage(target: Node) -> int:
	apply_poison_to_enemy(target)
	return super(target)
