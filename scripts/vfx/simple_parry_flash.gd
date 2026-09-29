class_name SimpleParryFlash
extends Node2D


func _ready() -> void:
	scale = Vector2(0.75, 0.75)
	modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.035)
	tween.tween_property(self, "scale", Vector2.ONE, 0.035)
	tween.chain().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.1)
	tween.chain().tween_callback(queue_free)
