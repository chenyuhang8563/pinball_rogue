extends Control
class_name BattleHud

@onready var health_label: Label = $ResourceRows/HealthRow/ValueLabel
@onready var gold_label: Label = $ResourceRows/GoldRow/ValueLabel
@onready var floor_label: Label = $ResourceRows/FloorRow/ValueLabel
@onready var heart_icon: AnimatedSprite2D = $ResourceRows/HealthRow/IconSlot/Heart
@onready var ammo_label: Label = $ResourceRows/AmmoRow/ValueLabel
@onready var ammo_animation: AnimationPlayer = $ResourceRows/AmmoRow/AmmoAnimation


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


## 弹药行：链中无炸弹弹珠隐藏，0 弹药显示警示色。显隐与颜色全部
## 由 .tscn 内建 AnimationPlayer 离散动画驱动，脚本只写文本、播放动画名。
func set_ammo(current: int, maximum: int, has_bomb: bool) -> void:
	if ammo_label != null:
		ammo_label.text = "%d/%d" % [current, maximum]
	if ammo_animation == null:
		return
	var state: StringName = &"ammo_normal"
	if not has_bomb:
		state = &"ammo_hidden"
	elif current <= 0:
		state = &"ammo_empty"
	ammo_animation.play(state)
	ammo_animation.advance(0.0)
