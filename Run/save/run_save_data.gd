extends Resource
class_name RunSaveData

const CURRENT_SCHEMA_VERSION: int = 1

@export var schema_version: int = CURRENT_SCHEMA_VERSION
@export var saved_at_unix: int = 0
@export var checkpoint: Dictionary = {}


func is_structurally_valid() -> bool:
	if schema_version != CURRENT_SCHEMA_VERSION or saved_at_unix <= 0:
		return false
	for key: StringName in [&"scope", &"random", &"flow", &"content_ids"]:
		if not checkpoint.has(key):
			return false
	return checkpoint[&"scope"] is Dictionary \
		and checkpoint[&"random"] is Dictionary \
		and checkpoint[&"flow"] is Dictionary \
		and checkpoint[&"content_ids"] is Array
