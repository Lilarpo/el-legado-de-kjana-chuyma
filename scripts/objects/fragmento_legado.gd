class_name FragmentoLegado
extends Area2D

@export var fragment_id: String = ""

const COLLECT_SFX := preload("res://assets/audio/sfx/pickups/legacy_fragment.wav")

@onready var sprite: Sprite2D = $Sprite
var _audio: AudioStreamPlayer2D

var _is_collected := false
var _base_sprite_scale := Vector2.ONE
var _float_tween: Tween
var _pulse_tween: Tween


func _ready() -> void:
	if not fragment_id.is_empty() and GameState.fragments_collected.has(fragment_id):
		queue_free()
		return
	_audio = AudioStreamPlayer2D.new()
	_audio.bus = &"SFX"
	_audio.volume_db = 1.0
	_audio.stream = COLLECT_SFX
	add_child(_audio)
	_base_sprite_scale = sprite.scale
	body_entered.connect(_on_body_entered)
	_start_idle_effects()


func _start_idle_effects() -> void:
	_float_tween = create_tween().set_loops()
	_float_tween.tween_property(sprite, "position:y", -4.0, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_tween.tween_property(sprite, "position:y", 4.0, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(sprite, "scale", _base_sprite_scale * 1.05, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(sprite, "scale", _base_sprite_scale, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_body_entered(body: Node2D) -> void:
	if _is_collected or body.name != "Player":
		return

	_is_collected = true
	set_deferred("monitoring", false)
	GameState.register_fragment_collected(fragment_id)
	_audio.play()
	if _float_tween != null:
		_float_tween.kill()
	if _pulse_tween != null:
		_pulse_tween.kill()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.18)
	tween.chain().tween_callback(_finish_collection)



func _finish_collection() -> void:
	sprite.hide()
	if _audio.playing:
		await _audio.finished
	queue_free()
