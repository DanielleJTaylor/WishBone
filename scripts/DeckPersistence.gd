# res://scripts/DeckPersistence.gd
extends RefCounted
class_name DeckPersistence

const SAVE_DIR := "user://decks"
const INDEX_FILE := "user://decks/index.json"

func ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func list_decks() -> Array[String]:
	ensure_dir()
	var out: Array[String] = []

	if not FileAccess.file_exists(INDEX_FILE):
		return out

	var f := FileAccess.open(INDEX_FILE, FileAccess.READ)
	if f == null:
		return out
	var txt := f.get_as_text()
	f.close()

	var parsed = JSON.parse_string(txt)
	if parsed is Dictionary:
		var names = (parsed as Dictionary).get("names", [])
		if names is Array:
			for n in names:
				out.append(String(n))
	out.sort()
	return out

func save_deck(name: String, model: DeckModel) -> void:
	ensure_dir()
	name = name.strip_edges()
	if name == "":
		name = "Deck_%d" % int(Time.get_unix_time_from_system())

	# Write deck file
	var path := "%s/%s.json" % [SAVE_DIR, name]
	var payload := {
		"name": name,
		"deck": model.to_deck_array()
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(payload, "\t"))
		f.close()

	# Update index
	var names := list_decks()
	if not names.has(name):
		names.append(name)
		names.sort()
	_write_index(names)

func load_deck(name: String) -> Array[String]:
	ensure_dir()
	var path := "%s/%s.json" % [SAVE_DIR, name]
	if not FileAccess.file_exists(path):
		return []

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var txt := f.get_as_text()
	f.close()

	var parsed = JSON.parse_string(txt)
	if parsed is Dictionary:
		var deck = (parsed as Dictionary).get("deck", [])
		if deck is Array:
			var out: Array[String] = []
			for x in deck:
				out.append(String(x))
			return out
	return []

func _write_index(names: Array[String]) -> void:
	var payload := {"names": names}
	var f := FileAccess.open(INDEX_FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(payload, "\t"))
		f.close()
