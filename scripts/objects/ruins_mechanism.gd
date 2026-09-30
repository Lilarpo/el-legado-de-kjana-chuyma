class_name RuinsMechanism
extends Area2D

signal activated(mechanism_id: StringName)

const OFF_REGION := Rect2(32, 640, 32, 32)
const ON_REGION := Rect2(0, 672, 32, 32)
const ACTIVATE_SFX := preload("res://assets/audio/sfx/environment/mechanism_activate.wav")
@export var mechanism_id: StringName = &"Mechanism"

@onready var prompt_label: Label = $PromptLabel
@onready var visual: Sprite2D = $Visual

var is_activated := false
var _player_nearby: Node2D
var _audio: AudioStreamPlayer2D


func _ready() -> void:
	_audio = AudioStreamPlayer2D.new()
	_audio.bus = &"SFX"
	_audio.volume_db = -1.0
	_audio.stream = ACTIVATE_SFX
	add_child(_audio)
	prompt_label.hide()
	visual.region_rect = OFF_REGION
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if is_activated or _player_nearby == null:
		return
	if event.is_action_pressed("interact"):
		activate()
		get_viewport().set_input_as_handled()


func activate() -> void:
	if is_activated:
		return
	is_activated = true
	prompt_label.text = "Mecanismo activado"
	prompt_label.show()
	visual.region_rect = ON_REGION
	visual.modulate = Color(0.5, 1.0, 0.94, 1.0)
	_play_activation_feedback()
	_audio.play()
	activated.emit(mechanism_id)


func _play_activation_feedback() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "modulate", Color(0.88, 1.0, 0.96, 1.0), 0.1)
	tween.tween_property(visual, "modulate", Color(0.5, 1.0, 0.94, 1.0), 0.18)


func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return
	_player_nearby = body
	prompt_label.text = ("Activar" if _mobile_controls_active() else "Activar (E)") if not is_activated else "Mecanismo activado"
	prompt_label.show()


func _on_body_exited(body: Node2D) -> void:
	if body != _player_nearby:
		return
	_player_nearby = null
	prompt_label.hide()


func is_player_in_interaction_range(player: Node2D) -> bool:
	return _player_nearby == player and not is_activated


func _mobile_controls_active() -> bool:
	var controls := get_tree().get_first_node_in_group("mobile_controls")
	return controls != null and controls.root.visible
