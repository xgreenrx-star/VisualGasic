extends SceneTree
## Headless Narcea web reference tests (Phase 0 + Phase 2 + reference offer catalog).

const WebFetch := preload("res://addons/visual_gasic/vg_ai_web_fetch.gd")
const GameRefs := preload("res://addons/visual_gasic/vg_ai_game_references.gd")
const Catalog := preload("res://addons/visual_gasic/vg_ai_reference_catalog.gd")
const ProjectSynth := preload("res://addons/visual_gasic/vg_ai_project_synth.gd")
const Narcea := preload("res://addons/visual_gasic/vg_ai_narcea.gd")
const AIHelp := preload("res://addons/visual_gasic/vg_ai_help.gd")

var _failed := 0
var _passed := 0


func _initialize() -> void:
	print("=== Narcea Web Reference (offline) ===")
	_test_html_to_text()
	_test_parse_https_url()
	_test_extract_urls()
	_test_ssrf_blocks()
	_test_game_reference_match()
	_test_catalog_godot_genres()
	_test_catalog_best_offer()
	_test_narcea_web_references_block()
	_test_web_block_relaxation()
	_test_should_offer_reference()
	_test_platformer_canvas_prompt()
	_test_platformer_catalog_priority()
	_finish()


func _test_catalog_godot_genres() -> void:
	print("")
	print("--- reference catalog v2 ---")
	var entries: Array = Catalog.load_entries()
	_expect("catalog has entries", entries.size() >= 15, str(entries.size()))
	var plat: Array = Catalog.match_prompt("build a 2d platformer with double jump", 2)
	_expect("matches platformer", plat.size() >= 1)
	if plat.size() >= 1:
		_expect("platformer is godot docs", str(plat[0].get("source", "")) == "godot_docs")
	var fps: Array = Catalog.match_prompt("make a 3d fps game", 1)
	_expect("matches 3d fps", fps.size() == 1)
	_expect("fps url is godot", str(fps[0].get("url", "")).find("godotengine.org") >= 0)


func _test_catalog_best_offer() -> void:
	print("")
	print("--- best_offer priority ---")
	var frog: Dictionary = Catalog.best_offer("Make a Frogger clone")
	_expect("frogger primary", str(frog.get("primary", {}).get("id", "")) == "frogger")
	var mixed: Dictionary = Catalog.best_offer("2d platformer asteroids hybrid")
	_expect("mixed has primary", not mixed.get("primary", {}).is_empty())


func _test_platformer_canvas_prompt() -> void:
	print("")
	print("--- platformer canvas prompt extra ---")
	var user_prompt := (
		"Let's make a 2d platformer. Use the wasd and arrow keys for movement "
		+ "and the spacebar for jump. The main character should have a blue hat."
	)
	_expect("detects canvas platformer", ProjectSynth.prompt_is_canvas_platformer(user_prompt))
	var extra := ProjectSynth.pure_2d_game_prompt_extra(user_prompt)
	_expect("warns Screen.Width", extra.find("Screen.Width") >= 0 or extra.find("Screen.Height") >= 0)
	_expect("requires fixed playfield", extra.find("800") >= 0 and extra.find("600") >= 0)
	_expect("requires AABB", extra.to_lower().find("aabb") >= 0)
	_expect("requires floor spawn", extra.to_lower().find("floor") >= 0)


func _test_platformer_catalog_priority() -> void:
	print("")
	print("--- platformer catalog priority ---")
	var user_prompt := (
		"Let's make a 2d platformer with wasd and a blue hat using basic shapes"
	)
	var offer: Dictionary = Catalog.best_offer(user_prompt)
	var primary: Dictionary = offer.get("primary", {})
	_expect("canvas platformer wins", str(primary.get("id", "")) == "vg_canvas_platformer")
	var plat: Array = Catalog.match_prompt("build a 2d platformer with double jump", 2)
	if plat.size() >= 1:
		_expect("platformer url is tutorial", str(plat[0].get("url", "")).find("first_2d_game") >= 0)


