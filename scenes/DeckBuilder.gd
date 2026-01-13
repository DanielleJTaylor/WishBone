extends Control
class_name DeckBuilder

const DECK_SIZE := 52

@onready var count_label: Label = $Layout/TopBar/BarRow/CountLabel
@onready var confirm_button: Button = $Layout/TopBar/BarRow/ConfirmButton

# Optional: if you have tabs/grids
@onready var all_grid: Control = $Layout/Tabs/All/Scroll/AllGrid
@onready var selected_grid: Control = $Layout/Tabs/Selected/Scroll/SelectedGrid

# Card counts coming from sliders: { "big_bark": 4, ... }
var deck_counts: Dictionary = {}

func _ready() -> void:
	_update_banner_and_validation()

func set_deck_counts(new_counts: Dictionary) -> void:
	deck_counts = new_counts.duplicate(true)
	_update_banner_and_validation()
	_refresh_selected_tab()

func _get_total_selected() -> int:
	var total := 0
	for k in deck_counts.keys():
		total += int(deck_counts[k])
	return total

func _update_banner_and_validation() -> void:
	var total := _get_total_selected()
	count_label.text = "%d / %d" % [total, DECK_SIZE]

	var ok := (total == DECK_SIZE)

	# green if ok, red if not
	count_label.add_theme_color_override(
		"font_color",
		Color(0.2, 1.0, 0.2) if ok else Color(1.0, 0.2, 0.2)
	)

	confirm_button.disabled = not ok

func _refresh_selected_tab() -> void:
	if selected_grid == null:
		return

	# Clear old items (only if you're building UI dynamically)
	for c in selected_grid.get_children():
		c.queue_free()

	# Add only cards with qty > 0
	for card_id in deck_counts.keys():
		var qty := int(deck_counts[card_id])
		if qty <= 0:
			continue

		var row := Label.new()
		row.text = "%s x%d" % [card_id, qty]
		selected_grid.add_child(row)
