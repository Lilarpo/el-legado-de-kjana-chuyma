class_name WayraPlayer
extends CharacterBody2D

signal died
signal health_changed
signal attack_hit(target: Node2D, damage: int)
signal parry_success(enemy: Node2D)

enum State {
	IDLE,
	RUN,
	JUMP,
	ATTACK,
	PARRY,
	HURT,
	DEAD,
}

@export var speed = 300.0
@export var acceleration = 1500.0
@export var friction = 1800.0
@export var jump_velocity = -520.0
@export var gravity_project = 1400.0
@export var max_health := 3
@export var current_health := 3

const DEFAULT_GRAVITY := 980.0
const ATTACK_DURATION := 0.4
const ATTACK_HITBOX_DURATION := 0.15
const PARRY_DURATION := 0.3
const HURT_DURATION := 0.3
const DAMAGE_FEEDBACK_DURATION := 0.15
const DAMAGE_INVULNERABILITY_DURATION := 0.7
const GUARDIAN_PARRY_CONTACT_GRACE := 0.2
const CAMERA_SHAKE_AMPLITUDE := 3.0
const FOOTSTEP_INTERVAL := 0.27
const FOOTSTEP_01 := preload("res://assets/audio/sfx/player/footstep_01.wav")
const FOOTSTEP_02 := preload("res://assets/audio/sfx/player/footstep_02.wav")
const JUMP_SFX := preload("res://assets/audio/sfx/player/jump.wav")
const LAND_SFX := preload("res://assets/audio/sfx/player/land.wav")
const ATTACK_SFX := preload("res://assets/audio/sfx/player/attack.wav")
const HIT_SFX := preload("res://assets/audio/sfx/player/hit.wav")
const PARRY_START_SFX := preload("res://assets/audio/sfx/player/parry_start.wav")
const PARRY_SUCCESS_SFX := preload("res://assets/audio/sfx/player/parry_success.wav")
const COUNTERATTACK_SFX := preload("res://assets/audio/sfx/player/counterattack.wav")
const ATTACK_PIVOT_OFFSET := Vector2(34.0, -4.0)
const PARRY_ZONE_OFFSET := Vector2(22.0, -4.0)
const ANIMATION_ORDER: Array[StringName] = [
	&"idle",
	&"walk",
	&"jump",
	&"parry",
	&"hurt",
	&"attack",
]
const ANIMATION_CONFIG := {
	&"idle": {
		"texture": preload("res://assets/sprites/characters/wayra/wayra_idle.png"),
		"frame_count": 4,
		"fps": 4.0,
		"loop": true,
	},
	&"walk": {
		"texture": preload("res://assets/sprites/characters/wayra/wayra_walk.png"),
		"frame_count": 24,
		"fps": 24.0,
		"loop": true,
	},
	&"jump": {
		"texture": preload("res://assets/sprites/characters/wayra/wayra_jump.png"),
		"frame_count": 17,
		"fps": 18.0,
		"loop": false,
	},
	&"parry": {
		"texture": preload("res://assets/sprites/characters/wayra/wayra_parry.png"),
		"frame_count": 3,
		"fps": 10.0,
		"loop": false,
	},
	&"hurt": {
		"texture": preload("res://assets/sprites/characters/wayra/wayra_hurt.png"),
		"frame_count": 7,
		"fps": 14.0,
		"loop": false,
	},
	&"attack": {
		"texture": preload("res://assets/sprites/characters/wayra/wayra_attack.png"),
		"frame_count": 8,
		"fps": 16.0,
		"loop": false,
	},
}

@onready var attack_pivot: Node2D = $AttackPivot # FIX-ATQ
@onready var hit_box: Area2D = $AttackPivot/HitBox # FIX-ATQ
@onready var parry_zone: Area2D = $ParryZone
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var camera: Camera2D = get_node_or_null("Camera2D")

var state := State.IDLE
var counterattack_ready := false
var input_locked: bool = false
var facing := 1.0 # FIX-ATQ

