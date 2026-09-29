class_name GuardianSediento
extends CharacterBody2D

signal fight_started
signal fight_ended
signal health_changed(current: int, maximum: int)
signal posture_changed(current: int, required: int)
signal normal_hits_changed(current: int, required: int)
signal phase_changed(value: int)
signal defeated

enum State {
	INTRO,
	IDLE,
	SELECT_ATTACK,
	ATTACK_WINDUP,
	ATTACK_ACTIVE,
	ATTACK_RECOVERY,
	STAGGER,
	VULNERABLE,
	PHASE_TRANSITION,
	DEAD,
}

enum Attack {
	NONE,
	BITE,
	BITE_DOUBLE,
	SWEEP,
	PROJECTILE,
	CORRUPTION,
}

@export_category("Health and posture")
@export var max_health := 12
@export var parries_required := 3
@export var vulnerable_duration := 4.0
@export_range(0.1, 0.9, 0.05) var phase2_health_threshold := 0.5

@export_category("Pacing")
@export var phase1_attack_speed_multiplier := 1.0
@export var phase2_attack_speed_multiplier := 1.22
@export var attack_cooldown_min := 0.55
@export var attack_cooldown_max := 0.85

@export_category("Damage")
@export var bite_damage := 1
@export var projectile_damage := 1
@export var corruption_damage := 1

@export_category("Debug")
@export var debug_boss := false

const PHASE1_TEXTURE := preload("res://assets/sprites/bosses/guardian_sediento/guardian_phase1_normalized.png")
const PHASE2_TEXTURE := preload("res://assets/sprites/bosses/guardian_sediento/guardian_phase2_normalized.png")
const DEATH_TEXTURE := preload("res://assets/sprites/bosses/guardian_sediento/guardian_death_grounded.png")
const PROJECTILE_SCENE := preload("res://scenes/bosses/GuardianCorruptionProjectile.tscn")
const CORRUPTION_SCENE := preload("res://scenes/bosses/GuardianCorruptionZone.tscn")
const PARRY_GLINT_VFX := preload("res://scenes/vfx/ParryFlash.tscn")
const PARRY_SUCCESS_VFX := preload("res://scenes/vfx/parry/ParrySuccessVFX.tscn")
const POSTURE_BREAK_VFX := preload("res://scenes/vfx/parry/PostureBreakVFX.tscn")
const CORRUPTION_PULSE_VFX := preload("res://scenes/vfx/boss/GuardianCorruptionPulseVFX.tscn")
const CORRUPTION_FLASH_VFX := preload("res://scenes/vfx/boss/GuardianCorruptionFlashVFX.tscn")

const PHASE1_SCALE := 0.75
const PHASE2_SCALE := 0.64
const DEATH_SCALE := 0.39
const BITE_SPEED_PHASE1 := 620.0
const BITE_SPEED_PHASE2 := 760.0
const ARENA_MARGIN := 170.0
const INTRO_HOLD := 0.9
const PERFECT_PARRY_WINDOW_DURATION := 0.22
# Body contact rows, excluding detached sparks below the coils. The root and
# collision bottom stay at local Y=100; source textures are left untouched.
const PHASE1_BODY_BASE := [244, 243, 237, 244, 234, 234, 245, 244, 244, 246, 245, 246, 242, 242, 244, 226, 244, 226, 218, 218, 216, 217, 216, 216, 240, 240, 242, 243, 245, 232]
const PHASE2_BODY_BASE := [308, 309, 284, 305, 304, 308, 302, 301, 287, 301, 302, 299, 309, 291, 290, 309, 307, 288]
# Keep the last body pivot once the death animation becomes airborne debris.
const DEATH_BODY_BASE := [440, 448, 440, 440, 440, 440, 440, 440]

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var body_collision: CollisionShape2D = $BodyCollision
@onready var hurt_box: Area2D = $HurtBox
@onready var bite_hitbox: Area2D = $BiteHitbox
@onready var sweep_hitbox: Area2D = $SweepHitbox
@onready var parry_cue: Marker2D = $ParryCue
@onready var sweep_cue: Polygon2D = $SweepCue
@onready var bite_audio: AudioStreamPlayer2D = $BiteAudio
@onready var projectile_audio: AudioStreamPlayer2D = $ProjectileAudio
@onready var parry_audio: AudioStreamPlayer2D = $ParryAudio
@onready var posture_break_audio: AudioStreamPlayer2D = $PostureBreakAudio
@onready var phase_transition_audio: AudioStreamPlayer2D = $PhaseTransitionAudio
@onready var death_audio: AudioStreamPlayer2D = $DeathAudio

