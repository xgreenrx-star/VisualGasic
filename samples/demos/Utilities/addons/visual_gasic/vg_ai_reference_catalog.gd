extends RefCounted
class_name VgAiReferenceCatalog
## Curated reference URLs: classic games (Wikipedia) + Godot doc pages (genres/templates).


static func catalog_path() -> String:
	return "res://addons/visual_gasic/data/reference_catalog.json"


static func legacy_catalog_path() -> String:
	return "res://addons/visual_gasic/data/game_reference_urls.json"


static func load_entries() -> Array:
	var path := catalog_path()
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY:
			var ver: int = int(parsed.get("version", 1))
			if ver >= 2:
				var entries: Array = parsed.get("entries", [])
				return entries if typeof(entries) == TYPE_ARRAY else []
			var games: Array = parsed.get("games", [])
			return _legacy_games_to_entries(games)
	# Fallback: old game-only JSON.
	if FileAccess.file_exists(legacy_catalog_path()):
		var leg = JSON.parse_string(FileAccess.get_file_as_string(legacy_catalog_path()))
		if typeof(leg) == TYPE_DICTIONARY:
			return _legacy_games_to_entries(leg.get("games", []))
	return []


static func _legacy_games_to_entries(games: Array) -> Array:
	var out: Array = []
	for g in games:
		if typeof(g) != TYPE_DICTIONARY:
			continue
		out.append({
			"id": str(g.get("id", "")),
			"kind": "classic_game",
			"source": "wikipedia",
			"label": str(g.get("label", "")),
			"keywords": g.get("keywords", []),
			"url": str(g.get("url", "")),
			"priority": int(g.get("priority", 20)),
		})
	return out


## Return matching entries sorted by match strength then priority (best first).
static func match_prompt(prompt: String, max_hits: int = 3) -> Array:
	var low := prompt.to_lower()
	var scored: Array = []
	for entry in load_entries():
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var best_kw_len := 0
		for kw in entry.get("keywords", []):
			var k := str(kw).to_lower().strip_edges()
			if k.is_empty():
				continue
			if low.find(k) >= 0:
				best_kw_len = maxi(best_kw_len, k.length())
		if best_kw_len <= 0:
			continue
		var item: Dictionary = entry.duplicate()
		item["_kw_len"] = best_kw_len
		scored.append(item)
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("_kw_len", 0)) != int(b.get("_kw_len", 0)):
			return int(a.get("_kw_len", 0)) > int(b.get("_kw_len", 0))
		if int(a.get("priority", 0)) != int(b.get("priority", 0)):
			return int(a.get("priority", 0)) > int(b.get("priority", 0))
		return str(a.get("label", "")) < str(b.get("label", ""))
	)
	var out: Array = []
	for i in range(mini(max_hits, scored.size())):
		var e: Dictionary = scored[i]
		e.erase("_kw_len")
		out.append(e)
	return out


static func best_offer(prompt: String) -> Dictionary:
	var hits := match_prompt(prompt, 4)
	if hits.is_empty():
		return {}
	var primary: Dictionary = hits[0]
	var alternates: Array = []
	for i in range(1, hits.size()):
		var alt: Dictionary = hits[i]
		if str(alt.get("kind", "")) != str(primary.get("kind", "")):
			alternates.append(alt)
		elif alternates.size() < 1:
			alternates.append(alt)
	return {"primary": primary, "alternates": alternates}


static func source_blurb(source: String) -> String:
	match str(source):
		"godot_docs":
			return "Godot documentation"
		"wikipedia":
			return "Wikipedia"
		_:
			return "reference page"
