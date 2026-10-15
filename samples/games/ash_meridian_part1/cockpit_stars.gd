extends Node2D

var time := 0.0
var stars := PackedVector2Array()

func _ready() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 73219
	for i in 160:
		stars.append(Vector2(random.randf_range(0, TAU), random.randf()))

func _draw() -> void:
	for star in stars:
		var depth := fposmod(star.y + time * 0.035, 1.0)
		var angle := star.x
		var radius := 30 + depth * depth * 700
		var point := Vector2(480, 205) + Vector2(cos(angle), sin(angle)) * Vector2(radius, radius * 0.6)
		var brightness := 0.35 + depth * 0.65
		draw_circle(point, 0.6 + depth, Color(0.7 * brightness, 0.85 * brightness, brightness))
		if depth > 0.65:
			draw_line(point, point + (point - Vector2(480, 205)) * 0.012, Color(0.4, 0.65, 0.85, 0.4), 1, true)
