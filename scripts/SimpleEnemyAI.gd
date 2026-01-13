# res://scripts/SimpleEnemyAI.gd
extends Node
class_name SimpleEnemyAI

@export var debug_enabled: bool = true

func _dbg(msg: String) -> void:
	if debug_enabled:
		print("[EnemyAI] ", msg)

func choose_card(hand_ids: Array[String], card_db: Node, track_move: Node) -> String:
	if hand_ids.is_empty():
		return ""

	var attacks: Array[String] = []
	var valid_moves: Array[String] = []
	var others: Array[String] = []

	for id in hand_ids:
		var d: Dictionary = card_db.get_card_data(id)
		var t := String(d.get("type", ""))
		var eff: Dictionary = d.get("effect", {})

		if t == "ATTACK":
			attacks.append(id)
		elif t == "MOVEMENT":
			# Only accept movement cards if the move is possible right now
			var delta := int(eff.get("delta", 0))
			var who := String(eff.get("who", "enemy"))
			if track_move != null and track_move.has_method("can_move"):
				var ok := bool(track_move.call("can_move", who, delta))
				if ok:
					valid_moves.append(id)
				else:
					_dbg("Reject move %s (who=%s delta=%d) because can_move=false" % [id, who, delta])
			else:
				# If TrackMovement doesn't expose can_move, we assume it's NOT safe to choose movement.
				_dbg("TrackMovement missing can_move(); rejecting move card %s" % id)
		else:
			others.append(id)

	# ✅ Rule: ATTACK if available
	if not attacks.is_empty():
		return attacks.pick_random()

	# ✅ Otherwise: movement ONLY if valid space exists
	if not valid_moves.is_empty():
		return valid_moves.pick_random()

	# ✅ Otherwise: anything
	if not others.is_empty():
		return others.pick_random()

	return hand_ids.pick_random()
