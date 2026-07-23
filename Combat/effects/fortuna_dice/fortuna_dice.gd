extends RefCounted
class_name FortunaDiceEffect

const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/fortuna_dice.tres")
const FACES: Array[float] = [0.7, 0.8, 0.9, 1.1, 1.3, 1.5]

var _config: RelicLevelConfig = DEFAULT_CONFIG
var _level: int = 1
var _awakened: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func set_level(level: int) -> void:
	_level = clampi(level, 1, _config.max_level)


func get_level() -> int:
	return _level


func set_awakened(awakened: bool) -> void:
	_awakened = awakened


func is_awakened() -> bool:
	return _awakened


func seed_rng(value: int) -> void:
	_rng.seed = value


func modify_damage_packet(_enemy: Node2D, packet: DamagePacket) -> void:
	if packet == null or packet.is_dot or not is_equal_approx(packet.damage_multiplier, 1.0):
		return
	var first: float = _roll()
	if _awakened:
		packet.damage_multiplier = _flip_low_face(first)
		return
	if _level == 2 and is_equal_approx(first, 0.7):
		packet.damage_multiplier = _roll()
		return
	if _level >= 3 and first < 1.0:
		packet.damage_multiplier = maxf(first, _roll())
		return
	packet.damage_multiplier = first


func _roll() -> float:
	return FACES[_rng.randi_range(0, FACES.size() - 1)]


func _flip_low_face(value: float) -> float:
	if is_equal_approx(value, 0.7):
		return 1.5
	if is_equal_approx(value, 0.8):
		return 1.3
	if is_equal_approx(value, 0.9):
		return 1.1
	return value