var current_health := 12
var phase := 1
var successful_parries := 0 # Shared posture points: Perfect Parry or four guard hits.
var normal_hits_toward_posture := 0
const NORMAL_HITS_PER_POSTURE := 4
var state := State.IDLE
var active := false

var _player: WayraPlayer
var _spawn_position := Vector2.ZERO
var _arena_left := 16150.0
var _arena_right := 17850.0
var _arena_center := Vector2(17000.0, 900.0)
var _attack_points: Array[Vector2] = []
var _corruption_points: Array[Vector2] = []
var _state_time_left := 0.0
var _current_attack := Attack.NONE
var _last_attack := Attack.NONE
var _repeat_count := 0
var _facing := -1.0
var _attack_direction := -1.0
var _attack_damage_done := false
var _projectile_spawned := false
var _pending_second_bite := false
var _double_bite_index := 0
var _phase_transition_done := false
var _death_finished := false
var _rng := RandomNumberGenerator.new()
var _spawned_projectiles: Array[Node] = []
var _spawned_zones: Array[Node] = []
var _spawned_vfx: Array[Node] = []
var _intro_emerged := false
var _intro_camera: Camera2D
var _intro_camera_offset := Vector2.ZERO
var _intro_camera_tween: Tween
var _intro_camera_zoom := Vector2.ONE
var _encounter_framing := false
var _perfect_parry_open := false
var _perfect_parry_confirmed := false


func _ready() -> void:
	add_to_group("boss")
	add_to_group("perfect_parry_targets")
	_spawn_position = global_position
	current_health = max_health
	_rng.randomize()
	_configure_audio()
	_configure_animations()
	sprite.frame_changed.connect(_on_sprite_frame_changed)
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	bite_hitbox.body_entered.connect(_on_bite_hitbox_body_entered)
	sweep_hitbox.body_entered.connect(_on_sweep_hitbox_body_entered)
	_set_all_attack_hitboxes(false)
	hurt_box.monitorable = false
	parry_cue.visible = false
	sweep_cue.visible = false
	visible = false
	set_physics_process(true)


func configure_arena(
	player: WayraPlayer,
	left_point: Vector2,
	right_point: Vector2,
	center_point: Vector2,
	corruption_markers: Array[Vector2]
) -> void:
	_player = player
	_attack_points = [left_point, right_point]
	_arena_left = minf(left_point.x, right_point.x) - 180.0
	_arena_right = maxf(left_point.x, right_point.x) + 180.0
	_arena_center = center_point
	_corruption_points = corruption_markers


func start_fight() -> void:
	if active or state == State.DEAD:
		return
	active = true
	visible = true
	# Right attack limit: 17660 in Santuario Profundo, 340px before the wall.
	global_position.x = _arena_right - ARENA_MARGIN
	state = State.INTRO
	_intro_emerged = false
	_face_player()
	_begin_intro_camera()
	velocity = Vector2.ZERO
	_play_animation(&"emerge_phase1", true)
	fight_started.emit()
	health_changed.emit(current_health, max_health)
	posture_changed.emit(successful_parries, parries_required)
	phase_changed.emit(phase)


