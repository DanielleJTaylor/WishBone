# res://scripts/DeckBuilderController.gd
extends Control
class_name DeckBuilderController

@export var card_db: CardDatabase
@export var CardItemPrefab: PackedScene # Small CardView/UI item

@onready var binder_grid: Control = %BinderGrid
@onready var deck_list: Control = %DeckList

func _ready() -> void:
	# If player has no deck yet, start with unlocked cards up to MAX
	if GameManager.current_deck.is_empty():
		for id in GameManager.unlocked_cards:
			if GameManager.current_deck.size() >= GameManager.MAX_DECK_SIZE:
				break
			GameManager.current_deck.append(id)

	refresh_ui()

func refresh_ui() -> void:
	# Clear UI
	for child in binder_grid.get_children():
		child.queue_free()
	for child in deck_list.get_children():
		child.queue_free()

	# Binder = unlocked cards NOT currently in deck
	for id in GameManager.unlocked_cards:
		if not GameManager.current_deck.has(id):
			_create_card_ui(id, binder_grid, true)

	# Deck = current deck
	for id in GameManager.current_deck:
		_create_card_ui(id, deck_list, false)

func _create_card_ui(id: String, container: Control, to_deck: bool) -> void:
	if card_db == null or CardItemPrefab == null:
		push_warning("DeckBuilderController: Missing card_db or CardItemPrefab.")
		return

	var card_node := CardItemPrefab.instantiate()
	container.add_child(card_node)

	var data: Dictionary = card_db.get_card_data(id)
	if card_node.has_method("set_from_data"):
		card_node.set_from_data(data)

	# Click to move
	if card_node is Control:
		(card_node as Control).mouse_filter = Control.MOUSE_FILTER_STOP

	card_node.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if to_deck:
				_add_to_deck(id)
			else:
				_remove_from_deck(id)
	)

func _add_to_deck(id: String) -> void:
	if GameManager.current_deck.size() >= GameManager.MAX_DECK_SIZE:
		return
	if not GameManager.unlocked_cards.has(id):
		return
	if GameManager.current_deck.has(id):
		return

	GameManager.current_deck.append(id)
	refresh_ui()

func _remove_from_deck(id: String) -> void:
	GameManager.current_deck.erase(id)
	refresh_ui()
