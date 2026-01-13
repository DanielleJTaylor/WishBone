# res://scripts/CardDatabase.gd
extends Node
class_name CardDatabase

# CardDatabase = ALL cards that exist in the game (player + enemies).
# GameManager decides what the player can draw (deck/unlocked).
# Enemy decks are chosen by enemy-specific database helpers (ex: ChipsCardDatabase).

@export_group("Debug")
@export var debug_enabled: bool = true

# CardView PackedScene (BattleUI calls set_card_scene)
var _card_scene: PackedScene = null

# Internal storage
var _cards: Dictionary = {}          # id -> Dictionary
var _ordered_ids: Array[String] = [] # stable ordering

func _dbg(msg: String) -> void:
	if debug_enabled:
		print("[CardDatabase] ", msg)

func _ready() -> void:
	_build_all_cards()

func set_card_scene(scene: PackedScene) -> void:
	_card_scene = scene

# -----------------------------
# Public API
# -----------------------------
func get_all_ids() -> Array[String]:
	return _ordered_ids.duplicate()

func has_id(card_id: String) -> bool:
	return _cards.has(card_id)

func get_card_data(card_id: String) -> Dictionary:
	if not _cards.has(card_id):
		return {}
	var d: Dictionary = (_cards[card_id] as Dictionary).duplicate(true)
	_normalize_card(d)
	return d

# ✅ Player draw pool ONLY (Hiro)
# Priority:
# 1) GameManager.current_deck
# 2) GameManager.unlocked_cards
# 3) Fallback: only cards tagged owner="hiro"
func get_deck_ids() -> Array[String]:
	var gm := get_node_or_null("/root/GameManager")
	if gm != null:
		if gm.has_method("get_current_deck"):
			var deck := gm.call("get_current_deck")
			if deck is Array and not (deck as Array).is_empty():
				return (deck as Array).duplicate()
		elif gm.has_variable("current_deck"):
			var deck2 = gm.get("current_deck")
			if deck2 is Array and not (deck2 as Array).is_empty():
				return (deck2 as Array).duplicate()

		if gm.has_method("get_unlocked_cards"):
			var unlocked := gm.call("get_unlocked_cards")
			if unlocked is Array and not (unlocked as Array).is_empty():
				return (unlocked as Array).duplicate()
		elif gm.has_variable("unlocked_cards"):
			var unlocked2 = gm.get("unlocked_cards")
			if unlocked2 is Array and not (unlocked2 as Array).is_empty():
				return (unlocked2 as Array).duplicate()

	# Fallback: ONLY Hiro-owned cards
	return get_ids_by_owner("hiro")

# ✅ Enemy helper: get a deck list for a specific enemy at a specific level
# Example: get_enemy_deck_ids("chips", 1)
func get_enemy_deck_ids(enemy_id: String, level: int) -> Array[String]:
	enemy_id = enemy_id.to_lower()

	match enemy_id:
		"chips":
			return ChipsCardDatabase.get_deck_ids(level)
		# Add more later:
		# "raven":
		#     return RavenCardDatabase.get_deck_ids(level)
		_:
			# Fallback: any cards tagged owner=enemy_id
			return get_ids_by_owner(enemy_id)

# ✅ Utility: filter card ids by an "owner" field
# owner values: "hiro", "chips", "raven", etc.
func get_ids_by_owner(owner: String) -> Array[String]:
	owner = owner.to_lower()
	var out: Array[String] = []
	for id in _ordered_ids:
		var d: Dictionary = _cards[id] as Dictionary
		if String(d.get("owner", "")).to_lower() == owner:
			out.append(id)
	return out

func make_card_instance(card_id: String) -> Control:
	if _card_scene == null:
		push_error("CardDatabase: _card_scene is null. Did BattleUI call set_card_scene?")
		return null
	if not _cards.has(card_id):
		_dbg("make_card_instance: unknown id '%s'" % card_id)
		return null

	var inst := _card_scene.instantiate()
	var c := inst as Control
	if c == null:
		return null

	# Helpful name in the scene tree
	c.name = "Card_%s" % card_id

	# Store card id meta for quick debugging
	(c as Node).set_meta("card_id", card_id)

	# IMPORTANT:
	# Apply AFTER node enters tree / ready — avoids “labels null” issues.
	var data := get_card_data(card_id)
	if c.has_method("set_from_data"):
		c.call_deferred("set_from_data", data)
	elif c.has_method("set_data"):
		c.call_deferred("set_data", data)

	return c