func _physics_process(delta: float) -> void:
	if not active or state == State.DEAD:
		return
	_update_encounter_camera(delta)
	_state_time_left = maxf(_state_time_left - delta, 0.0)
	if state == State.ATTACK_ACTIVE and _current_attack in [Attack.BITE, Attack.BITE_DOUBLE]:
		velocity.x = _attack_direction * (BITE_SPEED_PHASE2 if phase == 2 else BITE_SPEED_PHASE1)
	elif state == State.IDLE and is_instance_valid(_player) and absf(_player.global_position.x - global_position.x) > 390.0:
		velocity.x = signf(_player.global_position.x - global_position.x) * 115.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, 1800.0 * delta)
	move_and_slide()
	global_position.x = clampf(global_position.x, _arena_left + ARENA_MARGIN, _arena_right - ARENA_MARGIN)

	match state:
		State.INTRO:
			if _intro_emerged and _state_time_left <= 0.0:
				_enter_idle(0.55)
		State.IDLE:
			if _state_time_left <= 0.0:
				_select_attack()
		State.ATTACK_RECOVERY:
			if _state_time_left <= 0.0:
				if _pending_second_bite:
					_pending_second_bite = false
					_double_bite_index = 1
					_start_bite(true)
				else:
					_enter_idle()
		State.STAGGER:
			if _state_time_left <= 0.0:
				_enter_idle()
		State.VULNERABLE:
			if _state_time_left <= 0.0:
				_end_vulnerability()


func _select_attack() -> void:
	state = State.SELECT_ATTACK
	var choices: Array[Attack] = [Attack.BITE, Attack.SWEEP, Attack.PROJECTILE]
	if phase == 2:
		choices.append(Attack.BITE_DOUBLE)
		choices.append(Attack.CORRUPTION)
	if _repeat_count >= 2:
		choices.erase(_last_attack)
	var selected: Attack = choices[_rng.randi_range(0, choices.size() - 1)]
	if selected == _last_attack:
		_repeat_count += 1
	else:
		_last_attack = selected
		_repeat_count = 1
	_current_attack = selected
	if debug_boss:
		print("Guardian attack: ", Attack.keys()[selected])
	match selected:
		Attack.BITE:
			_start_bite(false)
		Attack.BITE_DOUBLE:
			_double_bite_index = 0
			_start_bite(true)
		Attack.SWEEP:
			_start_sweep()
		Attack.PROJECTILE:
			_start_projectile()
		Attack.CORRUPTION:
			_start_corruption()


func _start_bite(is_double: bool) -> void:
	_perfect_parry_open = false
	_perfect_parry_confirmed = false
	_current_attack = Attack.BITE_DOUBLE if is_double else Attack.BITE
	_face_player()
	_attack_direction = _facing
	_attack_damage_done = false
	state = State.ATTACK_WINDUP
	parry_cue.visible = true
	_play_animation(&"bite_phase%d" % phase, true)


func _start_sweep() -> void:
	_current_attack = Attack.SWEEP
	_perfect_parry_open = false
	_perfect_parry_confirmed = false
	_face_player()
	_attack_damage_done = false
	state = State.ATTACK_WINDUP
	sweep_cue.visible = true
	_play_animation(&"sweep_phase%d" % phase, true)


func _start_projectile() -> void:
	_face_player()
	_projectile_spawned = false
	state = State.ATTACK_WINDUP
	_play_animation(&"projectile_phase%d" % phase, true)


func _start_corruption() -> void:
	state = State.ATTACK_WINDUP
	_play_animation(&"projectile_phase2", true)
	_spawn_vfx(CORRUPTION_FLASH_VFX, global_position + Vector2(_facing * 72.0, -42.0))
	projectile_audio.play()
	_projectile_spawned = true
	var available := [0, 1, 2]
	available.shuffle()
	var count := 2 if _rng.randf() < 0.55 else 1
	for index in count:
		_spawn_corruption_zone(available[index])


func _on_sprite_frame_changed() -> void:
	_stabilize_sprite_grounding()
	if state not in [State.ATTACK_WINDUP, State.ATTACK_ACTIVE]:
		return
	var animation := String(sprite.animation)
	if animation.begins_with("bite_"):
		if sprite.frame == 3:
			_open_perfect_parry_window(parry_cue.global_position)
		elif sprite.frame == 4:
			_perfect_parry_open = false
			bite_audio.play()
			state = State.ATTACK_ACTIVE
			parry_cue.visible = false
			_set_bite_active(true)
		elif sprite.frame >= 6:
			_set_bite_active(false)
	elif animation.begins_with("sweep_"):
		if sprite.frame == 1:
			_open_perfect_parry_window(global_position + Vector2(-_facing * 65.0, 58.0))
		elif sprite.frame == 2:
			_perfect_parry_open = false
			state = State.ATTACK_ACTIVE
			sweep_cue.visible = false
			_set_sweep_active(true)
		elif sprite.frame >= 5:
			_set_sweep_active(false)
	elif animation.begins_with("projectile_") and sprite.frame == 3 and not _projectile_spawned:
		_projectile_spawned = true
		projectile_audio.play()
		if _current_attack != Attack.CORRUPTION:
			_spawn_projectile()


