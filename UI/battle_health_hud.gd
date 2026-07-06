extends Control
class_name BattleHealthHud

@onready var health_label: Label = $ResourceRows/HealthRow/ValueLabel
@onready var gold_label: Label = $ResourceRows/GoldRow/ValueLabel
@onready var heart_icon: AnimatedSprite2D = $ResourceRows/HealthRow/IconSlot/Heart


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if heart_icon != null:
		heart_icon.play()
	set_health(0)
	set_gold(0)


func set_health(health: int) -> void:
	if health_label != null:
		health_label.text = str(health)


func set_gold(value: int) -> void:
	if gold_label != null:
		gold_label.text = str(value)
