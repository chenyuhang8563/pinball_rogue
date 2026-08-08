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

@export_group("Dash")
@export var dash_damage_multiplier: float = 1.0
@export var dash_damage_duration: float = 0.0

@export_group("Demolition Charge")
## 爆炸 AOE 半径（px）。升级列 blast_radius。
@export var blast_radius: float = 70.0
## 导火索时长（秒），从抛射瞬间开始计时。升级列 fuse_time。
@export_range(0.5, 10.0, 0.1) var fuse_time: float = 3.0
## 抛射飞行时长（秒）。
@export_range(0.2, 2.0, 0.05) var flight_duration: float = 0.6
## 瞄准时鼠标落点距 Head 的最大距离（px）。
@export var aim_max_distance: float = 160.0
## 抛物线拱高（px）。
@export var aim_arc_height: float = 60.0
## 抛物线预览虚线段数。
@export_range(8, 64, 1) var aim_arc_steps: int = 24