func _on_sprite_animation_finished() -> void:
	if state == State.INTRO:
		_intro_emerged = true
		_state_time_left = INTRO_HOLD
		_play_animation(&"idle_phase1")
	elif state == State.PHASE_TRANSITION:
		_finish_phase_transition()
	elif state == State.DEAD:
		_finish_death()
	elif state in [State.ATTACK_WINDUP, State.ATTACK_ACTIVE]:
		_finish_attack()


func _finish_attack() -> void:
	_set_all_attack_hitboxes(false)
	parry_cue.visible = false
	sweep_cue.visible = false
	velocity.x = 0.0
	state = State.ATTACK_RECOVERY
	if _current_attack == Attack.BITE_DOUBLE and _double_bite_index == 0:
		_pending_second_bite = true
		_state_time_left = 0.28
	else:
		_pending_second_bite = false
		_state_time_left = _recovery_duration()


func _enter_idle(delay := -1.0) -> void:
	if not active or state == State.DEAD:
		return
	state = State.IDLE
	_current_attack = Attack.NONE
	_play_animation(&"idle_phase%d" % phase)
	var multiplier := phase2_attack_speed_multiplier if phase == 2 else phase1_attack_speed_multiplier
	_state_time_left = (delay if delay >= 0.0 else _rng.randf_range(attack_cooldown_min, attack_cooldown_max)) / maxf(multiplier, 0.1)


func stun(parried_enemy: Node2D = null) -> void:
	if not active or state == State.DEAD or parried_enemy != self:
		return
	if not _perfect_parry_confirmed or not _perfect_parry_open or not can_be_parried():
		return
	_attack_damage_done = true
	_set_all_attack_hitboxes(false)
	parry_cue.visible = false
	velocity = Vector2.ZERO
	_pending_second_bite = false
	_spawn_vfx(PARRY_SUCCESS_VFX, _parry_contact_position())
	if not _gain_posture_point():
		parry_audio.play()
		state = State.STAGGER
		_state_time_left = 0.36 + successful_parries * 0.08
		_play_animation(&"stagger_phase%d" % phase, true)


func _gain_posture_point() -> bool:
	successful_parries = mini(successful_parries + 1, parries_required)
	posture_changed.emit(successful_parries, parries_required)
	if successful_parries < parries_required:
		return false
	# Both paths use the original break presentation and vulnerability window.
	_set_all_attack_hitboxes(false)
	parry_cue.hide()
	sweep_cue.hide()
	velocity = Vector2.ZERO
	_pending_second_bite = false
	normal_hits_toward_posture = 0
	normal_hits_changed.emit(0, NORMAL_HITS_PER_POSTURE)
	posture_break_audio.play()
	_spawn_vfx(POSTURE_BREAK_VFX, global_position + Vector2(0.0, -62.0))
	_enter_vulnerable()
	return true


func _register_guard_hit() -> void:
	normal_hits_toward_posture += 1
	if normal_hits_toward_posture >= NORMAL_HITS_PER_POSTURE:
		normal_hits_toward_posture = 0
		if not _gain_posture_point():
			parry_audio.play()
	normal_hits_changed.emit(normal_hits_toward_posture, NORMAL_HITS_PER_POSTURE)


func _enter_vulnerable() -> void:
	state = State.VULNERABLE
	_state_time_left = vulnerable_duration
	hurt_box.monitorable = true
	_play_animation(&"vulnerable_phase%d" % phase)


func _end_vulnerability() -> void:
	hurt_box.monitorable = false
	successful_parries = 0
	normal_hits_toward_posture = 0
	normal_hits_changed.emit(0, NORMAL_HITS_PER_POSTURE)
	posture_changed.emit(0, parries_required)
	_enter_idle(0.55)