var _state_time_left := 0.0
var _hitbox_time_left := 0.0
var _hit_targets: Dictionary = {}
var _damage_feedback_time_left := 0.0
var _damage_invulnerability_left := 0.0
var _guardian_contact_grace_left := 0.0
var _protection_flash_tween: Tween
var _camera_rest_position := Vector2.ZERO
var _visual_one_shot_active := false
var _jumps_used := 0
var _movement_audio: AudioStreamPlayer2D
var _action_audio: AudioStreamPlayer2D
var _feedback_audio: AudioStreamPlayer2D
var _footstep_time_left := 0.0
var _next_footstep := 0
var _has_been_airborne := false


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_damage_invulnerability_left = maxf(_damage_invulnerability_left - delta, 0.0)
	_guardian_contact_grace_left = maxf(_guardian_contact_grace_left - delta, 0.0)
	var was_on_floor := is_on_floor()
	if is_on_floor():
		_jumps_used = 0
	_update_state_timers(delta)
	_handle_state_input()
	_handle_movement(delta)

	if not is_on_floor():
		var gravity: float = gravity_project if velocity.y > 0.0 else DEFAULT_GRAVITY
		velocity.y += gravity * delta

	move_and_slide()
	_update_movement_audio(delta, was_on_floor)
	_update_locomotion_state()
	_update_animation()


func _ready() -> void:
	_movement_audio = _create_audio_player("MovementAudio")
	_action_audio = _create_audio_player("ActionAudio")
	_feedback_audio = _create_audio_player("FeedbackAudio")
	_configure_animations()
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	_update_facing(facing) # FIX-ATQ
	_update_attack_direction()
	_update_parry_direction()
	if camera != null:
		_camera_rest_position = camera.position
	GameState.health_changed.connect(_sync_health)
	_sync_health(GameState.current_health, GameState.max_health)
	_update_animation()


func _process(delta: float) -> void:
	if state == State.DEAD:
		return
	sprite.modulate.r = 1.12 if counterattack_ready else 1.0
	sprite.modulate.g = 1.25 if counterattack_ready else 1.0
	sprite.modulate.b = 1.25 if counterattack_ready else 1.0
	if _damage_feedback_time_left <= 0.0:
		return

	_damage_feedback_time_left = max(_damage_feedback_time_left - delta, 0.0)
	var flash_phase := int(_damage_feedback_time_left / 0.04) % 2
	sprite.modulate.a = 0.35 if flash_phase == 0 else 1.0
	if camera != null:
		camera.position = _camera_rest_position + Vector2(sin(_damage_feedback_time_left * 180.0) * CAMERA_SHAKE_AMPLITUDE, 0.0)

	if _damage_feedback_time_left == 0.0:
		sprite.modulate.a = 1.0
		if camera != null:
			camera.position = _camera_rest_position


func _handle_state_input() -> void:
	if input_locked:
		return
	if _is_action_just_pressed("use_protection_potion"):
		try_use_protection_potion()
	if state == State.PARRY:
		# A fresh press inside the flash must work even if an earlier parry animation is still ending.
		if _is_action_just_pressed("parry"):
			_enter_parry()
		return
	if state in [State.ATTACK, State.HURT]:
		return

	if _is_action_just_pressed("attack"):
		_enter_attack()
	elif _is_action_just_pressed("parry"):
		_enter_parry()
	elif _is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = jump_velocity
			_jumps_used = 1
			_play_player_sfx(_movement_audio, JUMP_SFX, 1.0, -2.0)
		elif GameState.unlocked_abilities.get("double_jump", false) and _jumps_used < 2:
			velocity.y = jump_velocity
			_jumps_used = 2
			_play_player_sfx(_movement_audio, JUMP_SFX, 1.15, -2.0)
			# El doble salto reutiliza y reinicia la animación del salto normal.
			_play_animation(&"jump", false, true)


func _handle_movement(delta: float) -> void:
	var direction := _get_move_direction() # FIX-ATQ
	if direction != 0.0: # FIX-ATQ
		_update_facing(direction) # FIX-ATQ

	if input_locked:
		velocity.x = 0.0
		return

	if state == State.HURT:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		return

	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if _is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.5


