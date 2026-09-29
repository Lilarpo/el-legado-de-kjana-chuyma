class_name EspectroSediento
extends CharacterBody2D

signal died

enum State {
	PATROL,
	CHASE,
	ATTACK_WINDUP,
	ATTACK_ACTIVE,
	RECOVERY,
	STUN,
	HURT,
	RETURN,
	DEAD,
}

@export_category("Movement")
@export var patrol_distance := 180.0
@export var patrol_speed := 45.0
@export var chase_speed := 84.0
@export var detection_range := 315.0
@export var max_chase_distance := 400.0
@export var fall_limit_y := 800.0

@export_category("Attack")
@export var attack_range := 50.0
@export var attack_delay_min := 0.46
@export var attack_delay_max := 1.08
@export var attack_windup_duration := 0.5
@export var attack_active_duration := 0.3
@export var attack_recovery_duration := 0.48
@export var parry_stun_duration := 1.4

@export_category("Health")
@export var max_health := 4
@export var stompable := false
@export var drops_protection_potion := false
@export var potion_drop_id := ""
var _potion_drop_spawned := false

@export_category("Debug")
@export var debug_ai := false

const GRAVITY := 980.0
const HURT_DURATION := 0.25
const HURT_INVULNERABILITY := 0.15
const LOST_TARGET_GRACE := 1.2
const EDGE_CHECK_DISTANCE := 28.0
const ATTACK_HITBOX_OFFSET := 46.0
const VERTICAL_DETECTION_TOLERANCE := 96.0
const FRAME_SIZE := Vector2i(64, 64)
const PARRY_GLINT_LEAD_TIME := 0.16
const PARRY_GLINT_VFX := preload("res://scenes/vfx/ParryFlash.tscn")
const PARRY_SUCCESS_VFX := preload("res://scenes/vfx/parry/ParrySuccessVFX.tscn")

const ANIMATION_FRAMES := {
	&"idle": [Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0), Vector2i(8, 0)],
	&"move": [
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1),
		Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1), Vector2i(8, 1),
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
		Vector2i(5, 2), Vector2i(6, 2), Vector2i(7, 2), Vector2i(8, 2),
	],
	&"attack": [
		Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3),
		Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3), Vector2i(8, 3),
	],
	&"hurt": [Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)],
	&"stun": [Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)],
	&"death": [Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5)],
}

const ANIMATION_SPEEDS := {
	&"idle": 5.0,
	&"move": 14.0,
	&"attack": 8.0,
	&"hurt": 12.0,
	&"stun": 8.0,
	&"death": 9.0,
}

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var body_collision: CollisionShape2D = $Collision
@onready var hurt_box: Area2D = $HurtBox
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var parry_cue: Marker2D = $ParryCue
@onready var attack_audio: AudioStreamPlayer2D = $AttackAudio
@onready var death_audio: AudioStreamPlayer2D = $DeathAudio
@onready var wall_ray: RayCast2D = $WallRay
@onready var floor_ray: RayCast2D = $FloorRay

var current_health := 4
var state := State.PATROL
var spawn_position := Vector2.ZERO
var facing := 1.0

var _player: Node2D
var _state_time_left := 0.0
var _attack_wait_remaining := 0.0
var _lost_target_time := 0.0
var _blocked_time := 0.0
var _hurt_invulnerability_left := 0.0
var _patrol_direction := 1.0
var _rng := RandomNumberGenerator.new()
var _initial_collision_layer := 0
var _initial_collision_mask := 0
var _initial_hurt_box_layer := 0
var _initial_hurt_box_mask := 0
var _parry_telegraph_shown := false


