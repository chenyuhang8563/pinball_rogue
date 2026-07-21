extends Marble
class_name BlueMarble

const STAT_ENTITY_MARBLE_CHAIN: String = "marble_chain"
const STAT_BLUE_FROST_BONUS_DAMAGE_ENABLED: String = "blue_frost_bonus_damage_enabled"
const STAT_BLUE_FROST_STACKS_PER_HIT: String = "blue_frost_stacks_per_hit"
const FROST_DEBUFF_ID: String = "frost_debuff"
const FROZEN_DEBUFF_ID: String = "frozen_debuff"


static func apply_frost_to_enemy(enemy: Node) -> int:
	if enemy == null:
		return 0
	if enemy.has_method("has_buff") and bool(enemy.call("has_buff", FROZEN_DEBUFF_ID)):
		return 0
	if not enemy.has_method("add_buff"):
		return 0
	var stack_gain: int = _get_frost_stacks_per_hit()
	var current_stacks: int = _get_enemy_frost_stacks(enemy)
	var stacks_after_hit: int = mini(current_stacks + stack_gain, FrostDebuff.MAX_FROST_STACKS)
	var frost_debuff: BuffDef = Marble.make_buff(FROST_DEBUFF_ID)
	if frost_debuff != null:
		enemy.call("add_buff", frost_debuff, stack_gain)
	return stacks_after_hit


static func get_frost_bonus_damage(stacks_after_hit: int) -> int:
	if _get_blue_stat_float(STAT_BLUE_FROST_BONUS_DAMAGE_ENABLED, 0.0) <= 0.0:
		return 0
	return max(0, stacks_after_hit)


func _ready() -> void:
	marble_type = MARBLE_TYPE.BLUE
	super()


func get_hit_damage(target: Node) -> int:
	var stacks_after_hit: int = apply_frost_to_enemy(target)
	return super(target) + get_frost_bonus_damage(stacks_after_hit)


static func _get_enemy_frost_stacks(enemy: Node) -> int:
	if enemy.has_method("get_buff_stacks"):
		return int(enemy.call("get_buff_stacks", FROST_DEBUFF_ID))
	return 0


static func _get_frost_stacks_per_hit() -> int:
	return max(1, roundi(_get_blue_stat_float(STAT_BLUE_FROST_STACKS_PER_HIT, 1.0)))


static func _get_blue_stat_float(stat_id: String, fallback: float) -> float:
	var stat_system: Node = _get_blue_stat_system()
	if stat_system == null or not stat_system.has_method("get_stat"):
		return fallback
	return float(stat_system.call("get_stat", stat_id, STAT_ENTITY_MARBLE_CHAIN))


static func _get_blue_stat_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("StatSystem")
