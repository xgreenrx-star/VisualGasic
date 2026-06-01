extends Node
class_name GDAITest

const GDAI = preload("res://addons/visual_gasic/gdai.gd")

func run_tests() -> void:
	var failed = false
	print("[GDAI Test] Loading project settings...")
	var config = GDAI.load_project_settings()
	if not config.has("provider"):
		push_error("[GDAI Test] Missing provider in loaded config")
		failed = true
	else:
		print("[GDAI Test] provider=%s" % config["provider"])

	var providers = GDAI.supported_providers()
	if providers.empty():
		push_error("[GDAI Test] supported_providers returned empty list")
		failed = true
	else:
		print("[GDAI Test] supported providers: %s" % providers)

	var dummy_id = "test_dummy"
	GDAI.register_provider(dummy_id, "res://addons/visual_gasic/gdai_provider.gd", {
		"display_name": "Dummy GDAI Provider",
		"description": "Test provider registration",
		"requires_api_key": false,
		"default_endpoint": "http://localhost:8000/v1",
		"default_model": "test-model",
	})
	if not GDAI.supported_providers().has(dummy_id):
		push_error("[GDAI Test] register_provider did not add %s" % dummy_id)
		failed = true
	else:
		print("[GDAI Test] register_provider succeeded for %s" % dummy_id)

	if failed:
		print("[GDAI Test] FAILED")
	else:
		print("[GDAI Test] PASSED")
