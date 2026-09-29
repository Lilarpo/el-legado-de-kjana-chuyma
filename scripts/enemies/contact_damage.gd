extends Area2D
## Physical overlap damage. Attack hitboxes handle parry and never call this node.
@export var inactive_states := PackedInt32Array()
@export var contact_damage := 1
@export var require_active := false

@onready var source: Node2D = get_parent()


func _physics_process(_delta: float) -> void:
	if require_active and not bool(source.get("active")):
		return
	if inactive_states.has(int(source.get("state"))):
		return
	for body in get_overlapping_bodies():
		if body is WayraPlayer:
			body.take_damage(contact_damage, source, true)