func take_damage(amount_or_target: Variant = 1, attack_damage: int = 1) -> void:
	if not active or state in [State.INTRO, State.PHASE_TRANSITION, State.DEAD]:
		return
	var damage := attack_damage
	if amount_or_target is Node and amount_or_target != self:
		return
	if amount_or_target is int:
		damage = maxi(amount_or_target, 0)
	if damage <= 0:
		return
	if state != State.VULNERABLE:
		# One connected swing counts once, even when its damage is doubled.
		_register_guard_hit()
		return
	current_health = maxi(current_health - damage, 0)
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		_die()
	elif phase == 1 and current_health <= ceili(max_health * phase2_health_threshold):
		_start_phase_transition()
	else:
		_flash_damage()


func _start_phase_transition() -> void:
	state = State.PHASE_TRANSITION
	hurt_box.monitorable = false
	_set_all_attack_hitboxes(false)
	successful_parries = 0
	normal_hits_toward_posture = 0
	normal_hits_changed.emit(0, NORMAL_HITS_PER_POSTURE)
	posture_changed.emit(0, parries_required)
	_phase_transition_done = false
	phase_transition_audio.play()
	_spawn_vfx(CORRUPTION_PULSE_VFX, global_position + Vector2(0.0, -56.0))
	_play_animation(&"transition", true)


func _finish_phase_transition() -> void:
	if _phase_transition_done or state != State.PHASE_TRANSITION:
		return
	_phase_transition_done = true
	phase = 2
	phase_changed.emit(phase)
	_set_phase_visuals()
	_enter_idle(0.7)


func _die() -> void:
	_restore_intro_camera(false)
	if state == State.DEAD:
		return
	state = State.DEAD
	death_audio.play()
	active = false
	velocity = Vector2.ZERO
	hurt_box.monitorable = false
	_set_all_attack_hitboxes(false)
	parry_cue.visible = false
	sweep_cue.visible = false
	_clear_temporary_attacks()
	collision_layer = 0
	collision_mask = 0
	body_collision.set_deferred("disabled", true)
	_set_death_visuals()
	_play_animation(&"death", true)


func _finish_death() -> void:
	if _death_finished:
		return
	_death_finished = true
	_spawn_vfx(CORRUPTION_PULSE_VFX, global_position + Vector2(0.0, -42.0))
	await get_tree().create_timer(0.75).timeout
	defeated.emit()
	fight_ended.emit()


func reset_boss_fight() -> void:
	_restore_intro_camera(false)
	_intro_emerged = false
	_stop_audio()
	_clear_temporary_attacks()
	global_position = _spawn_position
	velocity = Vector2.ZERO
	current_health = max_health
	phase = 1
	successful_parries = 0
	normal_hits_toward_posture = 0
	normal_hits_changed.emit(0, NORMAL_HITS_PER_POSTURE)
	state = State.IDLE
	active = false
	_current_attack = Attack.NONE
	_last_attack = Attack.NONE
	_repeat_count = 0
	_pending_second_bite = false
	_double_bite_index = 0
	_death_finished = false
	collision_layer = 4
	collision_mask = 1
	body_collision.set_deferred("disabled", false)
	hurt_box.monitorable = false
	_set_all_attack_hitboxes(false)
	parry_cue.visible = false
	sweep_cue.visible = false
	_set_phase_visuals()
	visible = false
	health_changed.emit(current_health, max_health)
	posture_changed.emit(0, parries_required)
	phase_changed.emit(1)
	fight_ended.emit()


func _spawn_projectile() -> void:
	if not is_instance_valid(_player):
		return
	var projectile := PROJECTILE_SCENE.instantiate() as GuardianCorruptionProjectile
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + Vector2(_facing * 90.0, -30.0)
	var target := _player.global_position + Vector2(0.0, -20.0)
	projectile.setup(target - projectile.global_position, projectile_damage, self)
	_spawned_projectiles.append(projectile)


func _spawn_corruption_zone(index: int) -> void:
	if index < 0 or index >= _corruption_points.size():
		return
	var zone := CORRUPTION_SCENE.instantiate() as GuardianCorruptionZone
	get_tree().current_scene.add_child(zone)
	zone.global_position = _corruption_points[index]
	zone.setup(corruption_damage, self)
	zone.finished.connect(_on_corruption_zone_finished)
	_spawned_zones.append(zone)


func _on_corruption_zone_finished(zone: GuardianCorruptionZone) -> void:
	_spawned_zones.erase(zone)


