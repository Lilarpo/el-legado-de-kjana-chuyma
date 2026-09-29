class_name EnemyBase
extends CharacterBody2D

signal died

enum State {
	PATROL,
	STUNNED,
	DEAD, # FIXB
}

@export var max_health := 2
@export var speed := 60.0
@export var fall_limit_y := 800.0 # FIX2
@export var stompable := false # S3: enemigos pisables futuros — hoy NINGÚN enemigo es pisable (decisión de diseño, GDD no define stomp).

const GRAVITY := 980.0
const STUN_DURATION := 1.5

@onready var patrol_left: Marker2D = $PatrolLeft
@onready var patrol_right: Marker2D = $PatrolRight
@onready var hurt_box: Area2D = $HurtBox
@onready var damage_zone: Area2D = $DamageZone
@onready var stun_timer: Timer = $StunTimer

var current_health := max_health
var state := State.PATROL
var _patrol_left_position := Vector2.ZERO
var _patrol_right_position := Vector2.ZERO
var _target_position := Vector2.ZERO
var _initial_position := Vector2.ZERO # FIXB
var _initial_target_position := Vector2.ZERO # FIXB
var _initial_patrol_direction := 1.0 # FIXB
var _initial_state := State.PATROL # FIXB
var _initial_collision_layer := 0 # FIXB
var _initial_collision_mask := 0 # FIXB
var _initial_hurt_box_layer := 0 # FIXB
var _initial_hurt_box_mask := 0 # FIXB
var _initial_damage_zone_layer := 0 # FIXB
var _initial_damage_zone_mask := 0 # FIXB


func _ready() -> void:
	add_to_group("enemies") # FIXB
	_patrol_left_position = patrol_left.global_position
	_patrol_right_position = patrol_right.global_position
	_target_position = _patrol_right_position
	_initial_position = global_position # FIXB
	_initial_target_position = _target_position # FIXB
	_initial_patrol_direction = signf(_target_position.x - global_position.x) # FIXB
	_initial_state = state # FIXB
	_initial_collision_layer = collision_layer # FIXB
	_initial_collision_mask = collision_mask # FIXB
	_initial_hurt_box_layer = hurt_box.collision_layer # FIXB
	_initial_hurt_box_mask = hurt_box.collision_mask # FIXB
	_initial_damage_zone_layer = damage_zone.collision_layer # FIXB
	_initial_damage_zone_mask = damage_zone.collision_mask # FIXB
	stun_timer.timeout.connect(_on_stun_timer_timeout)


func _physics_process(delta: float) -> void:
	if state == State.DEAD: # FIXB
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if state == State.STUNNED:
		velocity.x = 0.0
	else:
		_patrol(delta)

	move_and_slide()
	if global_position.y > fall_limit_y: # FIX2
		_reset_after_fall() # FIX2


func _reset_after_fall() -> void: # FIX2
	if state == State.DEAD: # FIXB
		return
	global_position = _patrol_left_position # FIX2
	velocity = Vector2.ZERO # FIX2
	state = State.PATROL # FIX2
	_target_position = _patrol_right_position # FIX2
	damage_zone.monitoring = true # FIX2
	stun_timer.stop() # FIX2


func _patrol(delta: float) -> void:
	var distance_to_target := _target_position.x - global_position.x
	if absf(distance_to_target) <= 2.0:
		_target_position = _patrol_left_position if _target_position == _patrol_right_position else _patrol_right_position
		distance_to_target = _target_position.x - global_position.x

	velocity.x = move_toward(velocity.x, signf(distance_to_target) * speed, speed * 8.0 * delta)


func take_damage(amount_or_target: Variant = 1, attack_damage: int = 1) -> void:
	if state == State.DEAD:
		return
	var damage := attack_damage
	if amount_or_target is Node and amount_or_target != self:
		return
	if amount_or_target is int:
		damage = amount_or_target

	current_health = max(current_health - max(damage, 0), 0)
	if current_health == 0:
		died.emit()
		_set_dead_state() # FIXB


func _set_dead_state() -> void: # FIXB
	state = State.DEAD
	velocity = Vector2.ZERO
	stun_timer.stop()
	hurt_box.set_deferred("monitoring", false)
	damage_zone.set_deferred("monitoring", false)
	collision_layer = 0
	collision_mask = 0
	hurt_box.collision_layer = 0
	hurt_box.collision_mask = 0
	damage_zone.collision_layer = 0
	damage_zone.collision_mask = 0
	hide()


func restore_to_snapshot() -> void: # FIXB
	# S3: snapshots por checkpoint.
	global_position = _initial_position
	velocity = Vector2.ZERO
	current_health = max_health
	state = _initial_state
	_target_position = _patrol_right_position if _initial_patrol_direction >= 0.0 else _patrol_left_position
	collision_layer = _initial_collision_layer
	collision_mask = _initial_collision_mask
	hurt_box.collision_layer = _initial_hurt_box_layer
	hurt_box.collision_mask = _initial_hurt_box_mask
	damage_zone.collision_layer = _initial_damage_zone_layer
	damage_zone.collision_mask = _initial_damage_zone_mask
	hurt_box.set_deferred("monitoring", true)
	damage_zone.set_deferred("monitoring", true)
	show()


func stun(parried_enemy: Node2D = null) -> void:
	if state == State.DEAD: # FIXB
		return
	if parried_enemy != null and parried_enemy != self:
		return

	state = State.STUNNED
	velocity = Vector2.ZERO
	damage_zone.monitoring = false
	stun_timer.start(STUN_DURATION)


func _on_stun_timer_timeout() -> void:
	if state == State.DEAD: # FIXB
		return
	state = State.PATROL
	damage_zone.monitoring = true


func _on_damage_zone_body_entered(body: Node2D) -> void:
	if state == State.DEAD or state == State.STUNNED or body.name != "Player":
		return
	if body.has_method("take_damage"):
		body.take_damage(1, self)


func _on_hurt_box_area_entered(_area: Area2D) -> void:
	pass