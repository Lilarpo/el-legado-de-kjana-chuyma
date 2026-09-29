class_name KillZone
extends Area2D

@export var initial_respawn_position := Vector2.ZERO

var _bodies_respawning: Dictionary = {}


func _ready() -> void:
	add_to_group("kill_zones")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return

	var body_id := body.get_instance_id()
	if _bodies_respawning.has(body_id):
		return

	_bodies_respawning[body_id] = true
	if body is WayraPlayer:
		body.take_damage(1, self)
	else:
		GameState.take_damage(1)
	if GameState.current_health <= 0:
		return

	var respawn_position := GameState.last_checkpoint
	if respawn_position == Vector2.ZERO:
		respawn_position = initial_respawn_position

	body.global_position = respawn_position
	if body is CharacterBody2D:
		body.velocity = Vector2.ZERO


func _on_body_exited(body: Node2D) -> void:
	_bodies_respawning.erase(body.get_instance_id())

func restore_to_snapshot() -> void:
	_bodies_respawning.clear()
