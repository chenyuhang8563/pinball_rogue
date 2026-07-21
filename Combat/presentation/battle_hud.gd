extends Control
class_name BattleHud

@onready var health_label: Label = $ResourceRows/HealthRow/ValueLabel
@onready var gold_label: Label = $ResourceRows/GoldRow/ValueLabel
@onready var floor_label: Label = $ResourceRows/FloorRow/ValueLabel
@onready var heart_icon: AnimatedSprite2D = $ResourceRows/HealthRow/IconSlot/Heart


func _ready() -> void:
	if heart_icon != null:
		heart_icon.play()
	set_health(0)
	set_gold(0)
	set_floor(1)


func set_health(health: int) -> void:
	if health_label != null:
		health_label.text = str(health)


func set_gold(value: int) -> void:
	if gold_label != null:
		gold_label.text = str(value)


func set_floor(floor_number: int) -> void:
	if floor_label != null:
		floor_label.text = str(maxi(1, floor_number))
