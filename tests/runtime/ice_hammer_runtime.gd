extends Node2D

const FrozenDebuffScript: GDScript = preload("res://Buffs/buffs/frozen_debuff.gd")
const IceHammerRelic: Item = preload("res://Resources/ice_hammer.tres")

@onready var center: Node2D = $Center
@onready var nearby: Node = $Nearby
@onready var outside: Node = $Outside
@onready var result_label: Label = $CanvasLayer/ResultLabel


func _ready() -> void:
	var inventory: Node = get_node_or_null("/root/Inventory")
	var effect_manager: Node = get_node_or_null("/root/EffectManager")
	if inventory == null or effect_manager == null:
		result_label.text = "冰系验证失败：缺少自动加载"
		return
	for _copy: int in range(4):
		inventory.call("add_item", IceHammerRelic)
	effect_manager.call("_sync_active_effects")
	center.call("add_buff", FrozenDebuffScript.new())
	effect_manager.call("on_enemy_hit_resolved", center, false, true)
	result_label.text = "碎冰锤（觉醒）\n范围伤害 12，施加 3 层冰霜\n近处：%d  范围外：%d" % [
		int(nearby.get("health")),
		int(outside.get("health")),
	]
