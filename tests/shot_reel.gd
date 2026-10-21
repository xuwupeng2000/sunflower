extends RefCounted

const SHOT_DIR := "user://shots"

static var _steps: Array[Dictionary] = []
static var _woke := false


static func snap(host: Node, story: String, caption: String) -> void:
	if host == null:
		return
	_wake()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := host.get_viewport().get_texture().get_image()
	if image == null or image.get_width() == 0:
		return
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	var file_name := "%03d.png" % (_steps.size() + 1)
	image.save_png(SHOT_DIR.path_join(file_name))
	_steps.append({"story": story, "caption": caption, "file": file_name})
	var manifest := FileAccess.open(SHOT_DIR.path_join("steps.json"), FileAccess.WRITE)
	if manifest == null:
		return
	manifest.store_string(JSON.stringify(_steps))
	manifest.close()


static func _wake() -> void:
	if _woke or DisplayServer.get_name() == "headless":
		return
	_woke = true
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
	DisplayServer.window_set_size(Vector2i(390, 844))
