extends RefCounted
class_name ParasiteEffect

## Relic 寄生 (parasite): plague flies become vectors. When a friendly fly bites an
## enemy, the parasite layers poison on the target, helping it reach infection and
## keeping the rolling infection economy alive.
##
## Triggered through EffectManager.on_fly_bite.

const POISON_DEBUFF_ID: String = "poison_debuff"
const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/parasite.tres")

var _config: RelicLevelConfig = DEFAULT_CONFIG
var _level: int = 1
var _awakened: bool = false


func set_config(config: RelicLevelConfig) -> void:
	_config = config


func set_level(level: int) -> void:
	_level = clampi(level, 1, _config.max_level)


func get_level() -> int:
	return _level


func set_awakened(awakened: bool) -> void:
	_awakened = awakened


func is_awakened() -> bool:
	return _awakened


## Poison stacks layered per fly bite: base value by level plus an awakened bonus.
func get_stacks_per_bite() -> int:
	var base: int = _config.get_value(_level)
	if _awakened:
		base += int(_config.extra.get("awakened_bonus", 1))
	return maxi(0, base)


func on_fly_bite(enemy: Node2D, _packet: DamagePacket = null) -> void:
	var stacks: int = get_stacks_per_bite()
	if stacks <= 0 or enemy == null or not is_instance_valid(enemy):
		return
	if enemy.has_method("is_alive") and not bool(enemy.call("is_alive")):
		return
	if not enemy.has_method("add_buff"):
		return
	var poison: BuffDef = _make_buff(POISON_DEBUFF_ID)
	if poison != null:
		enemy.call("add_buff", poison, stacks)


func _make_buff(buff_id: String) -> BuffDef:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var registry: Node = tree.root.get_node_or_null("BuffRegistry")
	if registry == null or not registry.has_method("get_buff_def"):
		return null
	return registry.call("get_buff_def", buff_id) as BuffDef