# -----------------------------
# Normalize cards
# -----------------------------
func _normalize_card(d: Dictionary) -> void:
	if not d.has("id"):
		d["id"] = ""
	if not d.has("name"):
		d["name"] = ""
	if not d.has("desc"):
		d["desc"] = ""
	if not d.has("type"):
		d["type"] = ""

	# ✅ Owner tag used for "Hiro only draws Hiro cards"
	# If missing, default to "hiro" (safe for your current 5 Hiro cards)
	if not d.has("owner"):
		d["owner"] = "hiro"

	if not d.has("effect") or not (d["effect"] is Dictionary):
		d["effect"] = {}
	var eff: Dictionary = d["effect"] as Dictionary

	# Normalize effect.kind ONLY from effect legacy keys (never from card.type)
	if String(eff.get("kind", "")) == "":
		if String(eff.get("type", "")) != "":
			eff["kind"] = String(eff.get("type", ""))
		elif String(eff.get("action", "")) != "":
			eff["kind"] = String(eff.get("action", ""))

	# Normalize common int fields
	for k in ["amount", "delta", "duration", "discard_count", "draw_count", "rank"]:
		if eff.has(k):
			eff[k] = int(eff[k])

	d["effect"] = eff

# -----------------------------
# Build ALL cards
# -----------------------------
func _build_all_cards() -> void:
	_cards.clear()
	_ordered_ids.clear()

	# -----------------------------
	# Hiro Cards (owner="hiro")
	# -----------------------------
	_add_card({
		"id": "big_bark",
		"owner": "hiro",
		"name": "Big Bark",
		"type": "ATTACK",
		"rank": 1,
		"desc": "Deal 6 damage.\n(Knocks the enemy back if HP hits 0!)",
		"art_path": "res://assets/art/cards/big_bark.png",
		"effect": {"kind": "damage", "amount": 6}
	})

	_add_card({
		"id": "tuck_and_roll",
		"owner": "hiro",
		"name": "Tuck & Roll",
		"type": "DEFENSE",
		"rank": 1,
		"desc": "Gain 4 Shield.\n(Shield absorbs damage before your HP is touched.)",
		"art_path": "res://assets/art/cards/tuck_roll.png",
		"effect": {"kind": "shield", "amount": 4}
	})

	_add_card({
		"id": "paws_forward",
		"owner": "hiro",
		"name": "Paws Forward",
		"type": "MOVEMENT",
		"rank": 1,
		"desc": "Move Hiro +1.\n(Cannot pass the enemy.)",
		"art_path": "res://assets/art/cards/paws_forward.png",
		"effect": {"kind": "move", "who": "hiro", "delta": 1}
	})

	_add_card({
		"id": "intimidate",
		"owner": "hiro",
		"name": "Intimidate",
		"type": "CONDITION",
		"rank": 1,
		"desc": "Enemy deals -2 damage on their next 2 attacks.",
		"art_path": "res://assets/art/cards/intimidate.png",
		"effect": {"kind": "status", "target": "enemy", "status_id": "weaken", "amount": 2, "duration": 2}
	})

	_add_card({
		"id": "drop_it",
		"owner": "hiro",
		"name": "Drop It!",
		"type": "HAND",
		"rank": 0,
		"desc": "FREE: Discard 1 card to Draw 1 card.\n(Does not use a turn!)",
		"art_path": "res://assets/art/cards/mulligan.png",
		"effect": {"kind": "hand_mulligan", "free": true, "discard_count": 1, "draw_count": 1}
	})

	# -----------------------------
	# Enemy Cards (merge from helpers)
	# -----------------------------
	# Chips cards become part of the global DB,
	# but Hiro will NOT draw them because get_deck_ids() filters to owner="hiro"
	_merge_cards_from_dict(ChipsCardDatabase.get_card_defs(), "chips")

	_dbg("Built ALL cards: %d" % _ordered_ids.size())

func _add_card(data: Dictionary) -> void:
	if not data.has("id"):
		return
	var id := String(data["id"])
	var d := data.duplicate(true)
	_normalize_card(d)
	_cards[id] = d
	_ordered_ids.append(id)

# Merge cards from a dictionary, stamping owner if missing/blank
func _merge_cards_from_dict(defs: Dictionary, default_owner: String) -> void:
	default_owner = default_owner.to_lower()

	for raw_id in defs.keys():
		var id := String(raw_id)

		if _cards.has(id):
			_dbg("merge: skipping duplicate id '%s'" % id)
			continue

		var d := (defs[raw_id] as Dictionary).duplicate(true)

		# Stamp owner so we can filter draws correctly
		if not d.has("owner") or String(d.get("owner", "")).strip_edges() == "":
			d["owner"] = default_owner

		_normalize_card(d)
		_cards[id] = d
		_ordered_ids.append(id)
