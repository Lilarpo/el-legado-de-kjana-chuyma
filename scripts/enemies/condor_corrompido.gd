class_name CondorCorrompido
extends CharacterBody2D

signal died

enum State {
	FLY_PATROL,
	TRACK,
	DIVE_WINDUP,
	DIVE_ATTACK,
	DIVE_RECOVERY,
	ASCEND,
	RETURN,
	STUN,
	HURT,
	DEAD,
}

@export_category("Patrol")
@export var patrol_distance := 180.0
@export var patrol_speed := 60.0
@export var hover_amplitude := 6.0

@export_category("Detection")
@export var detection_range_x := 442.0
@export var detection_range_y := 320.0
@export var tracking_time_min := 0.35
@export var tracking_time_max := 0.85

@export_category("Dive")
@export var dive_windup_duration := 0.45
@export var dive_speed := 297.0
@export var dive_recovery_duration := 0.35
@export var return_speed := 126.0
@export var max_distance_from_spawn := 420.0
@export var attack_cooldown_min := 1.08
@export var attack_cooldown_max := 1.8
@export var parry_stun_duration := 1.8

@export_category("Health")
@export var max_health := 3
@export var stompable := false
@export var drops_protection_potion := false
@export var potion_drop_id := ""
var _potion_drop_spawned := false

@export_category("Debug")
@export var debug_ai := false

const FRAME_SIZE := Vector2i(48, 32)
const HURT_DURATION := 0.22
const HURT_INVULNERABILITY := 0.18
const TARGET_OVERSHOOT := 56.0
const MAX_DIVE_DURATION := 2.0
const ARRIVAL_DISTANCE := 10.0

const ANIMATION_FRAMES := {
	&"fly": [
		Vector2i(0, 6), Vector2i(1, 6), Vector2i(2, 6),
		Vector2i(3, 6), Vector2i(4, 6), Vector2i(5, 6),
		Vector2i(6, 6), Vector2i(7, 6), Vector2i(8, 6),
	],
	&"track": [
		Vector2i(0, 6), Vector2i(1, 6), Vector2i(2, 6),
		Vector2i(3, 6), Vector2i(4, 6), Vector2i(5, 6),
		Vector2i(6, 6), Vector2i(7, 6), Vector2i(8, 6),
	],
	&"dive_windup": [
		Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5),
		Vector2i(3, 5), Vector2i(4, 5),
	],
	&"dive": [
		Vector2i(0, 6), Vector2i(1, 6), Vector2i(2, 6),
		Vector2i(3, 6), Vector2i(4, 6), Vector2i(5, 6),
		Vector2i(6, 6), Vector2i(7, 6), Vector2i(8, 6),
	],
	&"hurt": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
	&"stun": [Vector2i(2, 0), Vector2i(3, 0)],
	&"death": [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
		Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0),
	],
}

const ANIMATION_SPEEDS := {
	&"fly": 12.0,
	&"track": 12.0,
	&"dive_windup": 10.0,
	&"dive": 16.0,
	&"hurt": 12.0,
	&"stun": 7.0,
	&"death": 9.0,
}

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var body_collision: CollisionShape2D = $Collision
@onready var hurt_box: Area2D = $HurtBox
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var dive_audio: AudioStreamPlayer2D = $DiveAudio
@onready var death_audio: AudioStreamPlayer2D = $DeathAudio

var current_health := 3
var state := State.FLY_PATROL
var spawn_position := Vector2.ZERO
var dive_target_position := Vector2.ZERO
var facing := 1.0

var _player: Node2D
var _state_time_left := 0.0
var _attack_cooldown_left := 0.0
var _hurt_invulnerability_left := 0.0
var _hover_time := 0.0
var _patrol_direction := 1.0
var _dive_direction := Vector2.DOWN
var _dive_end_position := Vector2.ZERO
var _dive_time_left := 0.0
var _attack_has_hit := false
var _rng := RandomNumberGenerator.new()
var _initial_collision_mask := 0
var _initial_hurt_box_layer := 0
var _initial_hurt_box_mask := 0


var _perfect_flash_shown := false
const PERFECT_FLASH := preload("res://scenes/vfx/ParryFlash.tscn")


