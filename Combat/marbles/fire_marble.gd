extends Marble
class_name FireMarble

const FIRE_BURN_DEBUFF_ID: String = "fire_burn_debuff"
const INITIAL_BURN_FUEL: int = 4
const FOLLOWUP_BURN_FUEL: int = 1


static func apply_burn_to_enemy(enemy: Node, packet: DamagePacket = null) -> void:
	if enemy == null or not enemy.has_method("add_buff"):
		return
	var burn: BuffDef = Marble.make_buff(FIRE_BURN_DEBUFF_ID)
	if burn != null:
		var fuel_to_add: int = INITIAL_BURN_FUEL
		if enemy.has_method("has_buff") and bool(enemy.call("has_buff", FIRE_BURN_DEBUFF_ID)):
			fuel_to_add = FOLLOWUP_BURN_FUEL
		enemy.call("add_buff", burn, fuel_to_add, packet)


func _ready() -> void:
	marble_type = MARBLE_TYPE.FIRE
	super()


func get_hit_damage(target: Node, packet: DamagePacket = null) -> int:
	apply_burn_to_enemy(target, packet)
	return super(target, packet)
