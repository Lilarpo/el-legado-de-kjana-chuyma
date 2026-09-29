class_name Altar
extends Area2D

const RESTORED_MESSAGE_DURATION := 2.0
const INACTIVE_REGION := Rect2(16, 64, 16, 32)
const ACTIVE_REGION := Rect2(16, 32, 16, 32)
const ACTIVATION_FRAME_TIME := 0.08
const RIPPLE_FRAME_TIME := 0.055
const ACTIVATE_SFX := preload("res://assets/audio/sfx/environment/shrine_activate.wav")

@onready var prompt_label: Label = $PromptLabel
@onready var shrine_sprite: Sprite2D = $Sprite
@onready var active_aura: Polygon2D = $ActiveAura
@onready var activation_vfx: Sprite2D = $ActivationVFX
@onready var ripple_vfx: Sprite2D = $RippleVFX

var _player_nearby: Node2D
var _message_time_left := 0.0
var _is_active := false
var _activation_elapsed := -1.0
var _ripple_elapsed := -1.0
var _audio: AudioStreamPlayer2D


func _ready() -> void:
	_audio = AudioStreamPlayer2D.new()
	_audio.bus = &"SFX"
	_audio.volume_db = 3.0
	_audio.stream = ACTIVATE_SFX
	add_child(_audio)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt_label.visible = false
	_is_active = _matches_saved_checkpoint()
	_apply_visual_state()


func _process(delta: float) -> void:
	_update_activation_vfx(delta)
	_update_active_aura()

	if _message_time_left > 0.0:
		_message_time_left = maxf(_message_time_left - delta, 0.0)
		if _message_time_left == 0.0:
			_update_prompt()
		return

	if _player_nearby != null and Input.is_action_just_pressed("interact"):
		_rest()


func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return
	_player_nearby = body
	_update_prompt()


func _on_body_exited(body: Node2D) -> void:
	if body != _player_nearby:
		return
	_player_nearby = null
	prompt_label.visible = false


func _rest() -> void:
	var first_activation := not _is_active
	GameState.heal_full()
	GameState.set_checkpoint(global_position, get_tree().current_scene.scene_file_path, str(get_tree().current_scene.get_path_to(self)))
	if _player_nearby != null:
		_player_nearby.max_health = GameState.max_health
		_player_nearby.current_health = GameState.current_health
		_player_nearby.health_changed.emit()
	GameState.save_at_checkpoint()
	if first_activation:
		_is_active = true
		_apply_visual_state()
		_play_activation_vfx()
		_audio.play()
	prompt_label.text = "Salud restaurada"
	prompt_label.visible = true
	_message_time_left = RESTORED_MESSAGE_DURATION


func _matches_saved_checkpoint() -> bool:
	var current_scene := get_tree().current_scene
	if current_scene == null or GameState.checkpoint_scene != current_scene.scene_file_path:
		return false
	return GameState.last_checkpoint.distance_to(global_position) <= 2.0


func _apply_visual_state() -> void:
	shrine_sprite.region_rect = ACTIVE_REGION if _is_active else INACTIVE_REGION
	shrine_sprite.position.y = -16.0
	shrine_sprite.modulate = Color.WHITE if _is_active else Color(0.62, 0.66, 0.7, 1.0)
	active_aura.visible = _is_active


func _play_activation_vfx() -> void:
	_activation_elapsed = 0.0
	_ripple_elapsed = 0.0
	activation_vfx.frame = 0
	ripple_vfx.frame = 0
	activation_vfx.show()
	ripple_vfx.show()


func _update_activation_vfx(delta: float) -> void:
	if _activation_elapsed >= 0.0:
		_activation_elapsed += delta
		var activation_frame := int(_activation_elapsed / ACTIVATION_FRAME_TIME)
		if activation_frame >= activation_vfx.hframes:
			activation_vfx.hide()
			_activation_elapsed = -1.0
		else:
			activation_vfx.frame = activation_frame

	if _ripple_elapsed >= 0.0:
		_ripple_elapsed += delta
		var ripple_frame := int(_ripple_elapsed / RIPPLE_FRAME_TIME)
		if ripple_frame >= ripple_vfx.hframes:
			ripple_vfx.hide()
			_ripple_elapsed = -1.0
		else:
			ripple_vfx.frame = ripple_frame


func _update_active_aura() -> void:
	if not _is_active:
		return
	var pulse := 0.15 + (sin(Time.get_ticks_msec() * 0.0035) + 1.0) * 0.035
	active_aura.modulate.a = pulse


func _update_prompt() -> void:
	prompt_label.text = "Descansar (E)"
	prompt_label.visible = _player_nearby != null
