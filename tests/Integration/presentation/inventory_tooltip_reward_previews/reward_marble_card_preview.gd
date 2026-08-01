extends Control

@export var item: Item
@export_range(1, 4, 1) var target_level: int = 1
@export var is_upgrade: bool = false
@export var locale_code: String = "zh_CN"


func _ready() -> void:
	var localization := get_node_or_null("/root/Localization")
	if localization != null and localization.has_method("set_locale"):
		localization.call("set_locale", locale_code)
	var card := get_node("Backdrop/Center/RewardMarbleCard") as RewardMarbleCard
	card.set_reward(item, target_level, is_upgrade)
