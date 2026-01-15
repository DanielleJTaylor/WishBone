# res://scripts/DeckModel.gd
extends RefCounted
class_name DeckModel

var _qty_by_id: Dictionary = {}
var _deck_size: int = 52

func set_deck_size(size: int) -> void:
	_deck_size = size

func ensure_ids(ids: Array[String]) -> void:
	for id in ids:
		if not _qty_by_id.has(id):
			_qty_by_id[id] = 0

func get_qty(id: String) -> int:
	return int(_qty_by_id.get(id, 0))

func set_qty(id: String, qty: int, cap: int) -> void:
	_qty_by_id[id] = clampi(qty, 0, cap)

func get_total() -> int:
	var total := 0
	for k in _qty_by_id.keys():
		total += int(_qty_by_id[k])
	return total

func is_valid() -> bool:
	return get_total() == _deck_size

func to_deck_array() -> Array[String]:
	var out: Array[String] = []
	for id in _qty_by_id.keys():
		var n := int(_qty_by_id[id])
		for i in range(n):
			out.append(String(id))
	return out

func from_deck_array(deck: Array) -> void:
	for k in _qty_by_id.keys():
		_qty_by_id[k] = 0

	for x in deck:
		var id := String(x)
		_qty_by_id[id] = int(_qty_by_id.get(id, 0)) + 1