func _clear_temporary_attacks() -> void:
	for node in _spawned_projectiles:
		if is_instance_valid(node):
			if node.has_method("cancel_visuals"):
				node.call("cancel_visuals")
			node.queue_free()
	for node in _spawned_zones:
		if is_instance_valid(node):
			node.queue_free()
	for node in _spawned_vfx:
		if is_instance_valid(node):
			node.queue_free()
	_spawned_projectiles.clear()
	_spawned_zones.clear()
	_spawned_vfx.clear()


func _on_bite_hitbox_body_entered(body: Node2D) -> void:
	if state != State.ATTACK_ACTIVE or _attack_damage_done or body.name != "Player":
		return
	_attack_damage_done = true
	if body.has_method("take_damage"):
		body.take_damage(bite_damage, self)


func _on_sweep_hitbox_body_entered(body: Node2D) -> void:
	if state != State.ATTACK_ACTIVE or _attack_damage_done or body.name != "Player":
		return
	_attack_damage_done = true
	if body.has_method("take_damage"):
		body.take_damage(bite_damage, self)


func _set_bite_active(enabled: bool) -> void:
	bite_hitbox.set_deferred("monitoring", enabled)
	bite_hitbox.position.x = 90.0 * _facing


func _set_sweep_active(enabled: bool) -> void:
	sweep_hitbox.set_deferred("monitoring", enabled)


func _set_all_attack_hitboxes(enabled: bool) -> void:
	if not enabled:
		_perfect_parry_open = false
		_perfect_parry_confirmed = false
		sweep_cue.visible = false
	bite_hitbox.set_deferred("monitoring", enabled)
	sweep_hitbox.set_deferred("monitoring", enabled)


func _face_player() -> void:
	if not is_instance_valid(_player):
		return
	var direction := signf(_player.global_position.x - global_position.x)
	if not is_zero_approx(direction):
		_facing = direction
	sprite.flip_h = _facing < 0.0
	bite_hitbox.position.x = 90.0 * _facing
	parry_cue.position = Vector2((70.0 if phase == 2 else 65.0) * _facing, -12.0 if phase == 2 else -20.0)


func _recovery_duration() -> float:
	var base := 0.68
	if _current_attack == Attack.SWEEP:
		base = 0.76
	elif _current_attack in [Attack.PROJECTILE, Attack.CORRUPTION]:
		base = 0.62
	return base / (phase2_attack_speed_multiplier if phase == 2 else phase1_attack_speed_multiplier)


func _parry_contact_position() -> Vector2:
	if is_instance_valid(_player):
		return (global_position + _player.global_position) * 0.5 + Vector2(0.0, -34.0)
	return parry_cue.global_position


func _spawn_vfx(scene: PackedScene, world_position: Vector2) -> Node2D:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return null
	var vfx := scene.instantiate() as Node2D
	current_scene.add_child(vfx)
	vfx.global_position = world_position
	_spawned_vfx.append(vfx)
	vfx.tree_exited.connect(_on_spawned_vfx_exited.bind(vfx))

	return vfx

func _on_spawned_vfx_exited(vfx: Node) -> void:
	_spawned_vfx.erase(vfx)


func _flash_damage() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.45, 1.45, 1.45, 1.0), 0.06)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)


func _set_phase_visuals() -> void:
	sprite.scale = Vector2.ONE * (PHASE2_SCALE if phase == 2 else PHASE1_SCALE)
	sprite.modulate = Color.WHITE
	_stabilize_sprite_grounding()


func _set_death_visuals() -> void:
	sprite.scale = Vector2.ONE * DEATH_SCALE
	sprite.modulate = Color.WHITE


func _stabilize_sprite_grounding() -> void:
	if not sprite.sprite_frames.has_animation(sprite.animation):
		return
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame) as AtlasTexture
	if texture == null:
		return
	var cell := int(texture.region.size.x)
	var columns := texture.atlas.get_width() / cell
	var index := int(texture.region.position.y / cell) * int(columns) + int(texture.region.position.x / cell)
	var bases: Array = DEATH_BODY_BASE if sprite.animation == &"death" else (PHASE2_BODY_BASE if String(sprite.animation).ends_with("phase2") else PHASE1_BODY_BASE)
	var ground_y := body_collision.position.y + (body_collision.shape as RectangleShape2D).size.y * 0.5
	sprite.position.y = ground_y - (float(bases[index]) - cell * 0.5) * sprite.scale.y


