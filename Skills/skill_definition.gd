extends Resource
class_name SkillDefinition

enum ActivationMode {
	INSTANT,
	HOLD_RELEASE,
}

@export_group("Identity")
@export var id: String = ""
@export var name_key: String = ""
@export var description_key: String = ""
@export var icon: Texture2D
@export var price: int = 0

@export_group("Runtime")
@export var activation_mode: ActivationMode = ActivationMode.INSTANT
@export_range(1, 99, 1) var max_charges: int = 1
@export_range(0.05, 60.0, 0.05) var recharge_time: float = 1.0
@export var executor_scene: PackedScene

@export_group("Magic Missile")
@export var base_damage: int = 10
@export var projectile_speed: float = 220.0
@export var projectile_lifetime: float = 4.0
@export_range(0.01, 1.0, 0.01) var aiming_time_scale: float = 0.15
@export var aim_rotation_speed_degrees: float = 540.0
@export var aim_radius: float = 20.0
@export var spawn_safe_offset: float = 18.0