func _get_move_direction() -> float:
	if not InputMap.has_action("move_left") or not InputMap.has_action("move_right"):
		return 0.0
	return Input.get_axis("move_left", "move_right")


func _update_facing(direction: float) -> void: # FIX-ATQ
	if direction == 0.0: # FIX-ATQ
		return # FIX-ATQ
	facing = signf(direction) # FIX-ATQ
	# Los sprites fuente miran hacia la izquierda; se espejan al avanzar a la derecha.
	sprite.flip_h = facing > 0.0 # FIX-ATQ


func _update_attack_direction() -> void:
	attack_pivot.position = Vector2(ATTACK_PIVOT_OFFSET.x * facing, ATTACK_PIVOT_OFFSET.y)
	attack_pivot.scale.x = facing


func _update_parry_direction() -> void:
	parry_zone.position = Vector2(PARRY_ZONE_OFFSET.x * facing, PARRY_ZONE_OFFSET.y)
	parry_zone.scale.x = facing


func _configure_animations() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")

	for animation_name in ANIMATION_ORDER:
		var config: Dictionary = ANIMATION_CONFIG[animation_name]
		var texture: Texture2D = config["texture"]
		var frame_count: int = config["frame_count"]
		var source_frame_count := frame_count
		if not _texture_has_visible_pixels(texture):
			texture = ANIMATION_CONFIG[&"idle"]["texture"]
			source_frame_count = ANIMATION_CONFIG[&"idle"]["frame_count"]
		var frame_width := int(texture.get_width() / float(source_frame_count))
		var frame_height := texture.get_height()

		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, config["fps"])
		frames.set_animation_loop(animation_name, config["loop"])

		for frame_index in frame_count:
			var source_frame_index := frame_index % source_frame_count
			var frame_texture := AtlasTexture.new()
			frame_texture.atlas = texture
			frame_texture.region = Rect2(
				source_frame_index * frame_width,
				0,
				frame_width,
				frame_height
			)
			frames.add_frame(animation_name, frame_texture)

	sprite.sprite_frames = frames


func _texture_has_visible_pixels(texture: Texture2D) -> bool:
	var image := texture.get_image()
	return image != null and image.get_used_rect().size != Vector2i.ZERO


func _update_animation() -> void:
	if state == State.DEAD:
		return
	if _visual_one_shot_active and not sprite.is_playing():
		_visual_one_shot_active = false

	if state == State.HURT:
		_play_animation(&"hurt", true)
		return
	if state == State.PARRY:
		_play_animation(&"parry", true)
		return
	if state == State.ATTACK:
		_play_animation(&"attack", true)
		return
	if _visual_one_shot_active:
		return
	if not is_on_floor():
		_play_animation(&"jump")
	elif not is_zero_approx(velocity.x):
		_play_animation(&"walk")
	else:
		_play_animation(&"idle")


func _play_animation(animation_name: StringName, one_shot := false, restart := false) -> void:
	if restart or sprite.animation != animation_name:
		sprite.play(animation_name)
	if one_shot:
		_visual_one_shot_active = true


func _on_sprite_animation_finished() -> void:
	_visual_one_shot_active = false
	_update_animation()


func _is_action_just_pressed(action: StringName) -> bool:
	return InputMap.has_action(action) and Input.is_action_just_pressed(action)


func _is_action_just_released(action: StringName) -> bool:
	return InputMap.has_action(action) and Input.is_action_just_released(action)


func _update_state_timers(delta: float) -> void:
	if _state_time_left > 0.0:
		_state_time_left -= delta
		if _state_time_left <= 0.0:
			state = State.IDLE
			parry_zone.monitoring = false

	if _hitbox_time_left > 0.0:
		_hitbox_time_left -= delta
		if _hitbox_time_left <= 0.0:
			hit_box.monitoring = false



func _update_locomotion_state() -> void:
	if state in [State.ATTACK, State.PARRY, State.HURT]:
		return
	if not is_on_floor():
		state = State.JUMP
	elif not is_zero_approx(velocity.x):
		state = State.RUN
	else:
		state = State.IDLE


