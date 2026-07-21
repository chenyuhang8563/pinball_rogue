extends RefCounted
class_name StatContext

var entity_id: String = ""
var target_id: String = ""
var event_type: String = ""
var extra: Dictionary = {}
var extra_data: Dictionary = extra


func _init(
	p_entity_id: String = "",
	p_target_id: String = "",
	p_event_type: String = "",
	p_extra: Dictionary = {}
) -> void:
	entity_id = p_entity_id
	target_id = p_target_id
	event_type = p_event_type
	extra = p_extra.duplicate()
	extra_data = extra
