extends Control
class_name FloorHud


@onready var floor_label: Label = $FloorLabel


func set_floor(floor_number: int) -> void:
	if floor_label != null:
		floor_label.text = "楼层：%d" % maxi(1, floor_number)