func _ready() -> void:
	add_to_group("perfect_parry_targets")
	add_to_group("enemies")
	spawn_position = global_position
	current_health = max_health
	_initial_collision_layer = collision_layer
	_initial_collision_mask = collision_mask
	_initial_hurt_box_layer = hurt_box.collision_layer
	_initial_hurt_box_mask = hurt_box.collision_mask
	_rng.randomize()
	attack_audio.bus = &"SFX"
	attack_audio.volume_db = -1.0
	attack_audio.stream = preload("res://assets/audio/sfx/enemies/specter_attack.wav")
	death_audio.bus = &"SFX"
	death_audio.volume_db = 0.0
	death_audio.stream = preload("res://assets/audio/sfx/enemies/specter_death.wav")
	_configure_animations()
	attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)
	sprite.animation_finished.connect(_on_animation_finished)
	_set_attack_active(false)
	_find_player()
	_roll_attack_delay()
	_update_facing(1.0)
	_play_animation(&"idle")
	queue_redraw()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	_hurt_invulnerability_left = maxf(_hurt_invulnerability_left - delta, 0.0)
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if not is_instance_valid(_player):
		_find_player()

	match state:
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK_WINDUP:
			_process_attack_windup(delta)
		State.ATTACK_ACTIVE:
			_process_attack_active(delta)
		State.RECOVERY:
			_process_recovery(delta)
		State.STUN, State.HURT:
			_process_disabled_state(delta)
		State.RETURN:
			_process_return(delta)

	move_and_slide()
	if global_position.y > fall_limit_y:
		_reset_after_fall()
	_update_animation()


func _process_patrol(delta: float) -> void:
	if _can_detect_player():
		_enter_state(State.CHASE)
		return

	var patrol_offset := global_position.x - spawn_position.x
	if patrol_offset >= patrol_distance:
		_patrol_direction = -1.0
	elif patrol_offset <= -patrol_distance:
		_patrol_direction = 1.0

	_move_horizontal(_patrol_direction, patrol_speed, delta)


func _process_chase(delta: float) -> void:
	if not _target_is_reachable():
		_lost_target_time += delta
		velocity.x = move_toward(velocity.x, 0.0, chase_speed * 8.0 * delta)
		if _lost_target_time >= LOST_TARGET_GRACE:
			_enter_state(State.RETURN)
		return
	_lost_target_time = 0.0

	if absf(global_position.x - spawn_position.x) >= max_chase_distance:
		_enter_state(State.RETURN)
		return

	var to_player := _player.global_position - global_position
	var direction := signf(to_player.x)
	if not is_zero_approx(direction):
		_update_facing(direction)

	if absf(to_player.x) <= attack_range:
		velocity.x = move_toward(velocity.x, 0.0, chase_speed * 10.0 * delta)
		_attack_wait_remaining -= delta
		if _attack_wait_remaining <= 0.0:
			_enter_state(State.ATTACK_WINDUP)
		return

	if not _move_horizontal(direction, chase_speed, delta):
		_blocked_time += delta
		if _blocked_time >= LOST_TARGET_GRACE:
			_enter_state(State.RETURN)
	else:
		_blocked_time = 0.0


func _process_attack_windup(delta: float) -> void:
	velocity.x = 0.0
	_face_player()
	_state_time_left -= delta
	if not _parry_telegraph_shown and _state_time_left <= PARRY_GLINT_LEAD_TIME:
		_parry_telegraph_shown = true
		_spawn_vfx(PARRY_GLINT_VFX, parry_cue.global_position, _state_time_left)
	if _state_time_left <= 0.0:
		_enter_state(State.ATTACK_ACTIVE)


func _process_attack_active(delta: float) -> void:
	velocity.x = 0.0
	_state_time_left -= delta
	if _state_time_left <= 0.0:
		_enter_state(State.RECOVERY)


func _process_recovery(delta: float) -> void:
	velocity.x = 0.0
	_state_time_left -= delta
	if _state_time_left <= 0.0:
		_roll_attack_delay()
		_enter_state(State.CHASE if _can_detect_player() else State.RETURN)


func _process_disabled_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, patrol_speed * 10.0 * delta)
	_state_time_left -= delta
	if _state_time_left <= 0.0:
		_enter_state(State.CHASE if _can_detect_player() else State.RETURN)


