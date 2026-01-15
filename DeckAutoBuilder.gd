# res://scripts/DeckAutoBuilder.gd
extends RefCounted
class_name DeckAutoBuilder

const DECK_SIZE := 52
const MAX_COPIES := 4

const MIN_PCT := {
	"ATTACK": 0.22,
	"DEFENSE": 0.08,
	"HEALING": 0.10,
	"CONDITION": 0.10,
	"HAND": 0.08,
	"MOVEMENT": 0.12,
	"SPECIAL": 0.00,
}

static func build_random_deck(card_db: CardDatabase, rng: RandomNumberGenerator, allowed_ids: Array[String]) -> Array[String]:
	# allowed_ids should be "player pool" ids you want available in tutorial
	# (ex: CardDatabase.get_player_card_ids()).

	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	# Build buckets by type
	var by_type: Dictionary = {}
	for t in MIN_PCT.keys():
		by_type[t] = []

	for id in allowed_ids:
		var d := card_db.get_card_data(id)
		var t := String(d.get("type", "")).to_upper()
		if not by_type.has(t):
			continue
		(by_type[t] as Array).append(id)

	# Convert mins to counts (ceil)
	var min_counts: Dictionary = {}
	var sum_min := 0
	for t in MIN_PCT.keys():
		var n := int(ceil(DECK_SIZE * float(MIN_PCT[t])))
		min_counts[t] = n
		sum_min += n

	# Flexible pool + cap
	var flexible := DECK_SIZE - sum_min
	var max_extra_per_type := int(floor(float(flexible) / 2.0)) # "no more than half of extra into one type"

	# Build counts target = mins + flexible distributed
	var target_counts: Dictionary = {}
	for t in MIN_PCT.keys():
		target_counts[t] = int(min_counts[t])

	# Distribute flexible pool with a simple bias:
	# identity defaults: Attack + Movement get some, but never exceed max_extra_per_type per type
	var flex_left := flexible
	var preference := ["ATTACK", "MOVEMENT", "DEFENSE", "HEALING", "CONDITION", "HAND"]

	while flex_left > 0:
		for t in preference:
			if flex_left <= 0:
				break
			var extra := int(target_counts[t]) - int(min_counts[t])
			if extra >= max_extra_per_type:
				continue
			target_counts[t] = int(target_counts[t]) + 1
			flex_left -= 1

	# Now actually pick cards to satisfy target_counts with max copies rule
	var qty_by_id: Dictionary = {}
	for id in allowed_ids:
		qty_by_id[id] = 0

	var deck: Array[String] = []

	for t in target_counts.keys():
		var want := int(target_counts[t])
		var pool: Array = by_type.get(t, [])
		if pool.is_empty():
			# If you don’t have cards of a required type yet, skip (but your DB should)
			continue

		var attempts := 0
		while want > 0 and attempts < 20000:
			attempts += 1
			var pick := String(pool[rng.randi_range(0, pool.size() - 1)])
			var q := int(qty_by_id.get(pick, 0))
			if q >= MAX_COPIES:
				continue

			qty_by_id[pick] = q + 1
			deck.append(pick)
			want -= 1

	# If we somehow came up short (missing types etc), fill with ATTACK then anything
	while deck.size() < DECK_SIZE:
		var fallback_pool: Array = by_type.get("ATTACK", [])
		if fallback_pool.is_empty():
			fallback_pool = allowed_ids
		var pick2 := String(fallback_pool[rng.randi_range(0, fallback_pool.size() - 1)])
		if int(qty_by_id.get(pick2, 0)) < MAX_COPIES:
			qty_by_id[pick2] = int(qty_by_id.get(pick2, 0)) + 1
			deck.append(pick2)
		else:
			# try some other id
			var any_id := String(allowed_ids[rng.randi_range(0, allowed_ids.size() - 1)])
			if int(qty_by_id.get(any_id, 0)) < MAX_COPIES:
				qty_by_id[any_id] = int(qty_by_id.get(any_id, 0)) + 1
				deck.append(any_id)

	# Shuffle final list so it isn’t grouped by type
	deck.shuffle()
	return deck
