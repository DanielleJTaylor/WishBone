# res://scripts/ChipsCardDatabase.gd
extends Node
class_name ChipsCardDatabase

# Enemy ID convenience (optional)
const ENEMY_ID := "chips"

# --- Chips progression ---
# Level 1: basic attacks + tiny movement
# Level 2: more movement + small shield
# Level 3: introduces "stumble" style debuff + mulligan trick

# Returns an Array[String] of card IDs for Chips at a given level.
# You can treat this as a draw pile recipe or a decklist.
static func get_deck_ids(level: int) -> Array[String]:
	level = clamp(level, 1, 3)

	match level:
		1:
			return [
				# Basic swipes + simple movement
				"chips_nibble", "chips_nibble", "chips_nibble",
				"chips_scurry", "chips_scurry",
				"chips_shove",
				"chips_snack_time"
			]
		2:
			return [
				# More movement, introduces light defense
				"chips_nibble", "chips_nibble",
				"chips_shove", "chips_shove",
				"chips_scurry", "chips_scurry", "chips_scurry",
				"chips_duck_under",
				"chips_snack_time"
			]
		_:
			return [
				# Adds stumble-style debuff + a free hand trick
				"chips_nibble", "chips_nibble",
				"chips_shove", "chips_shove",
				"chips_scurry", "chips_scurry", "chips_scurry",
				"chips_tripwire",
				"chips_duck_under",
				"chips_greasy_fingers"
			]

# Returns a Dictionary card definition (same format as your CardDatabase cards)
static func get_card_defs() -> Dictionary:
	return {
		# ---------------------------
		# ATTACKS
		# ---------------------------
		"chips_nibble": {
			"id": "chips_nibble",
			"name": "Nibble",
			"type": "ATTACK",
			"rank": 1,
			"desc": "Deal 2 damage.\nA quick bite and a quick getaway.",
			"art_path": "res://assets/art/cards/chips_nibble.png",
			"effect": {"kind": "damage", "amount": 2}
		},
		"chips_shove": {
			"id": "chips_shove",
			"name": "Shoulder Shove",
			"type": "ATTACK",
			"rank": 1,
			"desc": "Deal 3 damage.\nChips plays dirty when cornered.",
			"art_path": "res://assets/art/cards/chips_shove.png",
			"effect": {"kind": "damage", "amount": 3}
		},

		# ---------------------------
		# MOVEMENT
		# ---------------------------
		"chips_scurry": {
			"id": "chips_scurry",
			"name": "Scurry",
			"type": "MOVEMENT",
			"rank": 1,
			"desc": "Move Chips -1.\n(Tries to widen the gap.)",
			"art_path": "res://assets/art/cards/chips_scurry.png",
			"effect": {"kind": "move", "who": "enemy", "delta": -1}
		},
		"chips_snack_time": {
			"id": "chips_snack_time",
			"name": "Snack Time",
			"type": "MOVEMENT",
			"rank": 1,
			"desc": "Move Chips -2.\nHe darts toward a tasty stash.",
			"art_path": "res://assets/art/cards/chips_snack_time.png",
			"effect": {"kind": "move", "who": "enemy", "delta": -2}
		},

		# ---------------------------
		# DEFENSE
		# ---------------------------
		"chips_duck_under": {
			"id": "chips_duck_under",
			"name": "Duck Under",
			"type": "DEFENSE",
			"rank": 1,
			"desc": "Gain 3 Shield.\nChips hides behind trash cans.",
			"art_path": "res://assets/art/cards/chips_duck_under.png",
			"effect": {"kind": "shield", "amount": 3}
		},

		# ---------------------------
		# CONDITION (Stumble tutorial-ish)
		# ---------------------------
		# NOTE: This assumes your EffectEngine has a "status" system
		# and you can create a status called "stumble" or reuse "weaken".
		# If you don't have stumble yet, rename status_id to "weaken".
		"chips_tripwire": {
			"id": "chips_tripwire",
			"name": "Tripwire",
			"type": "CONDITION",
			"rank": 1,
			"desc": "Apply STUMBLE (1) for 2 turns.\nHiro’s footing gets messy.",
			"art_path": "res://assets/art/cards/chips_tripwire.png",
			"effect": {
				"kind": "status",
				"target": "hiro",
				"status_id": "stumble", # change to "weaken" if needed
				"amount": 1,
				"duration": 2
			}
		},

		# ---------------------------
		# HAND (Chips cheat)
		# ---------------------------
		# FREE: small mulligan so he feels sneaky but still tutorial-safe.
		"chips_greasy_fingers": {
			"id": "chips_greasy_fingers",
			"name": "Greasy Fingers",
			"type": "HAND",
			"rank": 0,
			"desc": "FREE: Discard 1 to Draw 1.\nChips cycles for the perfect escape.",
			"art_path": "res://assets/art/cards/chips_greasy_fingers.png",
			"effect": {
				"kind": "hand_mulligan",
				"free": true,
				"discard_count": 1,
				"draw_count": 1
			}
		},
	}

# Convenience: give CardDatabase-style data
static func has_card(card_id: String) -> bool:
	return get_card_defs().has(card_id)

static func get_card_data(card_id: String) -> Dictionary:
	var defs := get_card_defs()
	if not defs.has(card_id):
		return {}
	return (defs[card_id] as Dictionary).duplicate(true)
