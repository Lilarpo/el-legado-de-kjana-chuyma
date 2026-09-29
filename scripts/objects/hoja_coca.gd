class_name HojaCoca
extends Area2D

signal collected

@export var leaf_id: String = ""

const COLLECT_SFX := preload("res://assets/audio/sfx/pickups/coca_leaf.wav")

@onready var sprite: Sprite2D = $Sprite
var _audio: AudioStreamPlayer2D

var _is_collected := false
var _base_sprite_scale := Vector2.ONE
var _collect_tween: Tween


func _ready() -> void:
	_audio = AudioStreamPlayer2D.new()
	_audio.bus = &"SFX"
	_audio.volume_db = -1.0
	_audio.stream = COLLECT_SFX
	add_child(_audio)
	_base_sprite_scale = sprite.scale
	if leaf_id.is_empty():
		leaf_id = "%s_%d_%d" % [name, roundi(global_position.x), roundi(global_position.y)]
	add_to_group("hojas_coca")
	body_entered.connect(_on_body_entered)
	GameState.leaves_restored.connect(on_leaves_restored)
	if GameState.collected_leaf_ids.has(leaf_id):
		_set_collected_state()
	_start_floating()


func _start_floating() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(sprite, "position:y", -4.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "position:y", 4.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_body_entered(body: Node2D) -> void:
	if _is_collected or body.name != "Player":
		return

	_is_collected = true
	set_deferred("monitoring", false)
	GameState.collect_leaf(leaf_id)
	_audio.play()
	collected.emit()

	_collect_tween = create_tween()
	_collect_tween.set_parallel(true)
	_collect_tween.tween_property(sprite, "scale", Vector2.ZERO, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_collect_tween.tween_property(sprite, "modulate:a", 0.0, 0.18)


func on_leaves_restored(remaining_ids: Array[String]) -> void:
	if remaining_ids.has(leaf_id):
		_set_collected_state()
		return

	_is_collected = false
	if _collect_tween != null and _collect_tween.is_valid():
		_collect_tween.kill()
	visible = true
	sprite.scale = _base_sprite_scale
	sprite.modulate.a = 1.0
	set_deferred("monitoring", true)


func _set_collected_state() -> void:
	_is_collected = true
	visible = false
	set_deferred("monitoring", false)