func _enter_attack() -> void:
	var attack_direction := _get_move_direction() # FIX-ATQ
	if attack_direction != 0.0: # FIX-ATQ
		_update_facing(attack_direction) # FIX-ATQ
	_update_attack_direction()
	state = State.ATTACK
	_state_time_left = ATTACK_DURATION
	_hitbox_time_left = ATTACK_HITBOX_DURATION
	_hit_targets.clear()
	hit_box.monitoring = true # FIX-ATQ
	_play_animation(&"attack", true, true)
	_play_player_sfx(_action_audio, ATTACK_SFX, 1.0, 1.0)


func _enter_parry() -> void:
	var parry_direction := _get_move_direction()
	if parry_direction != 0.0:
		_update_facing(parry_direction)
	_update_parry_direction()
	state = State.PARRY
	_state_time_left = PARRY_DURATION
	parry_zone.monitoring = true
	_play_animation(&"parry", true, true)
	_play_player_sfx(_action_audio, PARRY_START_SFX, 1.0, -3.0)
	for enemy in get_tree().get_nodes_in_group("perfect_parry_targets"):
		if enemy.has_method("try_perfect_parry") and enemy.try_perfect_parry(self):
			_register_parry(enemy)
			break


func take_damage(amount: int, attacker: Node2D = null, contact: bool = false) -> void:
	if contact and attacker is GuardianSediento:
		if _guardian_contact_grace_left > 0.0:
			return
		# Contact can be processed before Player input in the same physics frame.
		# Defer it for that frame; only the attack window can award Perfect Parry.
		if _is_action_just_pressed("parry") and attacker.is_parryable_windup():
			return
	if state == State.DEAD or GameState.current_health <= 0 or _damage_invulnerability_left > 0.0:
		return
	if not contact and state == State.PARRY and is_instance_valid(attacker) and attacker.has_method("stun"):
		if not attacker.has_method("can_be_parried") or attacker.can_be_parried():
			# A normal block grants neither posture nor a counterattack charge.
			if not attacker is GuardianSediento:
				attacker.stun(attacker)
			return

	if amount <= 0:
		return
	_damage_invulnerability_left = DAMAGE_INVULNERABILITY_DURATION
	if GameState.absorb_protected_hit():
		_flash_protection(GameState.protection_hits_remaining == 0)
		return
	GameState.take_damage(amount)
	_play_player_sfx(_feedback_audio, HIT_SFX, 1.0, 1.0)
	current_health = GameState.current_health
	health_changed.emit()
	_damage_feedback_time_left = DAMAGE_FEEDBACK_DURATION
	if current_health == 0:
		begin_death()
		died.emit()
		return

	state = State.HURT
	_state_time_left = HURT_DURATION
	_play_animation(&"hurt", true, true)
	var knockback_direction := 1.0
	if attacker != null:
		knockback_direction = signf(global_position.x - attacker.global_position.x)
	if is_zero_approx(knockback_direction):
		knockback_direction = -signf(velocity.x) if not is_zero_approx(velocity.x) else 1.0
	velocity.x = knockback_direction * speed * 0.5


func try_use_protection_potion() -> void:
	if input_locked or state == State.DEAD:
		return
	if GameState.use_protection_potion():
		_flash_protection(false)


func _flash_protection(broken: bool) -> void:
	# self_modulate is independent of the existing damage/counterattack modulate.
	var tint := Color(0.9, 1.0, 1.0) if broken else Color(0.52, 1.0, 0.96)
	if _protection_flash_tween != null and _protection_flash_tween.is_valid():
		_protection_flash_tween.kill()
	sprite.self_modulate = tint
	_protection_flash_tween = create_tween()
	_protection_flash_tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.38 if broken else 0.45)


func _register_parry(enemy: Node2D) -> void:
	if enemy is GuardianSediento:
		_guardian_contact_grace_left = GUARDIAN_PARRY_CONTACT_GRACE
	counterattack_ready = GameState.unlocked_abilities.get("counterattack", false)
	_play_player_sfx(_feedback_audio, PARRY_SUCCESS_SFX, 1.0, 4.0)
	parry_success.emit(enemy)


