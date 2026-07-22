extends Marble
class_name FireMarble

const FIRE_BURN_DEBUFF_ID: String = "fire_burn_debuff"


static func apply_burn_to_enemy(enemy: Node, packet: DamagePacket = null) -> void:
	if enemy == null or not enemy.has_method("add_buff"):
		return
	var burn: BuffDef = Marble.make_buff(FIRE_BURN_DEBUFF_ID)
	if burn != null:
		enemy.call("add_buff", burn, 1, packet)


func _ready() -> void:
	marble_type = MARBLE_TYPE.FIRE
	super()


func get_hit_damage(target: Node, packet: DamagePacket = null) -> int:
	apply_burn_to_enemy(target, packet)
	return super(target, packet)
