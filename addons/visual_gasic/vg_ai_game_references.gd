extends RefCounted
class_name VgAiGameReferences
## Back-compat alias — use VgAiReferenceCatalog for new code.

const Catalog = preload("res://addons/visual_gasic/vg_ai_reference_catalog.gd")


static func catalog_path() -> String:
	return Catalog.catalog_path()


static func load_catalog() -> Array:
	return Catalog.load_entries()


static func match_prompt(prompt: String, max_hits: int = 3) -> Array:
	return Catalog.match_prompt(prompt, max_hits)
