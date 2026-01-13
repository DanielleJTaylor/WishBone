extends Control

@onready var play_button: Button = $HBoxContainer/VBoxContainer/PlayButton

func _ready() -> void:
	play_button.pressed.connect(_go_level_select)

func _go_level_select() -> void:
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")