func _on_hit_box_body_entered(body: Node2D) -> void:
	# El cuerpo del Espectro es exclusivamente físico; recibe golpes mediante su HurtBox.
	if body is EspectroSediento:
		return
	_register_attack_target(body)


func _on_hit_box_area_entered(area: Area2D) -> void:
	var target := area.get_parent() as Node2D
	_register_attack_target(target)


func _register_attack_target(target: Node2D) -> void:
	if state != State.ATTACK:
		return
	if target == null or target == self or _hit_targets.has(target.get_instance_id()):
		return
	if not target.has_method("take_damage") or not "current_health" in target:
		return
	_hit_targets[target.get_instance_id()] = true
	var before: int = target.current_health
	var damage := 2 if counterattack_ready else 1
	attack_hit.emit(target, damage)
	if counterattack_ready and (not is_instance_valid(target) or target.current_health < before):
		counterattack_ready = false
		sprite.modulate = Color.WHITE
		_play_player_sfx(_action_audio, COUNTERATTACK_SFX, 1.0, 2.0)


func _on_parry_zone_body_entered(_body: Node2D) -> void:
	# Rewards are decided on the press during an enemy's telegraph, never on touch.
	pass


func can_reach_parry(target: Node2D, reach: float) -> bool:
	var distance := target.global_position - global_position
	return absf(distance.x) <= reach and absf(distance.y) <= 140.0 and distance.x * facing >= -20.0


func _sync_health(current: int, maximum: int) -> void:
	current_health = current
	max_health = maximum
	health_changed.emit()


func begin_death() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	GameState.clear_protection()
	_guardian_contact_grace_left = 0.0
	input_locked = true
	velocity = Vector2.ZERO
	counterattack_ready = false
	hit_box.set_deferred("monitoring", false)
	parry_zone.set_deferred("monitoring", false)
	sprite.modulate = Color.WHITE
	sprite.self_modulate = Color.WHITE
	sprite.process_mode = Node.PROCESS_MODE_ALWAYS
	# The project has no death sheet; retain its existing hurt one-shot.
	_play_animation(&"death" if sprite.sprite_frames.has_animation(&"death") else &"hurt", true, true)


func finish_respawn() -> void:
	state = State.IDLE
	input_locked = false
	counterattack_ready = false
	_state_time_left = 0.0
	_hitbox_time_left = 0.0
	_damage_feedback_time_left = 0.0
	_damage_invulnerability_left = 0.0
	_guardian_contact_grace_left = 0.0
	_hit_targets.clear()
	sprite.process_mode = Node.PROCESS_MODE_INHERIT
	sprite.modulate = Color.WHITE
	sprite.self_modulate = Color.WHITE
	_visual_one_shot_active = false
	if camera != null:
		camera.position = _camera_rest_position
	_update_animation()


func _create_audio_player(node_name: String) -> AudioStreamPlayer2D:
	var player := AudioStreamPlayer2D.new()
	player.name = node_name
	player.bus = &"SFX"
	player.max_polyphony = 4
	add_child(player)
	return player


func _play_player_sfx(
	player: AudioStreamPlayer2D,
	stream: AudioStream,
	pitch := 1.0,
	volume_db := 0.0
) -> void:
	if player == null:
		return
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()


func _update_movement_audio(delta: float, was_on_floor: bool) -> void:
	var grounded := is_on_floor()
	if not grounded:
		_has_been_airborne = true
	if grounded and not was_on_floor and _has_been_airborne:
		_has_been_airborne = false
		_play_player_sfx(_movement_audio, LAND_SFX, 1.0, -2.0)
	var walking := grounded \
		and not input_locked \
		and state not in [State.ATTACK, State.PARRY, State.HURT] \
		and absf(velocity.x) > 35.0
	if not walking:
		_footstep_time_left = 0.0
		return
	_footstep_time_left -= delta
	if _footstep_time_left > 0.0:
		return
	_footstep_time_left = FOOTSTEP_INTERVAL
	var stream: AudioStream = FOOTSTEP_01 if _next_footstep == 0 else FOOTSTEP_02
	_next_footstep = 1 - _next_footstep
	_play_player_sfx(_movement_audio, stream, 1.0, -7.0)
