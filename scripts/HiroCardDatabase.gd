# res://scripts/HiroCardDatabase.gd
extends Node
class_name HiroCardDatabase

const OWNER := "hiro"
const POOL := "player"

# Optional convenience "recipe"
static func get_deck_ids(level: int = 1) -> Array[String]:
	# Add the healing card into the starter pool
	return [
		"big_bark",
		"tuck_and_roll",
		"paws_forward",
		"intimidate",
		"drop_it",
		"lick_wounds", # ✅ NEW Healing
	]

# card_id -> card_def
static func get_card_defs() -> Dictionary:
	return {
		"big_bark": {
			"id": "big_bark",
			"owner": OWNER,
			"pool": POOL,
			"name": "Big Bark",
			"type": "ATTACK",
			"rank": 1,
			"desc": "Deal 6 damage.\n(Knocks the enemy back if HP hits 0!)",
			"art_path": "res://assets/art/cards/big_bark.png",
			"effect": {"kind": "damage", "amount": 6}
		},

		"tuck_and_roll": {
			"id": "tuck_and_roll",
			"owner": OWNER,
			"pool": POOL,
			"name": "Tuck & Roll",
			"type": "DEFENSE",
			"rank": 1,
			"desc": "Gain 4 Shield.\n(Shield absorbs damage before your HP is touched.)",
			"art_path": "res://assets/art/cards/tuck_roll.png",
			"effect": {"kind": "shield", "amount": 4}
		},

		"paws_forward": {
			"id": "paws_forward",
			"owner": OWNER,
			"pool": POOL,
			"name": "Paws Forward",
			"type": "MOVEMENT",
			"rank": 1,
			"desc": "Move Hiro +1.\n(Cannot pass the enemy.)",
			"art_path": "res://assets/art/cards/paws_forward.png",
			"effect": {"kind": "move", "who": "hiro", "delta": 1}
		},

		"intimidate": {
			"id": "intimidate",
			"owner": OWNER,
			"pool": POOL,
			"name": "Intimidate",
			"type": "CONDITION",
			"rank": 1,
			"desc": "Enemy deals -2 damage on their next 2 attacks.",
			"art_path": "res://assets/art/cards/intimidate.png",
			"effect": {"kind": "status", "target": "enemy", "status_id": "weaken", "amount": 2, "duration": 2}
		},

		# ✅ CHANGED: Drop It now uses a turn (NOT free)
		# New behavior text:
		# "Discard up to 2, then draw to 7."
		"drop_it": {
			"id": "drop_it",
			"owner": OWNER,
			"pool": POOL,
			"name": "Drop It!",
			"type": "HAND",
			"rank": 5,
			"desc": "Discard up to 2, then draw to 7.",
			"art_path": "res://assets/art/cards/mulligan.png",
			"effect": {
				"kind": "hand_mulligan",
				"free": false,          # ✅ NOT FREE anymore
				"discard_up_to": 2,     # ✅ up to 2
				"draw_to": 7            # ✅ draw to 7
			}
		},

		# ✅ NEW Healing card added to starter pool
		# Simple + readable early-game heal
		"lick_wounds": {
			"id": "lick_wounds",
			"owner": OWNER,
			"pool": POOL,
			"name": "Lick Wounds",
			"type": "HEALING",
			"rank": 5,
			"desc": "Heal 8.",
			"art_path": "res://assets/art/cards/lick_wounds.png",
			"effect": {
				"kind": "heal",
				"amount": 8
			}
		},
	}

static func has_card(card_id: String) -> bool:
	return get_card_defs().has(card_id)

static func get_card_data(card_id: String) -> Dictionary:
	var defs := get_card_defs()
	if not defs.has(card_id):
		return {}
	return (defs[card_id] as Dictionary).duplicate(true)
