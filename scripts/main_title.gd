extends Control

@onready var play_button: Button = $HBoxContainer/VBoxContainer/PlayButton
@onready var deck_button: Button = $HBoxContainer/VBoxContainer/DeckButton

func _ready() -> void:
	play_button.pressed.connect(_go_level_select)
	deck_button.pressed.connect(_go_deck_builder)

func _go_level_select() -> void:
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")

func _go_deck_builder() -> void:
	get_tree().change_scene_to_file("res://scenes/DeckBuilder.tscn")