func _play_animation(animation_name: StringName, restart := false) -> void:
	if restart or sprite.animation != animation_name:
		sprite.play(animation_name)
		_stabilize_sprite_grounding()


func _begin_intro_camera() -> void:
	if not is_instance_valid(_player):
		return
	_intro_camera = _player.get_node_or_null("Camera2D") as Camera2D
	if _intro_camera == null:
		return
	_intro_camera_offset = _intro_camera.offset
	_intro_camera_zoom = _intro_camera.zoom
	_encounter_framing = true
	_intro_camera_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_intro_camera_tween.tween_property(_intro_camera, "offset", _encounter_camera_offset(), 0.45)
	_intro_camera_tween.tween_property(_intro_camera, "zoom", _encounter_camera_zoom(), 0.45)


func _encounter_camera_offset() -> Vector2:
	return _intro_camera_offset + Vector2((global_position.x - _player.global_position.x) * 0.5, -60.0)


func _encounter_camera_zoom() -> Vector2:
	var span := absf(global_position.x - _player.global_position.x) + 340.0
	return Vector2.ONE * minf(_intro_camera_zoom.x, get_viewport_rect().size.x / maxf(span, 1.0))


func _update_encounter_camera(delta: float) -> void:
	if not _encounter_framing or not is_instance_valid(_intro_camera) or not is_instance_valid(_player):
		return
	if is_instance_valid(_intro_camera_tween) and _intro_camera_tween.is_running():
		return
	if state != State.INTRO and absf(global_position.x - _player.global_position.x) < 540.0:
		_restore_intro_camera(true)
		return
	_intro_camera.offset = _intro_camera.offset.lerp(_encounter_camera_offset(), minf(delta * 4.0, 1.0))
	_intro_camera.zoom = _intro_camera.zoom.lerp(_encounter_camera_zoom(), minf(delta * 4.0, 1.0))


func _restore_intro_camera(smooth: bool) -> void:
	_encounter_framing = false
	if not is_instance_valid(_intro_camera):
		return
	if is_instance_valid(_intro_camera_tween):
		_intro_camera_tween.kill()
	if smooth:
		_intro_camera_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_intro_camera_tween.tween_property(_intro_camera, "offset", _intro_camera_offset, 0.65)
		_intro_camera_tween.tween_property(_intro_camera, "zoom", _intro_camera_zoom, 0.65)
	else:
		_intro_camera.offset = _intro_camera_offset
		_intro_camera.zoom = _intro_camera_zoom


func _exit_tree() -> void:
	_restore_intro_camera(false)


func _configure_audio() -> void:
	bite_audio.stream = preload("res://assets/audio/sfx/boss/bite.wav")
	projectile_audio.stream = preload("res://assets/audio/sfx/boss/corruption_cast.wav")
	parry_audio.stream = preload("res://assets/audio/sfx/boss/posture_hit.wav")
	posture_break_audio.stream = preload("res://assets/audio/sfx/boss/posture_break.wav")
	phase_transition_audio.stream = preload("res://assets/audio/sfx/boss/phase_transition.wav")
	death_audio.stream = preload("res://assets/audio/sfx/boss/death.wav")
	for player in [bite_audio, projectile_audio, parry_audio, posture_break_audio, phase_transition_audio, death_audio]:
		player.bus = &"SFX"
	bite_audio.volume_db = 1.0
	projectile_audio.volume_db = 0.0
	parry_audio.volume_db = 1.0
	posture_break_audio.volume_db = 5.0
	phase_transition_audio.volume_db = 3.0
	death_audio.volume_db = 3.0


func _stop_audio() -> void:
	for player in [bite_audio, projectile_audio, parry_audio, posture_break_audio, phase_transition_audio, death_audio]:
		player.stop()


