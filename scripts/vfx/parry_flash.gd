class_name ParryFlash
extends Node2D

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	sprite.animation_finished.connect(queue_free)
	sprite.play(&"flash")


func set_duration(duration: float) -> void:
	# Fit the same four frames to the enemy's existing windup frame/timer.
	sprite.speed_scale = (4.0 / 36.0) / maxf(duration, 0.001)
