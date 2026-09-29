class_name GuardianCorruptionTrailVFX
extends Node2D

@onready var trail: Line2D = $Trail

var _finished := false


func add_ground_point(world_position: Vector2) -> void:
	if _finished:
		return
	if trail.get_point_count() > 0 and trail.get_point_position(trail.get_point_count() - 1).distance_to(world_position) < 18.0:
		return
	trail.add_point(world_position)
	while trail.get_point_count() > 28:
		trail.remove_point(0)


func finish() -> void:
	if _finished:
		return
	_finished = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)


func cancel() -> void:
	_finished = true
	queue_free()
