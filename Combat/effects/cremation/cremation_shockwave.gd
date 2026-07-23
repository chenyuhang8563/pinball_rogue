extends Node2D

## 火葬冲击波视觉：从中心向外扩展并淡出。
## 调用 setup(radius) 设置与伤害判定匹配的视觉半径（像素）。

const EXPAND_DURATION: float = 0.35
## 粒子爆燃的基准半径（像素），用于将伤害半径换算为节点缩放。
const BASE_EFFECT_RADIUS: float = 16.0

var _target_scale: Vector2 = Vector2(5.0, 5.0)


func setup(radius: float) -> void:
	var s: float = maxf(0.1, radius / BASE_EFFECT_RADIUS)
	_target_scale = Vector2(s, s)


func _ready() -> void:
	scale = Vector2(0.1, 0.1)
	modulate.a = 1.0
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", _target_scale, EXPAND_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(self, "modulate:a", 0.0, EXPAND_DURATION)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