func _ready() -> void:
	add_to_group("perfect_parry_targets")
	add_to_group("enemies")
	spawn_position = global_position
	current_health = max_health
	_initial_collision_mask = collision_mask
	_initial_hurt_box_layer = hurt_box.collision_layer
	_initial_hurt_box_mask = hurt_box.collision_mask
	_rng.randomize()
	dive_audio.bus = &"SFX"
	dive_audio.volume_db = -1.0
	dive_audio.stream = preload("res://assets/audio/sfx/enemies/condor_dive.wav")
	death_audio.bus = &"SFX"
	death_audio.volume_db = 0.0
	death_audio.stream = preload("res://assets/audio/sfx/enemies/condor_death.wav")
	_configure_animations()
	attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)
	sprite.animation_finished.connect(_on_animation_finished)
	_set_attack_active(false)
	_find_player()
	_roll_attack_cooldown()
	_update_facing(1.0)
	_play_animation(&"fly")
	queue_redraw()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	_hover_time += delta
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	_hurt_invulnerability_left = maxf(_hurt_invulnerability_left - delta, 0.0)
	if not is_instance_valid(_player):
		_find_player()

	match state:
		State.FLY_PATROL:
			_process_fly_patrol(delta)
		State.TRACK:
			_process_track(delta)
		State.DIVE_WINDUP:
			_process_dive_windup(delta)
		State.DIVE_ATTACK:
			_process_dive_attack(delta)
		State.DIVE_RECOVERY:
			_process_dive_recovery(delta)
		State.ASCEND:
			_process_ascend(delta)
		State.RETURN:
			_process_return(delta)
		State.STUN, State.HURT:
			_process_disabled_state(delta)

	move_and_slide()
	if state == State.DIVE_ATTACK and get_slide_collision_count() > 0:
		_enter_state(State.DIVE_RECOVERY)
	_update_animation()
	if debug_ai:
		queue_redraw()


func _process_fly_patrol(delta: float) -> void:
	var offset_x := global_position.x - spawn_position.x
	if offset_x >= patrol_distance:
		_patrol_direction = -1.0
	elif offset_x <= -patrol_distance:
		_patrol_direction = 1.0

	velocity.x = move_toward(velocity.x, _patrol_direction * patrol_speed, patrol_speed * 6.0 * delta)
	_set_hover_velocity()
	_update_facing(velocity.x)
	if _attack_cooldown_left <= 0.0 and _can_detect_player():
		_enter_state(State.TRACK)


func _process_track(delta: float) -> void:
	if _must_return():
		_enter_state(State.RETURN)
		return
	if not _target_is_nearby():
		_enter_state(State.RETURN)
		return

	_state_time_left -= delta
	var horizontal_direction := signf(_player.global_position.x - global_position.x)
	velocity.x = move_toward(velocity.x, horizontal_direction * patrol_speed, patrol_speed * 7.0 * delta)
	_set_hover_velocity()
	_update_facing(horizontal_direction)
	if _state_time_left <= 0.0:
		_enter_state(State.DIVE_WINDUP)


func _process_dive_windup(delta: float) -> void:
	if _must_return():
		_enter_state(State.RETURN)
		return
	velocity = velocity.move_toward(Vector2.ZERO, patrol_speed * 8.0 * delta)
	_face_player()
	_state_time_left -= delta
	if not _perfect_flash_shown and _state_time_left > 0.0 and _state_time_left <= 0.15:
		_perfect_flash_shown = true
		var flash := PERFECT_FLASH.instantiate()
		get_tree().current_scene.add_child(flash)
		var direction := signf(_player.global_position.x - global_position.x) if is_instance_valid(_player) else 1.0
		flash.global_position = global_position + Vector2(direction * 33.0, 0.0)
		flash.set_duration(_state_time_left)
	if _state_time_left <= 0.0:
		_start_dive()


func _process_dive_attack(delta: float) -> void:
	_dive_time_left -= delta
	velocity = _dive_direction * dive_speed
	_update_facing(_dive_direction.x)
	var passed_end := (global_position - _dive_end_position).dot(_dive_direction) >= 0.0
	if passed_end or _dive_time_left <= 0.0 or global_position.distance_to(spawn_position) > max_distance_from_spawn:
		_enter_state(State.DIVE_RECOVERY)


func _process_dive_recovery(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, dive_speed * 5.0 * delta)
	_state_time_left -= delta
	if _state_time_left <= 0.0:
		_enter_state(State.ASCEND)


func _process_ascend(_delta: float) -> void:
	var return_target := Vector2(
		clampf(global_position.x, spawn_position.x - patrol_distance, spawn_position.x + patrol_distance),
		spawn_position.y
	)
	_move_toward_point(return_target, return_speed)
	if global_position.distance_to(return_target) <= ARRIVAL_DISTANCE:
		_finish_return_cycle()


func _process_return(_delta: float) -> void:
	_move_toward_point(spawn_position, return_speed)
	if global_position.distance_to(spawn_position) <= ARRIVAL_DISTANCE:
		global_position = spawn_position
		_finish_return_cycle()


