# res://scripts/CardDatabase.gd
extends Node
class_name CardDatabase

@export_group("Debug")
@export var debug_enabled: bool = true

var _card_scene: PackedScene = null

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

# ✅ pool filters
func get_player_card_ids() -> Array[String]:
	return get_ids_by_pool("player")

func get_enemy_card_ids() -> Array[String]:
	return get_ids_by_pool("enemy")

func get_ids_by_pool(pool: String) -> Array[String]:
	pool = pool.to_lower()
	var out: Array[String] = []
	for id in _ordered_ids:
		var d: Dictionary = _cards[id] as Dictionary
		var p := String(d.get("pool", "")).to_lower()

		if p == "":
			var owner := String(d.get("owner", "")).to_lower()
			p = "player" if owner == "hiro" else "enemy"

		if p == pool or p == "both":
			out.append(id)
	return out

# ✅ Player draw pool ONLY (Hiro)
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

	return get_ids_by_owner("hiro")

# ✅ Enemy helper
func get_enemy_deck_ids(enemy_id: String, level: int) -> Array[String]:
	enemy_id = enemy_id.to_lower()
	match enemy_id:
		"chips":
			return ChipsCardDatabase.get_deck_ids(level)
		_:
			return get_ids_by_owner(enemy_id)

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

	c.name = "Card_%s" % card_id
	(c as Node).set_meta("card_id", card_id)

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

	if not d.has("owner") or String(d.get("owner", "")).strip_edges() == "":
		d["owner"] = "hiro"

	if not d.has("pool") or String(d.get("pool", "")).strip_edges() == "":
		var o := String(d.get("owner", "")).to_lower()
		d["pool"] = "player" if o == "hiro" else "enemy"

	if not d.has("effect") or not (d["effect"] is Dictionary):
		d["effect"] = {}

	var eff: Dictionary = d["effect"] as Dictionary

	if String(eff.get("kind", "")) == "":
		if String(eff.get("type", "")) != "":
			eff["kind"] = String(eff.get("type", ""))
		elif String(eff.get("action", "")) != "":
			eff["kind"] = String(eff.get("action", ""))

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

	# Hiro (player pool)
	_merge_cards_from_dict(HiroCardDatabase.get_card_defs(), "hiro", "player")

	# Enemies (enemy pool)
	_merge_cards_from_dict(ChipsCardDatabase.get_card_defs(), "chips", "enemy")

	_dbg("Built ALL cards: %d" % _ordered_ids.size())

func _merge_cards_from_dict(defs: Dictionary, default_owner: String, default_pool: String) -> void:
	default_owner = default_owner.to_lower()
	default_pool = default_pool.to_lower()

	for raw_id in defs.keys():
		var id := String(raw_id)

		if _cards.has(id):
			_dbg("merge: skipping duplicate id '%s'" % id)
			continue

		var d := (defs[raw_id] as Dictionary).duplicate(true)

		if not d.has("owner") or String(d.get("owner", "")).strip_edges() == "":
			d["owner"] = default_owner

		if not d.has("pool") or String(d.get("pool", "")).strip_edges() == "":
			d["pool"] = default_pool

		_normalize_card(d)
		_cards[id] = d
		_ordered_ids.append(id)
