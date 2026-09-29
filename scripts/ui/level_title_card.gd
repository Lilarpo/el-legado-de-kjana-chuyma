class_name LevelTitleCard
extends CanvasLayer

const FADE_TO_BLACK := 0.4
const TEXT_FADE := 0.35
const HOLD := 1.7
const FADE_TO_GAME := 0.5

@onready var screen: Control = $Screen
@onready var backdrop: ColorRect = $Screen/Black
@onready var titles: VBoxContainer = $Screen/Center/Titles
@onready var number_label: Label = $Screen/Center/Titles/MapNumber
@onready var name_label: Label = $Screen/Center/Titles/MapName
var _running := false


func _ready() -> void:
	backdrop.modulate.a = 0.0
	titles.modulate.a = 0.0


func present(destination: PackedScene, spawn_id: StringName, number: int, map_name: String) -> void:
	if _running:
		return
	_running = true
	var player := get_tree().current_scene.get_node_or_null("Player") as Node2D
	var was_locked := false
	if player != null:
		was_locked = player.get("input_locked")
		player.set("input_locked", true)
		player.set("velocity", Vector2.ZERO)
	get_tree().paused = true
	number_label.text = "MAPA %d" % number
	name_label.text = map_name
	MusicManager.stop_music(FADE_TO_BLACK)
	var fade := create_tween()
	fade.tween_property(backdrop, "modulate:a", 1.0, FADE_TO_BLACK)
	await fade.finished
	GameState.pending_spawn_id = spawn_id
	var result := get_tree().change_scene_to_packed(destination)
	if result != OK:
		GameState.pending_spawn_id = &""
		if is_instance_valid(player):
			player.set("input_locked", was_locked)
		get_tree().paused = false
		queue_free()
		return
	await get_tree().scene_changed
	player = get_tree().current_scene.get_node_or_null("Player") as Node2D
	if player != null:
		player.set("input_locked", true)
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			camera.reset_smoothing()
			camera.force_update_scroll()
	# The root-owned black canvas covers scene loading and the first rendered frame.
	await get_tree().process_frame
	fade = create_tween()
	fade.tween_property(titles, "modulate:a", 1.0, TEXT_FADE)
	fade.tween_interval(HOLD)
	fade.tween_property(screen, "modulate:a", 0.0, FADE_TO_GAME)
	await fade.finished
	if is_instance_valid(player):
		player.set("input_locked", false)
	get_tree().paused = false
	queue_free()


func _input(_event: InputEvent) -> void:
	if _running:
		get_viewport().set_input_as_handled()
