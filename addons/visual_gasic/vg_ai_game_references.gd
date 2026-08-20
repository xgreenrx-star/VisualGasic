extends RefCounted
class_name VgAiGameReferences
## Match user prompts to curated Wikipedia URLs (Phase 2).


static func catalog_path() -> String:
	return "res://addons/visual_gasic/data/game_reference_urls.json"


static func load_catalog() -> Array:
	var path := catalog_path()
	if not FileAccess.file_exists(path):
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	var games: Array = parsed.get("games", [])
	return games if typeof(games) == TYPE_ARRAY else []


static func match_prompt(prompt: String, max_hits: int = 3) -> Array:
	var low := prompt.to_lower()
	var hits: Array = []
	for entry in load_catalog():
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var keywords: Array = entry.get("keywords", [])
		for kw in keywords:
			var k := str(kw).to_lower().strip_edges()
			if k.is_empty():
				continue
			if low.find(k) >= 0:
				hits.append(entry.duplicate())
				break
		if hits.size() >= max_hits:
			break
	return hits