func _process_return(delta: float) -> void:
	var distance_home := spawn_position.x - global_position.x
	if absf(distance_home) <= 8.0:
		global_position.x = spawn_position.x
		_patrol_direction = 1.0
		_enter_state(State.PATROL)
		return

	var direction := signf(distance_home)
	if not _move_horizontal(direction, patrol_speed, delta):
		velocity.x = 0.0
		if absf(global_position.x - spawn_position.x) <= patrol_distance:
			_enter_state(State.PATROL)


func _move_horizontal(direction: float, move_speed: float, delta: float) -> bool:
	if is_zero_approx(direction):
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 8.0 * delta)
		return true
	_update_facing(direction)
	if not _can_move_in_direction(direction):
		velocity.x = 0.0
		if state == State.PATROL:
			_patrol_direction = -direction
		return false
	velocity.x = move_toward(velocity.x, direction * move_speed, move_speed * 8.0 * delta)
	return true


func _can_move_in_direction(direction: float) -> bool:
	wall_ray.target_position = Vector2(EDGE_CHECK_DISTANCE * direction, 0.0)
	floor_ray.position.x = EDGE_CHECK_DISTANCE * direction
	wall_ray.force_raycast_update()
	floor_ray.force_raycast_update()
	return not wall_ray.is_colliding() and floor_ray.is_colliding()


func _can_detect_player() -> bool:
	if not is_instance_valid(_player):
		return false
	var offset := _player.global_position - global_position
	return offset.length() <= detection_range \
		and absf(offset.y) <= VERTICAL_DETECTION_TOLERANCE \
		and _has_clear_line_to_player()


func _target_is_reachable() -> bool:
	if not is_instance_valid(_player):
		return false
	var offset := _player.global_position - global_position
	return offset.length() <= detection_range * 1.35 \
		and absf(offset.y) <= VERTICAL_DETECTION_TOLERANCE \
		and _has_clear_line_to_player()


func _has_clear_line_to_player() -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, _player.global_position, 1)
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _enter_state(next_state: State) -> void:
	if state == State.DEAD:
		return
	state = next_state
	if debug_ai:
		print("%s -> %s" % [name, State.keys()[state]])
	match state:
		State.ATTACK_WINDUP:
			velocity.x = 0.0
			_face_player()
			_parry_telegraph_shown = false
			_state_time_left = attack_windup_duration
			_play_animation(&"attack", true)
		State.ATTACK_ACTIVE:
			attack_audio.play()
			_state_time_left = attack_active_duration
			_set_attack_active(true)
		State.RECOVERY:
			_set_attack_active(false)
			_state_time_left = attack_recovery_duration
		State.STUN:
			_set_attack_active(false)
			_state_time_left = parry_stun_duration
			_play_animation(&"stun", true)
		State.HURT:
			_state_time_left = HURT_DURATION
			_play_animation(&"hurt", true)
		State.RETURN:
			_set_attack_active(false)
			_lost_target_time = 0.0
			_blocked_time = 0.0
		State.CHASE:
			_lost_target_time = 0.0
			_blocked_time = 0.0
	queue_redraw()


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
	elif state not in [State.ATTACK_WINDUP, State.ATTACK_ACTIVE]:
		_enter_state(State.HURT)


func stun(parried_enemy: Node2D = null) -> void:
	if state == State.DEAD:
		return
	if parried_enemy != null and parried_enemy != self:
		return
	if parried_enemy == self:
		_spawn_vfx(PARRY_SUCCESS_VFX, _parry_contact_position())
	_enter_state(State.STUN)


func restore_to_snapshot() -> void:
	if is_queued_for_deletion():
		return
	global_position = spawn_position
	velocity = Vector2.ZERO
	current_health = max_health
	state = State.PATROL
	_patrol_direction = 1.0
	_hurt_invulnerability_left = 0.0
	collision_layer = _initial_collision_layer
	collision_mask = _initial_collision_mask
	hurt_box.collision_layer = _initial_hurt_box_layer
	hurt_box.collision_mask = _initial_hurt_box_mask
	body_collision.set_deferred("disabled", false)
	hurt_box.set_deferred("monitorable", true)
	_set_attack_active(false)
	show()
	_play_animation(&"idle", true)


