class_name LevelTransition
extends Area2D

signal transition_requested(destination_scene: PackedScene, spawn_point_id: StringName)

@export var destination_scene: PackedScene
@export var destination_spawn_id: StringName = &"DefaultSpawn"

const TITLE_CARD := preload("res://scenes/ui/LevelTitleCard.tscn")
const LEVEL_TITLES := {
	"res://scenes/levels/level02_ruinas_ancestrales.tscn": [2, "RUINAS ANCESTRALES"],
	"res://scenes/levels/level03_santuario_profundo.tscn": [3, "SANTUARIO PROFUNDO"],
}

var _transition_in_progress := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _transition_in_progress or body.name != "Player":
		return
	if destination_scene == null:
		push_warning("LevelTransition: asigna la escena destino para habilitar esta salida.")
		return

	_transition_in_progress = true
	transition_requested.emit(destination_scene, destination_spawn_id)
	_begin_transition.call_deferred()


func _begin_transition() -> void:
	var title_data: Array = LEVEL_TITLES.get(destination_scene.resource_path, [])
	if title_data.is_empty():
		GameState.pending_spawn_id = destination_spawn_id
		get_tree().change_scene_to_packed(destination_scene)
		return
	var card := TITLE_CARD.instantiate() as LevelTitleCard
	get_tree().root.add_child(card)
	card.present(destination_scene, destination_spawn_id, title_data[0], title_data[1])
