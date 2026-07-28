extends Node

## 全局音效管理器（Autoload: AudioManager）。
## 通过轮转一小池 AudioStreamPlayer 支持高频音效（如弹珠连续命中）的重叠播放，
## 避免新请求截断上一次播放。调用方自行 preload AudioStream 后传入 play_sfx()。

## 同时可重叠播放的音效数量上限；超出后轮转覆盖最早占用的播放器。
const MAX_CONCURRENT_SFX: int = 8

var _players: Array[AudioStreamPlayer] = []
var _next_player_index: int = 0


func _ready() -> void:
	for i in MAX_CONCURRENT_SFX:
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % i
		add_child(player)
		_players.append(player)


## 播放一次音效。stream 为 null 或播放器池为空时静默忽略。
## pitch_scale 可由调用方加入轻微随机抖动，避免密集命中听起来像"机枪"。
func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if stream == null or _players.is_empty():
		return
	var player: AudioStreamPlayer = _players[_next_player_index]
	_next_player_index = (_next_player_index + 1) % _players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()
