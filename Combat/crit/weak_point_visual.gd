extends Node2D
class_name WeakPointVisual

## Directional weak-point indicator drawn in the enemy's local space, so the markers
## rotate with the enemy and stay aligned with the local contact angle used for crit
## resolution. WeakPointHost parents this node under the ENEMY (a Node2D) on purpose:
## the host itself is a plain Node with no transform, so parenting here would leave the
## markers stuck at the world origin instead of tracking the enemy.
##
## Visual language follows docs/design/archetypes/critical.md §12: cold white / silver
## base markers with low-saturation cyan ticks, purple-white prism markers, and a thin
## gold perfect-core overlay. Each weak point is a pixel sprite placed on the enemy
## outline at its direction and rotated to point outward. The legacy arc drawing is kept
## only as a fallback if the sprite resources fail to load.

const BaseTex: Texture2D = preload("res://Assets/Crit/weak_point_base.png")
const PrismTex: Texture2D = preload("res://Assets/Crit/weak_point_prism.png")
const PerfectCoreTex: Texture2D = preload("res://Assets/Crit/weak_point_perfect_core.png")

## Distance from the enemy center at which a marker is centered. The enemy's visible body
## is ~20px (radius ~10) inside a 32px canvas; 12px hugs the visible outline. Tune these
## two constants together if the marker should sit further out or read larger.
const OUTLINE_RADIUS: float = 12.0
## Displayed edge length (px) of a marker sprite.
const MARKER_DISPLAY_SIZE: float = 12.0

# Legacy arc fallback (only used when the sprite textures fail to load).
const BASE_COLOR: Color = Color(0.85, 0.9, 0.95, 0.95)
const PRISM_COLOR: Color = Color(0.55, 0.85, 0.9, 0.9)
const ARC_RADIUS: float = 14.0
const ARC_HALF_WIDTH_DEG: float = 22.0
const ARC_THICKNESS: float = 2.0

var _arcs: Array = []


func update_weak_points(data: Array) -> void:
	_arcs = data
	queue_redraw()


func _draw() -> void:
	for entry: Variant in _arcs:
		if not entry is Dictionary:
			continue
		var info: Dictionary = entry as Dictionary
		var angle_deg: float = float(info.get("angle_deg", 0.0))
		var kind: int = int(info.get("kind", WeakPoint.Kind.BASE))
		var is_perfect: bool = bool(info.get("is_perfect", false))
		if not _draw_marker(angle_deg, kind, is_perfect):
			_draw_arc_fallback(angle_deg, kind)


func _draw_marker(angle_deg: float, kind: int, is_perfect: bool) -> bool:
	var tex: Texture2D = PrismTex if kind == WeakPoint.Kind.PRISM else BaseTex
	if tex == null:
		return false
	var center_rad: float = deg_to_rad(angle_deg)
	var marker_pos: Vector2 = Vector2.RIGHT.rotated(center_rad) * OUTLINE_RADIUS
	var marker_scale: Vector2 = Vector2(
		MARKER_DISPLAY_SIZE / tex.get_width(),
		MARKER_DISPLAY_SIZE / tex.get_height(),
	)
	# The sprite's "up" (top edge) must point outward, i.e. toward center_rad.
	var marker_rotation: float = center_rad + PI * 0.5
	var top_left: Vector2 = -tex.get_size() * 0.5
	draw_set_transform(marker_pos, marker_rotation, marker_scale)
	draw_texture(tex, top_left)
	if is_perfect and PerfectCoreTex != null:
		var core_top_left: Vector2 = -PerfectCoreTex.get_size() * 0.5
		draw_texture(PerfectCoreTex, core_top_left)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


func _draw_arc_fallback(angle_deg: float, kind: int) -> void:
	var color: Color = PRISM_COLOR if kind == WeakPoint.Kind.PRISM else BASE_COLOR
	var center_rad: float = deg_to_rad(angle_deg)
	var start_angle: float = center_rad - deg_to_rad(ARC_HALF_WIDTH_DEG)
	var end_angle: float = center_rad + deg_to_rad(ARC_HALF_WIDTH_DEG)
	draw_arc(Vector2.ZERO, ARC_RADIUS, start_angle, end_angle, 24, color, ARC_THICKNESS, true)
