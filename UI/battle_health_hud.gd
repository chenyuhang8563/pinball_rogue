extends Control
class_name BattleHealthHud

@onready var health_label: Label = $BattleHealthLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_health(0)


func set_health(health: int) -> void:
	if health_label != null:
		health_label.text = "Health: %d" % health