func _die() -> void:
	state = State.DEAD
	death_audio.play()
	velocity = Vector2.ZERO
	_set_attack_active(false)
	collision_layer = 0
	collision_mask = 0
	hurt_box.collision_layer = 0
	hurt_box.collision_mask = 0
	body_collision.set_deferred("disabled", true)
	hurt_box.set_deferred("monitorable", false)
	died.emit()
	_play_animation(&"death", true)


func _reset_after_fall() -> void:
	if state == State.DEAD:
		return
	global_position = spawn_position
	velocity = Vector2.ZERO
	_set_attack_active(false)
	state = State.PATROL
	_patrol_direction = 1.0
	_play_animation(&"idle", true)


func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	if state != State.ATTACK_ACTIVE or body.name != "Player":
		return
	if body.has_method("take_damage"):
		body.take_damage(1, self)


func _set_attack_active(active: bool) -> void:
	attack_hitbox.set_deferred("monitoring", active)


func _face_player() -> void:
	if not is_instance_valid(_player):
		return
	var direction := signf(_player.global_position.x - global_position.x)
	if not is_zero_approx(direction):
		_update_facing(direction)


func _update_facing(direction: float) -> void:
	facing = signf(direction)
	sprite.flip_h = facing > 0.0
	attack_hitbox.position.x = ATTACK_HITBOX_OFFSET * facing
	parry_cue.position.x = 46.0 * facing


func _parry_contact_position() -> Vector2:
	if is_instance_valid(_player):
		return (global_position + _player.global_position) * 0.5 + Vector2(0.0, -22.0)
	return parry_cue.global_position


func _spawn_vfx(scene: PackedScene, world_position: Vector2, duration := 0.0) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	var vfx := scene.instantiate() as Node2D
	current_scene.add_child(vfx)
	vfx.global_position = world_position

	if duration > 0.0 and vfx.has_method("set_duration"):
		vfx.set_duration(duration)

func _find_player() -> void:
	var current_scene := get_tree().current_scene
	_player = current_scene.get_node_or_null("Player") if current_scene != null else null


func _roll_attack_delay() -> void:
	var minimum := minf(attack_delay_min, attack_delay_max)
	var maximum := maxf(attack_delay_min, attack_delay_max)
	_attack_wait_remaining = _rng.randf_range(minimum, maximum)


func _configure_animations() -> void:
	var texture := preload("res://assets/sprites/enemies/espectro_sediento/espectro_sediento.png")
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for animation_name: StringName in ANIMATION_FRAMES:
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, ANIMATION_SPEEDS[animation_name])
		frames.set_animation_loop(animation_name, animation_name in [&"idle", &"move", &"stun"])
		for coordinate: Vector2i in ANIMATION_FRAMES[animation_name]:
			var frame := AtlasTexture.new()
			frame.atlas = texture
			frame.region = Rect2i(coordinate * FRAME_SIZE, FRAME_SIZE)
			frames.add_frame(animation_name, frame)
	sprite.sprite_frames = frames


func _update_animation() -> void:
	match state:
		State.ATTACK_WINDUP, State.ATTACK_ACTIVE, State.RECOVERY, State.STUN, State.HURT:
			return
		State.PATROL, State.CHASE, State.RETURN:
			_play_animation(&"move" if not is_zero_approx(velocity.x) else &"idle")


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
	draw_line(Vector2(-patrol_distance, 0.0), Vector2(patrol_distance, 0.0), Color.YELLOW, 2.0)
	draw_arc(Vector2.ZERO, detection_range, 0.0, TAU, 48, Color(0.2, 0.8, 1.0, 0.45), 1.0)
	draw_arc(Vector2.ZERO, max_chase_distance, 0.0, TAU, 48, Color(1.0, 0.4, 0.2, 0.35), 1.0)


func try_perfect_parry(player: WayraPlayer) -> bool:
	return state == State.ATTACK_WINDUP and _parry_telegraph_shown and _state_time_left > 0.0 and _state_time_left <= PARRY_GLINT_LEAD_TIME and player.can_reach_parry(self, 140.0)
