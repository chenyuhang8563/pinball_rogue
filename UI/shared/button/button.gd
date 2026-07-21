extends Button

signal hovered
signal unhovered

var tween: Tween = null

@export var width_full_rot: float = 48.0

func hover() -> void:
    pivot_offset = size / 2
    var scale_ratio = clampf(width_full_rot / size.x, 0.5, 1.0)
    var scale_target: float = 1.0 + (0.2) * scale_ratio
    hovered.emit()
    if tween and tween.is_running():
        tween.kill()
    
    tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    tween.tween_property(self, "scale:x", scale_target, 0.2)
    tween.parallel().tween_property(self, "scale:y", scale_target, 0.35)
    tween.parallel().tween_property(self, "rotation_degrees", 5.0 * scale_ratio * [-1.0, 1.0].pick_random(), 0.1)
    tween.parallel().tween_property(self, "rotation_degrees", 0.0, 0.1).set_delay(0.1)

func unhover() -> void:
    pivot_offset = size / 2
    var scale_target: float = 1.0
    unhovered.emit()
    if tween and tween.is_running():
        tween.kill()
    
    tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    tween.tween_property(self, "scale:x", scale_target, 0.2)
    tween.parallel().tween_property(self, "scale:y", scale_target, 0.35)
    tween.parallel().tween_property(self, "rotation_degrees", 0.0, 0.1)
    tween.parallel().tween_property(self, "rotation_degrees", 0.0, 0.1).set_delay(0.1)

func _on_mouse_entered() -> void:
    hover()

func _on_mouse_exited() -> void:
    unhover()