func _test_should_offer_reference() -> void:
	print("")
	print("--- should_offer_reference ---")
	var panel: Node = AIHelp.new()
	panel.set("_web_references", [])
	panel.set("_agent_continuation", false)
	panel.set("_last_send_was_desc_mode", false)
	_expect("offers for build+game", panel._should_offer_reference("Make a Frogger clone", false))
	_expect("skips plain chat", not panel._should_offer_reference("explain ByRef", false))
	panel.free()


func _test_html_to_text() -> void:
	print("")
	print("--- html_to_text ---")
	var html := "<html><head><title>Pac-Man</title></head><body><h1>Pac-Man</h1><p>Eat dots.</p></body></html>"
	var text := WebFetch.html_to_text(html)
	_expect("strips tags", text.find("<") < 0)
	_expect("keeps content", text.to_lower().find("pac-man") >= 0)
	_expect("keeps dots", text.find("Eat dots") >= 0)


func _test_parse_https_url() -> void:
	print("")
	print("--- parse_https_url ---")
	var p: Dictionary = WebFetch.parse_https_url("https://en.wikipedia.org/wiki/Pac-Man")
	_expect("wiki host", str(p.get("host", "")) == "en.wikipedia.org")
	_expect("wiki path", str(p.get("path", "")).find("Pac-Man") >= 0)
	_expect("http blocked", WebFetch.parse_https_url("http://example.com").is_empty())
	_expect("bare host normalized", not WebFetch.parse_https_url("example.com/foo").is_empty())


func _test_extract_urls() -> void:
	print("")
	print("--- extract_https_urls ---")
	var urls: Array[String] = WebFetch.extract_https_urls(
		"See https://en.wikipedia.org/wiki/Joust_(video_game) and https://example.com/a.b")
	_expect("finds two urls", urls.size() == 2)
	_expect("first is joust", urls[0].find("Joust") >= 0)


func _test_ssrf_blocks() -> void:
	print("")
	print("--- SSRF host blocklist ---")
	var r_local: Dictionary = WebFetch.fetch_url("https://127.0.0.1/secret")
	_expect("blocks localhost", not r_local.get("ok", true))
	var r_priv: Dictionary = WebFetch.fetch_url("https://192.168.1.1/admin")
	_expect("blocks RFC1918", not r_priv.get("ok", true))


func _test_game_reference_match() -> void:
	print("")
	print("--- game reference chips ---")
	var hits: Array = GameRefs.match_prompt("Make a Pac-Man clone with ghosts", 2)
	_expect("matches pacman", hits.size() >= 1)
	if hits.size() >= 1:
		_expect("pacman label", str(hits[0].get("label", "")) == "Pac-Man")
	var joust: Array = GameRefs.match_prompt("build joust", 1)
	_expect("matches joust", joust.size() == 1)
	var none: Array = GameRefs.match_prompt("hello world calculator", 1)
	_expect("no false positive", none.is_empty())


func _test_narcea_web_references_block() -> void:
	print("")
	print("--- Narcea web reference context ---")
	var narcea = Narcea.new()
	narcea.set_web_references([{
		"url": "https://en.wikipedia.org/wiki/Pac-Man",
		"title": "Pac-Man",
		"text": "Pac-Man is a maze action game. Eat pellets and avoid ghosts.",
	}])
	var ctx: String = narcea.build_context_block(null)
	_expect("context includes WEB REFERENCE", ctx.find("WEB REFERENCE") >= 0)
	_expect("context includes pac-man text", ctx.find("maze action") >= 0)


func _test_web_block_relaxation() -> void:
	print("")
	print("--- web block relaxation ---")
	var panel: Node = AIHelp.new()
	panel.set("_web_references", [{
		"url": "https://en.wikipedia.org/wiki/Pac-Man",
		"title": "Pac-Man",
		"text": "reference body",
	}])
	var hardened: String = panel._build_hardened_prompt("Make Pac-Man", "project")
	_expect("hardened uses attached reference note", hardened.find("User-attached web reference") >= 0)
	_expect("hardened skips cannot browse", hardened.find("NOT available unless") < 0)
	panel.free()


func _expect(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		_passed += 1
		print("  PASS  %s" % label)
	else:
		_failed += 1
		var msg := "  FAIL  %s" % label
		if not detail.is_empty():
			msg += " — %s" % detail
		push_error(msg)
		print(msg)


func _finish() -> void:
	print("")
	print("=== Results: %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