func _configure_animations() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_animation(frames, &"emerge_phase1", PHASE1_TEXTURE, 256, [0, 1, 2, 3, 4, 5], 6.0, false)
	_add_animation(frames, &"idle_phase1", PHASE1_TEXTURE, 256, [6, 7, 8, 9, 10, 11], 5.0, true)
	_add_animation(frames, &"bite_phase1", PHASE1_TEXTURE, 256, [12, 13, 14, 14, 15, 16, 17], 6.5, false)
	_add_animation(frames, &"projectile_phase1", PHASE1_TEXTURE, 256, [12, 13, 14, 15, 16, 17], 7.0, false)
	_add_animation(frames, &"sweep_phase1", PHASE1_TEXTURE, 256, [18, 19, 20, 21, 22, 23], 7.5, false)
	_add_animation(frames, &"stagger_phase1", PHASE1_TEXTURE, 256, [24, 25, 24], 9.0, false)
	_add_animation(frames, &"vulnerable_phase1", PHASE1_TEXTURE, 256, [25, 26, 25, 26], 7.0, true)
	_add_animation(frames, &"transition", PHASE1_TEXTURE, 256, [24, 25, 26, 27, 28, 29], 3.0, false)
	_add_animation(frames, &"idle_phase2", PHASE2_TEXTURE, 320, [0, 1, 2, 3, 4, 5], 6.0, true)
	_add_animation(frames, &"bite_phase2", PHASE2_TEXTURE, 320, [6, 7, 8, 8, 9, 10, 11], 8.5, false)
	_add_animation(frames, &"projectile_phase2", PHASE2_TEXTURE, 320, [6, 7, 8, 9, 10, 11], 9.0, false)
	_add_animation(frames, &"sweep_phase2", PHASE2_TEXTURE, 320, [12, 13, 14, 15, 16, 17], 10.0, false)
	_add_animation(frames, &"stagger_phase2", PHASE2_TEXTURE, 320, [4, 5, 4], 10.0, false)
	_add_animation(frames, &"vulnerable_phase2", PHASE2_TEXTURE, 320, [4, 5, 4, 5], 8.0, true)
	_add_animation(frames, &"death", DEATH_TEXTURE, 448, [0, 1, 2, 3, 4, 5, 6, 7], 5.0, false)
	sprite.sprite_frames = frames
	_set_phase_visuals()


func _add_animation(
	frames: SpriteFrames,
	animation_name: StringName,
	texture: Texture2D,
	cell_size: int,
	indices: Array,
	fps: float,
	loop: bool
) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loop)
	var columns := floori(float(texture.get_width()) / float(cell_size))
	var sequence_index := 0
	for frame_index: int in indices:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2i(
			(frame_index % columns) * cell_size,
			floori(float(frame_index) / float(columns)) * cell_size,
			cell_size,
			cell_size
		)
		var is_parry_cue_frame := (animation_name in [&"bite_phase1", &"bite_phase2"] and sequence_index == 3) or (animation_name in [&"sweep_phase1", &"sweep_phase2"] and sequence_index == 1)
		frames.add_frame(animation_name, atlas, PERFECT_PARRY_WINDOW_DURATION * fps if is_parry_cue_frame else 1.0)
		sequence_index += 1


func can_be_parried() -> bool:
	return active and state == State.ATTACK_WINDUP and _perfect_parry_open and _current_attack in [Attack.BITE, Attack.BITE_DOUBLE, Attack.SWEEP]


func is_parryable_windup() -> bool:
	# Used only to defer same-frame body contact so the input can resolve first.
	return active and state == State.ATTACK_WINDUP and _current_attack in [Attack.BITE, Attack.BITE_DOUBLE, Attack.SWEEP]


func try_perfect_parry(player: WayraPlayer) -> bool:
	if not _perfect_parry_open or _perfect_parry_confirmed or state != State.ATTACK_WINDUP or not can_be_parried():
		return false
	if not player.can_reach_parry(self, 250.0):
		return false
	_perfect_parry_confirmed = true
	return true


func _open_perfect_parry_window(point: Vector2) -> void:
	_perfect_parry_open = true
	_perfect_parry_confirmed = false
	var duration := sprite.sprite_frames.get_frame_duration(sprite.animation, sprite.frame) / (sprite.sprite_frames.get_animation_speed(sprite.animation) * absf(sprite.speed_scale))
	var flash := _spawn_vfx(PARRY_GLINT_VFX, point)
	if flash != null:
		flash.set_duration(duration)
