extends Node2D

const FireBurnScript: GDScript = preload("res://Buffs/buffs/fire_burn_debuff.gd")
const FireBellowsRelic: Item = preload("res://Resources/fire_bellows.tres")

@onready var target: Node = $Target
@onready var result_label: Label = $CanvasLayer/ResultLabel


func _ready() -> void:
	var inventory: Node = get_node_or_null("/root/Inventory")
	var effect_manager: Node = get_node_or_null("/root/EffectManager")
	if inventory == null or effect_manager == null:
		result_label.text = "火系验证失败：缺少自动加载"
		return
	for _copy: int in range(4):
		inventory.call("add_item", FireBellowsRelic)
	effect_manager.call("_sync_active_effects")
	target.call("add_buff", FireBurnScript.new())
	effect_manager.call("on_enemy_hit_resolved", target, true, false)
	effect_manager.call("on_enemy_hit_resolved", target, true, false)
	result_label.text = "风箱核心（觉醒）\n2 次命中触发额外燃烧\n目标生命：%d" % int(target.get("health"))
