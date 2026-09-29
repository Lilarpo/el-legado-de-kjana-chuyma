class_name GuardianCorruptionProjectile
extends Area2D

@export var speed := 520.0
@export var damage := 1
@export var lifetime := 4.0

var direction := Vector2.LEFT
var _finishing := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func setup(target_direction: Vector2, attack_damage: int, _source: Node2D) -> void:
	direction = target_direction.normalized()
	damage = attack_damage
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		_finish_projectile()


func cancel_visuals() -> void:
	# Boss reset still calls this compatibility hook.
	pass


func _finish_projectile() -> void:
	if _finishing:
		return
	_finishing = true
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return
	if body.has_method("take_damage"):
		body.take_damage(damage, self)
	_finish_projectile()
