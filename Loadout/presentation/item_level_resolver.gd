extends RefCounted
class_name ItemLevelResolver


static func get_inventory_level(item: Item, progression: RefCounted) -> int:
	if item == null or progression == null or not is_instance_valid(progression) \
			or not progression.has_method("level_of"):
		return 0
	return int(progression.call("level_of", item))


static func get_upgrade_option_level(option: Variant) -> int:
	if option is Dictionary:
		if bool((option as Dictionary).get("awakens", false)):
			return 4
		return int((option as Dictionary).get("next_level", 0))
	return 0
