extends Node

func _ready() -> void:
	# Example GDAI initialization and usage.
	GDAI.initialize({
		"enabled": true,
		"provider": "openai",
		"api_key": "YOUR_API_KEY_HERE",
		"endpoint": "https://api.openai.com/v1",
		"model": "gpt-4.1-mini",
		"timeout_ms": 15000,
	})

	if not GDAI.is_enabled():
		print("GDAI is disabled or not configured.")
		return

	# Use async `await` to get the result.
	var result = await GDAI.complete("Write a one-sentence game title for a neon cyberpunk arcade shooter.")
	print("GDAI complete result: %s" % result)

	var chat_response = await GDAI.chat([
		{"role": "system", "content": "You are a helpful game-writing assistant."},
		{"role": "user", "content": "Generate a short intro line for an arcade boss."},
	])
	print("GDAI chat response: %s" % chat_response)

	var embedding = await GDAI.embed("A glowing blue screen in a futuristic arcade.")
	print("Embedding length: %d" % embedding.size())

	var image_data = await GDAI.generate_image("Pixel art glowing blue screen arcade logo", {"size": "512x512"})
	print("Image response keys: %s" % image_data.keys())