func _process_disabled_state(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, dive_speed * 4.0 * delta)
	_state_time_left -= delta
	if _state_time_left <= 0.0:
		_enter_state(State.ASCEND)


func _move_toward_point(target: Vector2, speed: float) -> void:
	var offset := target - global_position
	velocity = offset.normalized() * speed if offset.length() > ARRIVAL_DISTANCE else Vector2.ZERO
	_update_facing(velocity.x)


func _set_hover_velocity() -> void:
	var desired_y := spawn_position.y + sin(_hover_time * 2.5) * hover_amplitude
	velocity.y = clampf((desired_y - global_position.y) * 4.0, -patrol_speed * 0.5, patrol_speed * 0.5)


func _can_detect_player() -> bool:
	if not is_instance_valid(_player):
		return false
	var offset := _player.global_position - global_position
	return absf(offset.x) <= detection_range_x \
		and offset.y >= -64.0 \
		and offset.y <= detection_range_y \
		and _has_clear_line_to_player()


func _target_is_nearby() -> bool:
	if not is_instance_valid(_player):
		return false
	var offset := _player.global_position - global_position
	return absf(offset.x) <= detection_range_x * 1.25 \
		and offset.y >= -96.0 \
		and offset.y <= detection_range_y * 1.35 \
		and global_position.distance_to(spawn_position) <= max_distance_from_spawn


func _has_clear_line_to_player() -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, _player.global_position, 1)
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _must_return() -> bool:
	if global_position.distance_to(spawn_position) > max_distance_from_spawn:
		return true
	return is_instance_valid(_player) and _player.global_position.distance_to(spawn_position) > max_distance_from_spawn


func _start_dive() -> void:
	if not is_instance_valid(_player):
		_enter_state(State.RETURN)
		return
	dive_target_position = _player.global_position
	_dive_direction = global_position.direction_to(dive_target_position)
	if _dive_direction.is_zero_approx():
		_dive_direction = Vector2.DOWN
	_dive_end_position = dive_target_position + _dive_direction * TARGET_OVERSHOOT
	_dive_time_left = MAX_DIVE_DURATION
	_enter_state(State.DIVE_ATTACK)


func _enter_state(next_state: State) -> void:
	if state == State.DEAD:
		return
	state = next_state
	if debug_ai:
		print("%s -> %s" % [name, State.keys()[state]])
	match state:
		State.FLY_PATROL:
			_set_attack_active(false)
			_play_animation(&"fly")
		State.TRACK:
			_state_time_left = _rng.randf_range(minf(tracking_time_min, tracking_time_max), maxf(tracking_time_min, tracking_time_max))
			_play_animation(&"track")
		State.DIVE_WINDUP:
			_set_attack_active(false)
			_perfect_flash_shown = false
			_state_time_left = dive_windup_duration
			_play_animation(&"dive_windup", true)
		State.DIVE_ATTACK:
			dive_audio.play()
			_attack_has_hit = false
			_set_attack_active(true)
			_play_animation(&"dive", true)
		State.DIVE_RECOVERY:
			_set_attack_active(false)
			_state_time_left = dive_recovery_duration
		State.ASCEND, State.RETURN:
			_set_attack_active(false)
			_play_animation(&"fly")
		State.STUN:
			_set_attack_active(false)
			_state_time_left = parry_stun_duration
			_play_animation(&"stun", true)
		State.HURT:
			_set_attack_active(false)
			_state_time_left = HURT_DURATION
			_play_animation(&"hurt", true)
	queue_redraw()


func _finish_return_cycle() -> void:
	velocity = Vector2.ZERO
	_roll_attack_cooldown()
	_enter_state(State.FLY_PATROL)


func take_damage(amount_or_target: Variant = 1, attack_damage: int = 1) -> void:
	if state == State.DEAD or _hurt_invulnerability_left > 0.0:
		return
	var damage := attack_damage
	if amount_or_target is Node and amount_or_target != self:
		return
	if amount_or_target is int:
		damage = amount_or_target
	if damage <= 0:
		return

	current_health = max(current_health - damage, 0)
	_hurt_invulnerability_left = HURT_INVULNERABILITY
	if current_health <= 0:
		_die()
	else:
		_enter_state(State.HURT)


func stun(parried_enemy: Node2D = null) -> void:
	if state == State.DEAD:
		return
	if parried_enemy != null and parried_enemy != self:
		return
	_enter_state(State.STUN)


