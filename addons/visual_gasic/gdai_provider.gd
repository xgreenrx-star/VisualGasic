extends RefCounted
class_name GDAIProvider

func initialize(config: Dictionary) -> void:
	# Optional provider-specific initialization.
	pass

func complete(prompt: String, options: Dictionary = {}) -> String:
	return ""

func chat(messages: Array, options: Dictionary = {}) -> String:
	return ""

func embed(text: String, options: Dictionary = {}) -> Array:
	return []

func generate_image(prompt: String, options: Dictionary = {}) -> Dictionary:
	return {}
