extends RigidBody2D

@export var health: int = 100:
	set(value):
		health = max(0, value)
		if health_label != null:
			health_label.text = str(health)

@export var flash_duration: float = 0.08

@onready var sprite: Sprite2D = $Sprite2D
@onready var hit_flash: Node = $HitFlash
@onready var health_label: Label = $HealthLabel
@onready var buff_host: BuffHost = $BuffHost


func _ready() -> void:
	add_to_group("enemies")
	health_label.text = str(health)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("marbles"):
		EffectManager.on_enemy_hit_by_marble(self)
		var hit_damage: int = _get_damage_from_body(body)
		take_damage(hit_damage, _get_active_buff_flash_color())


func take_damage(amount: int, flash_color: Color = Color.WHITE) -> void:
	health -= amount
	flash_hit_mask(flash_color)

	if health <= 0:
		queue_free()


func add_buff(buff: BuffDef, stacks: int = 1) -> void:
	if buff_host != null:
		buff_host.add_buff(buff, stacks)


func has_buff(buff_id: String) -> bool:
	return buff_host != null and buff_host.has_buff(buff_id)


func flash_hit_mask(flash_color: Color) -> void:
	if hit_flash == null or not hit_flash.has_method("flash"):
		return
	hit_flash.call("flash", flash_color)


func _get_damage_from_body(body: Node) -> int:
	if body.has_method("get_hit_damage"):
		return body.get_hit_damage(self)
	return 1


func _get_active_buff_flash_color() -> Color:
	if buff_host == null:
		return Color.WHITE
	return buff_host.get_active_flash_color()
