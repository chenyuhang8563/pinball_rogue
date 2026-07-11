extends Node2D

const FireBurnDebuffScript: GDScript = preload("res://Buffs/buffs/fire_burn_debuff.gd")

@onready var source: Node = $CanvasLayer/SourceEnemy
@onready var result_label: Label = $CanvasLayer/ResultLabel


func _ready() -> void:
	var burn: BuffDef = FireBurnDebuffScript.new() as BuffDef
	burn.params["ember_spread_enabled"] = true
	source.call("add_buff", burn)
	source.call("take_damage", 100)
	await get_tree().process_frame
	result_label.text = "余烬已传播至最近存活敌人"
