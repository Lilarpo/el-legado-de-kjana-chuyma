class_name AncientDoor
extends StaticBody2D

signal opened

const OPEN_SFX := preload("res://assets/audio/sfx/environment/door_open.wav")

@export_range(1, 8) var required_activations := 2

@onready var collision: CollisionShape2D = $Collision
@onready var visual: Node2D = $Visual
@onready var status_label: Label = $StatusLabel

var _activated_mechanisms: Dictionary = {}
var is_open := false
var _audio: AudioStreamPlayer2D


func _ready() -> void:
	_audio = AudioStreamPlayer2D.new()
	_audio.bus = &"SFX"
	_audio.volume_db = 0.0
	_audio.stream = OPEN_SFX
	add_child(_audio)
	_update_status()


func activate_mechanism(mechanism_id: StringName) -> void:
	if is_open or _activated_mechanisms.has(mechanism_id):
		return
	_activated_mechanisms[mechanism_id] = true
	_update_status()
	if _activated_mechanisms.size() >= required_activations:
		_open()


func _update_status() -> void:
	status_label.text = "Puerta Ancestral  %d/%d" % [_activated_mechanisms.size(), required_activations]


func _open() -> void:
	is_open = true
	_audio.play()
	status_label.text = "Puerta abierta"
	collision.set_deferred("disabled", true)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual, "position:y", -520.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(visual, "modulate:a", 0.25, 0.8)
	opened.emit()
