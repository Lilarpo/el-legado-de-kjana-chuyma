class_name ProtectionPotionPickup
extends Area2D

@export var drop_id := ""
const ICON_PATH := "res://assets/sprites/items/protection_potion.png"

@onready var sprite: Sprite2D = $Sprite
var _fall_speed := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if drop_id.is_empty() or GameState.collected_potion_drop_ids.has(drop_id):
		queue_free()
		return
	var tween := create_tween().set_loops()
	tween.tween_property(sprite, "position:y", -3.0, 0.7).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "position:y", 3.0, 0.7).set_trans(Tween.TRANS_SINE)


func _physics_process(delta: float) -> void:
	# A flying enemy's drop falls onto the walkable terrain.
	if _fall_speed < 0.0:
		return
	var distance := maxf(_fall_speed * delta, 2.0)
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2.DOWN * (distance + 15.0), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position.y = minf(global_position.y + distance, hit.position.y - 15.0)
		_fall_speed = -1.0
	else:
		_fall_speed = minf(_fall_speed + 980.0 * delta, 500.0)
		global_position.y += distance


func _on_body_entered(body: Node2D) -> void:
	if not body is WayraPlayer:
		return
	if GameState.register_potion_collected(drop_id):
		queue_free()
