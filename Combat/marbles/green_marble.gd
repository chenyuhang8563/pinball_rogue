extends Marble
class_name GreenMarble

## Green marble applies poison to enemies it hits.

const POISON_DEBUFF_ID: String = "poison_debuff"
const STAT_ENTITY_MARBLE_CHAIN: String = "marble_chain"
const STAT_POISON_STACKS_PER_HIT: String = "poison_stacks_per_hit"


static func apply_poison_to_enemy(enemy: Node, packet: DamagePacket = null) -> void:
	if enemy == null or not enemy.has_method("add_buff"):
		return
	var poison_debuff: BuffDef = Marble.make_buff(POISON_DEBUFF_ID)
	if poison_debuff != null:
		enemy.call("add_buff", poison_debuff, _poison_stacks_per_hit(), packet)


## Layers applied per hit: base 1, doubled to 2 once the green marble awakens.
static func _poison_stacks_per_hit() -> int:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return 1
	var stat_system: Node = tree.root.get_node_or_null("StatSystem")
	if stat_system != null and stat_system.has_method("get_stat"):
		return maxi(1, roundi(float(stat_system.call("get_stat", STAT_POISON_STACKS_PER_HIT, STAT_ENTITY_MARBLE_CHAIN))))
	return 1


func _ready() -> void:
	marble_type = MARBLE_TYPE.GREEN
	super()


func get_hit_damage(target: Node, packet: DamagePacket = null) -> int:
	apply_poison_to_enemy(target, packet)
	return super(target, packet)