func restore_to_snapshot() -> void:
	if is_queued_for_deletion():
		return
	global_position = spawn_position
	velocity = Vector2.ZERO
	current_health = max_health
	state = State.FLY_PATROL
	_patrol_direction = 1.0
	_hurt_invulnerability_left = 0.0
	collision_mask = _initial_collision_mask
	hurt_box.collision_layer = _initial_hurt_box_layer
	hurt_box.collision_mask = _initial_hurt_box_mask
	body_collision.set_deferred("disabled", false)
	hurt_box.set_deferred("monitorable", true)
	_set_attack_active(false)
	_roll_attack_cooldown()
	show()
	_play_animation(&"fly", true)


func _die() -> void:
	state = State.DEAD
	death_audio.play()
	velocity = Vector2.ZERO
	_set_attack_active(false)
	collision_mask = 0
	hurt_box.collision_layer = 0
	hurt_box.collision_mask = 0
	body_collision.set_deferred("disabled", true)
	hurt_box.set_deferred("monitorable", false)
	died.emit()
	_play_animation(&"death", true)


func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	if state != State.DIVE_ATTACK or _attack_has_hit or body.name != "Player":
		return
	_attack_has_hit = true
	if body.has_method("take_damage"):
		body.take_damage(1, self)
	if state == State.DIVE_ATTACK:
		_enter_state(State.DIVE_RECOVERY)


func _set_attack_active(active: bool) -> void:
	attack_hitbox.set_deferred("monitoring", active)


func _face_player() -> void:
	if is_instance_valid(_player):
		_update_facing(_player.global_position.x - global_position.x)


func _update_facing(direction_x: float) -> void:
	if is_zero_approx(direction_x):
		return
	facing = signf(direction_x)
	# La hoja fuente mira hacia la derecha.
	sprite.flip_h = facing < 0.0


func _find_player() -> void:
	var current_scene := get_tree().current_scene
	_player = current_scene.get_node_or_null("Player") if current_scene != null else null


func _roll_attack_cooldown() -> void:
	_attack_cooldown_left = _rng.randf_range(
		minf(attack_cooldown_min, attack_cooldown_max),
		maxf(attack_cooldown_min, attack_cooldown_max)
	)


func _configure_animations() -> void:
	var texture := preload("res://assets/sprites/enemies/condor_corrompido/condor_corrompido.png")
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for animation_name: StringName in ANIMATION_FRAMES:
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, ANIMATION_SPEEDS[animation_name])
		frames.set_animation_loop(animation_name, animation_name in [&"fly", &"track", &"dive", &"stun"])
		for coordinate: Vector2i in ANIMATION_FRAMES[animation_name]:
			var frame := AtlasTexture.new()
			frame.atlas = texture
			frame.region = Rect2i(coordinate * FRAME_SIZE, FRAME_SIZE)
			frames.add_frame(animation_name, frame)
	sprite.sprite_frames = frames


func _update_animation() -> void:
	match state:
		State.FLY_PATROL, State.ASCEND, State.RETURN:
			_play_animation(&"fly")
		State.TRACK:
			_play_animation(&"track")
		State.DIVE_ATTACK:
			_play_animation(&"dive")


func _play_animation(animation_name: StringName, restart := false) -> void:
	if restart or sprite.animation != animation_name:
		sprite.play(animation_name)


func _on_animation_finished() -> void:
	if state == State.DEAD and sprite.animation == &"death":
		_spawn_protection_potion()
		queue_free()


func _spawn_protection_potion() -> void:
	if _potion_drop_spawned or not drops_protection_potion or potion_drop_id.is_empty():
		return
	if GameState.collected_potion_drop_ids.has(potion_drop_id):
		return
	_potion_drop_spawned = true
	var pickup := preload("res://scenes/objects/ProtectionPotionPickup.tscn").instantiate()
	pickup.drop_id = potion_drop_id
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = global_position + Vector2(0.0, -12.0)


func _draw() -> void:
	if not debug_ai:
		return
	draw_line(Vector2(-patrol_distance, 0), Vector2(patrol_distance, 0), Color.YELLOW, 2.0)
	draw_rect(Rect2(-detection_range_x, -64.0, detection_range_x * 2.0, detection_range_y + 64.0), Color(0.1, 0.85, 0.85, 0.4), false, 1.0)
	draw_arc(spawn_position - global_position, max_distance_from_spawn, 0.0, TAU, 64, Color(1.0, 0.35, 0.2, 0.35), 1.0)


func try_perfect_parry(player: WayraPlayer) -> bool:
	return state == State.DIVE_WINDUP and _perfect_flash_shown and _state_time_left > 0.0 and _state_time_left <= 0.15 and player.can_reach_parry(self, 140.0)
