extends Marble
class_name FireMarble

const FIRE_BURN_DEBUFF_ID: String = "fire_burn_debuff"
const STAT_ENTITY_MARBLE_CHAIN: String = "marble_chain"
const STAT_FIRE_FUEL_PER_HIT: String = "fire_fuel_per_hit"


static func apply_burn_to_enemy(enemy: Node, packet: DamagePacket = null) -> void:
	if enemy == null or not enemy.has_method("add_buff"):
		return
	var burn: BuffDef = Marble.make_buff(FIRE_BURN_DEBUFF_ID)
	if burn != null:
		enemy.call("add_buff", burn, _fire_fuel_per_hit(), packet)


## Fuel added per hit: base 1, doubled to 2 once the fire marble awakens.
static func _fire_fuel_per_hit() -> int:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return 1
	var stat_system: Node = tree.root.get_node_or_null("StatSystem")
	if stat_system != null and stat_system.has_method("get_stat"):
		return maxi(1, roundi(float(stat_system.call("get_stat", STAT_FIRE_FUEL_PER_HIT, STAT_ENTITY_MARBLE_CHAIN))))
	return 1


func _ready() -> void:
	marble_type = MARBLE_TYPE.FIRE
	super()


func get_hit_damage(target: Node, packet: DamagePacket = null) -> int:
	apply_burn_to_enemy(target, packet)
	return super(target, packet)
