# res://scripts/CardLibrary.gd
extends RefCounted
class_name CardLibrary

var _db: CardDatabase = null
var _unlocked: Dictionary = {}  # set id->true
var _all_ids: Array[String] = []

# IMPORTANT: RefCounted cannot call get_node_or_null.
# Pass GameManager in setup.
var _gm: Node = null

func setup(db: CardDatabase, gm: Node) -> void:
	_db = db
	_gm = gm
	_reload()

func _reload() -> void:
	_all_ids.clear()
	_unlocked.clear()

	# All ids
	if _db != null:
		_all_ids = _db.get_all_ids()
	for i in range(_all_ids.size()):
		_all_ids[i] = String(_all_ids[i])

	# Unlocked ids from GameManager
	if _gm != null and _gm.has_method("get_unlocked_cards"):
		for id in _gm.call("get_unlocked_cards"):
			_unlocked[String(id)] = true
	elif _gm != null and _gm.has_variable("unlocked_cards"):
		var arr = _gm.get("unlocked_cards")
		if arr is Array:
			for id2 in arr:
				_unlocked[String(id2)] = true

	# ✅ unlocked-first ordering
	var unlocked_ids: Array[String] = []
	var locked_ids: Array[String] = []
	for id3 in _all_ids:
		if is_unlocked(id3):
			unlocked_ids.append(id3)
		else:
			locked_ids.append(id3)

	unlocked_ids.sort()
	locked_ids.sort()
	_all_ids = unlocked_ids + locked_ids

func get_all_ids() -> Array[String]:
	return _all_ids.duplicate()

func is_unlocked(id: String) -> bool:
	return _unlocked.has(id)

func get_data(id: String) -> Dictionary:
	if _db == null:
		return {"id": id, "name": id, "type": "", "rank": 0, "desc": ""}
	var d := _db.get_card_data(id)
	if d.is_empty():
		return {"id": id, "name": id, "type": "", "rank": 0, "desc": ""}
	return d
