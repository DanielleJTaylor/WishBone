# res://scripts/GameManager.gd
extends Node
# (NO class_name)

signal card_discarded(card_id: String)

const MAX_DECK_SIZE: int = 12

var unlocked_cards: Array[String] = [
	"big_bark", "tuck_and_roll", "paws_forward", "intimidate", "drop_it"
]
var current_deck: Array[String] = []

# ✅ newest -> oldest
var discard_history: Array[String] = []

func get_binder_cards() -> Array[String]:
	return unlocked_cards.duplicate()

func get_current_deck() -> Array[String]:
	return current_deck.duplicate()

func get_unlocked_cards() -> Array[String]:
	return unlocked_cards.duplicate()

# ----------------------------
# Single Source of Truth: Discard
# ----------------------------
func discard_card(card_id: String) -> void:
	if card_id == "":
		return

	# ✅ newest at index 0
	discard_history.insert(0, card_id)
	emit_signal("card_discarded", card_id)

func clear_discard_history() -> void:
	discard_history.clear()

# ✅ returns newest -> oldest
func get_discard_history() -> Array[String]:
	return discard_history.duplicate()

# ------------------------------------------------------------
# Progression State
# ------------------------------------------------------------
var current_enemy_id: String = "chips"
var current_level_index: int = 1

var completed_level: Dictionary = {
	"intro": 0,
	"chips": 0,
	"raven": 0,
	"cats": 0,
	"nutso": 0,
	"toad": 0,
	"ratsy": 0,
	"one_eye": 0
}

func mark_level_completed(enemy_id: String, level: int) -> void:
	var prev := int(completed_level.get(enemy_id, 0))
	completed_level[enemy_id] = max(prev, level)

func get_highest_completed(enemy_id: String) -> int:
	return int(completed_level.get(enemy_id, 0))

func is_level_unlocked(enemy_id: String, level: int) -> bool:
	if level <= 1:
		return true
	return get_highest_completed(enemy_id) >= (level - 1)
