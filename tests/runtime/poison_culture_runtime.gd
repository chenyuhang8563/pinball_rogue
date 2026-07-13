extends Node2D

const PoisonDebuffScript: GDScript = preload("res://Buffs/buffs/poison_debuff.gd")
const PoisonCultureRelic: Item = preload("res://Resources/poison_culture.tres")

@onready var source: Node2D = $Source
@onready var result_label: Label = $CanvasLayer/ResultLabel


func _ready() -> void:
	var inventory: Node = get_node_or_null("/root/Inventory")
	var effect_manager: Node = get_node_or_null("/root/EffectManager")
	if inventory == null or effect_manager == null:
		result_label.text = "毒系验证失败：缺少自动加载"
		return
	for _copy: int in range(3):
		inventory.call("add_item", PoisonCultureRelic)
	effect_manager.call("_sync_active_effects")
	source.call("add_buff", PoisonDebuffScript.new())
	for _tick: int in range(3):
		effect_manager.call("on_poison_tick", source)
	var spread_count: int = 0
	for node_name: String in ["TargetA", "TargetB", "TargetC"]:
		var target: Node = get_node(node_name)
		if target.call("has_buff", "poison_debuff"):
			spread_count += 1
	result_label.text = "瘟疫培养皿（3级）\n第 3 次跳伤传播中毒\n传播目标：%d/3" % spread_count
