extends Node

signal health_changed(current_health: int, max_health: int)
signal fragment_collected(id: String)

@export var max_health: int = 3
@export var current_health: int = 3
@export var fragments_collected: Array[String] = []
@export var unlocked_abilities: Dictionary = {
	"double_jump": false,
	"counterattack": false,
}
@export var last_checkpoint: Vector2 = Vector2.ZERO
@export var checkpoint_scene: String = ""

func heal_full() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)

func take_damage(amount: int) -> void:
	current_health = max(current_health - max(amount, 0), 0)
	health_changed.emit(current_health, max_health)

func set_checkpoint(pos: Vector2, scene_path: String) -> void:
	last_checkpoint = pos
	checkpoint_scene = scene_path

func respawn() -> void:
	heal_full()
	if not checkpoint_scene.is_empty():
		get_tree().change_scene_to_file(checkpoint_scene)
