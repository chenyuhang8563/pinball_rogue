extends GutTest

const AudioManagerScript: GDScript = preload("res://Core/audio/audio_manager.gd")
const MarbleHitSfx: AudioStream = preload("res://Assets/SFX/marble_hit.wav")

var _manager: Node


func before_each() -> void:
	_manager = AudioManagerScript.new()
	add_child_autofree(_manager)


func test_play_sfx_starts_a_player() -> void:
	_manager.play_sfx(MarbleHitSfx)
	assert_true(_at_least_n_players_playing(1), "播放一次后应有播放器处于播放状态")


func test_repeated_play_rotates_players_for_overlap() -> void:
	_manager.play_sfx(MarbleHitSfx)
	_manager.play_sfx(MarbleHitSfx)
	assert_true(_at_least_n_players_playing(2), "连续两次播放应占用不同播放器以支持重叠")


func test_volume_and_pitch_are_applied() -> void:
	_manager.play_sfx(MarbleHitSfx, -6.0, 1.5)
	var player: AudioStreamPlayer = _manager.get_child(0) as AudioStreamPlayer
	assert_eq(player.volume_db, -6.0)
	assert_eq(player.pitch_scale, 1.5)


func test_null_stream_is_ignored() -> void:
	_manager.play_sfx(null)
	assert_false(_at_least_n_players_playing(1), "空音效不应启动任何播放器")


func _at_least_n_players_playing(count: int) -> bool:
	var playing: int = 0
	for child in _manager.get_children():
		if child is AudioStreamPlayer and child.is_playing():
			playing += 1
	return playing >= count
