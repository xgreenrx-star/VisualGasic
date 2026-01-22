extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var label: RichTextLabel = $RichTextLabel


func _on_hurt_box_was_hit(hitbox: HitBox2D) -> void:
	label.text = "[b][font_size=10][color=red][outline_size=5][outline_color=white][p align=center]{0}".format([hitbox.damage])
	animation_player.play("hurt")
	await animation_player.animation_finished
	label.text = ""
	animation_player.play("idle")
