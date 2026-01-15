# res://scripts/DeckPersistence.gd
extends RefCounted
class_name DeckPersistence

const FILE_PATH := "user://decks.json"

func _load_all() -> Dictionary:
	if not FileAccess.file_exists(FILE_PATH):
		return {}

	var f := FileAccess.open(FILE_PATH, FileAccess.READ)
	if f == null:
		return {}

	var text := f.get_as_text()
	f.close()

	if text.strip_edges() == "":
		return {}

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}

	return parsed as Dictionary

func _save_all(data: Dictionary) -> void:
	var f := FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("DeckPersistence: cannot write %s" % FILE_PATH)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

func list_decks() -> Array[String]:
	var d := _load_all()
	var out: Array[String] = []
	for k in d.keys():
		out.append(String(k))
	out.sort()
	return out

func save_deck(name: String, model: DeckModel) -> void:
	name = name.strip_edges()
	if name == "":
		name = "Deck_%d" % int(Time.get_unix_time_from_system())

	var all := _load_all()
	all[name] = model.to_deck_array()
	_save_all(all)

func load_deck(name: String) -> Array[String]:
	var all := _load_all()
	if not all.has(name):
		return []
	var v = all[name]
	if v is Array:
		var out: Array[String] = []
		for x in v:
			out.append(String(x))
		return out
	return []
