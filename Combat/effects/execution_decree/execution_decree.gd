extends RefCounted
class_name ExecutionDecreeEffect

const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/execution_decree.tres")

var _config: RelicLevelConfig = DEFAULT_CONFIG
var _level: int = 1
var _awakened: bool = false
var progress: int = 0
var armed: bool = false
var _tracked_event_id: int = 0
var _buffered_progress: int = 0


func set_level(level: int) -> void:
	_level = clampi(level, 1, _config.max_level)
	progress = mini(progress, _threshold())


func get_level() -> int:
	return _level


func set_awakened(awakened: bool) -> void:
	_awakened = awakened


func is_awakened() -> bool:
	return _awakened


func modify_damage_packet(_enemy: Node2D, packet: DamagePacket) -> void:
	if packet == null:
		return
	_begin_event(packet.event_id)
	if packet.is_dot or packet.generation > 0:
		return
	if armed and not packet.is_crit and packet.is_event_main:
		packet.is_crit = true
		packet.crit_multiplier = 2.0
		packet.crit_source = &"execution_decree"
		packet.floating_style = &"crit"
		armed = false
		progress = 0
		return
	if packet.is_crit:
		return
	if packet.event_id == 0:
		_add_progress(1)
	else:
		_buffered_progress += 1


func on_damage_dealt(_enemy: Node2D, packet: DamagePacket) -> void:
	if not _awakened or packet == null or armed:
		return
	if packet.is_crit and (packet.crit_source == &"weak_point_base" or packet.crit_source == &"weak_point_prism"):
		_add_progress(2)


func flush_pending_event() -> void:
	if _buffered_progress > 0:
		_add_progress(_buffered_progress)
		_buffered_progress = 0


func _begin_event(event_id: int) -> void:
	if event_id == _tracked_event_id:
		return
	flush_pending_event()
	_tracked_event_id = event_id


func _add_progress(amount: int) -> void:
	if armed:
		return
	progress = mini(_threshold(), progress + amount)
	if progress >= _threshold():
		armed = true


func _threshold() -> int:
	return maxi(1, _config.get_value(_level))
