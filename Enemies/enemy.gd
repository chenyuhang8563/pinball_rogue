extends RigidBody2D

@export var health: int = 100:
	set(value):
		health = max(0, value)
		health_label.text = str(health)
	
@export var flash_duration: float = 0.08

@onready var sprite: Sprite2D = $Sprite2D
@onready var hit_flash: Node = $HitFlash
@onready var health_label: Label = $HealthLabel


func _ready() -> void:
	add_to_group("enemies")
	health_label.text = str(health)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("marbles"):
		EffectManager.on_enemy_hit_by_marble(self)
		take_damage(_get_damage_from_body(body))
		hit_flash.flash()


func take_damage(amount: int) -> void:
	health -= amount
	
	if health <= 0:
		queue_free()


func _get_damage_from_body(body: Node) -> int:
	if body.has_method("get_hit_damage"):
		return body.get_hit_damage(self)
	return 1
