extends GutTest

const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")


class FakeMarble:
	extends Node

	func get_hit_damage(_enemy: Node, _packet: RefCounted) -> int:
		return 1


var _enemy: Enemy


func before_each() -> void:
	_enemy = EnemyScene.instantiate() as Enemy
	add_child_autofree(_enemy)


func test_apply_damage_packet_starts_hit_shake_tween() -> void:
	_enemy.apply_damage_packet(DamagePacket.new(&"marble_head", 5.0))
	var tween: Tween = _enemy._hit_shake_tween
	assert_not_null(tween, "受击后应创建晃动 tween")
	assert_true(tween.is_valid(), "晃动 tween 应处于有效运行状态")


func test_hit_shake_retrigger_replaces_running_tween() -> void:
	_enemy.play_hit_shake()
	var first: Tween = _enemy._hit_shake_tween
	_enemy.play_hit_shake()
	var second: Tween = _enemy._hit_shake_tween
	assert_ne(first, second, "再次受击应创建新的 tween")
	assert_false(first.is_valid(), "旧的晃动 tween 应被终止")
	assert_true(second.is_valid(), "新的晃动 tween 应处于有效运行状态")


func test_marble_body_entered_plays_hit_sfx() -> void:
	var audio_manager: Node = get_node_or_null("/root/AudioManager")
	assert_not_null(audio_manager, "AudioManager 自动加载应存在")
	var marble := FakeMarble.new()
	marble.add_to_group("marbles")
	add_child_autofree(marble)

	_enemy._on_body_entered(marble)

	assert_true(_any_manager_player_playing(audio_manager), "弹珠碰撞敌人后应播放碰撞音效")


func _any_manager_player_playing(audio_manager: Node) -> bool:
	for child in audio_manager.get_children():
		if child is AudioStreamPlayer and child.is_playing():
			return true
	return false
