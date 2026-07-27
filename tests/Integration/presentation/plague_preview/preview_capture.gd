extends Node2D

@export var output_file: String


func _ready() -> void:
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	assert(DirAccess.make_dir_recursive_absolute("E:/Projects/pinball_rogue/.codex/hud_screenshots") == OK)
	assert(get_viewport().get_texture().get_image().save_png(output_file) == OK)
	get_tree().quit()
