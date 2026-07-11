extends Node2D

const FireBurnDebuffScript: GDScript = preload("res://Buffs/buffs/fire_burn_debuff.gd")

@onready var enemy: Node = $CanvasLayer/Enemy
@onready var result_label: Label = $CanvasLayer/ResultLabel


func _ready() -> void:
	enemy.call("add_buff", FireBurnDebuffScript.new())
	await get_tree().create_timer(3.1).timeout
	result_label.text = "燃烧结算完成：3 → 2 → 1"
