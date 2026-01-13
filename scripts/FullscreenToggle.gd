extends Node

func _ready() -> void:
	print("FullscreenToggle ready ✅")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		print("F11 pressed ✅")
		_toggle_fullscreen()

func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	print("Current mode:", mode)

	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
