extends CanvasLayer
## Presents rewards already applied by GameState; never grants progress itself.
signal opened(reward_title: String)
signal closed

const HEART := preload("res://assets/sprites/ui/hud/heart_full.png")
const ABILITIES := {
	"double_jump": ["DOBLE SALTO", "Wayra ahora puede realizar un segundo salto mientras está en el aire."],
	"counterattack": ["CONTRAATAQUE", "Después de un Parry Perfecto, el siguiente ataque conectado inflige el doble de daño."],
}

@onready var screen: Control = $Screen
@onready var panel: PanelContainer = $Screen/Center/Panel
@onready var category: Label = $Screen/Center/Panel/Content/Category
@onready var title: Label = $Screen/Center/Panel/Content/Title
@onready var description: Label = $Screen/Center/Panel/Content/Description
@onready var icon: TextureRect = $Screen/Center/Panel/Content/Icon
@onready var continue_button: Button = $Screen/Center/Panel/Content/Buttons/Continue

var _queue: Array[Dictionary] = []
var _active := false
var _ready_to_confirm := false
var _closing := false
var _fade: Tween
var _owner: WeakRef
var _player: Node2D
var _previous_input_lock := false


func _ready() -> void:
	hide()
	GameState.ability_unlocked.connect(_on_ability_unlocked)
	GameState.heart_upgraded.connect(_on_heart_upgraded)
	continue_button.pressed.connect(_close)


func _on_ability_unlocked(ability_id: String) -> void:
	if ABILITIES.has(ability_id):
		_enqueue("NUEVA HABILIDAD", ABILITIES[ability_id][0], ABILITIES[ability_id][1], null)


func _on_heart_upgraded(_maximum: int) -> void:
	_enqueue("VITALIDAD AUMENTADA", "NUEVO CORAZÓN", "La fuerza de Wayra ha aumentado. Has obtenido un corazón adicional.", HEART)


func _enqueue(kind: String, heading: String, details: String, texture: Texture2D) -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.get_node_or_null("Player") == null:
		return
	_queue.append({"owner": weakref(scene), "kind": kind, "title": heading, "description": details, "icon": texture})


func _process(_delta: float) -> void:
	if _active:
		if _owner.get_ref() != get_tree().current_scene:
			# A forced scene change must not carry a modal pause into the menu.
			_release()
		return
	if _queue.is_empty() or get_tree().paused or GameState.death_screen_active:
		return
	var reward := _queue[0]
	var scene := get_tree().current_scene
	if scene == null or reward["owner"].get_ref() != scene:
		_queue.pop_front()
		return
	var player := scene.get_node_or_null("Player") as Node2D
	if player == null or player.get("input_locked"):
		return
	_queue.pop_front()
	_show_reward(reward, player)


func _show_reward(reward: Dictionary, player: Node2D) -> void:
	_active = true
	_closing = false
	_ready_to_confirm = false
	_owner = reward["owner"]
	_player = player
	_previous_input_lock = player.get("input_locked")
	player.set("input_locked", true)
	get_tree().paused = true
	category.text = reward["kind"]
	title.text = reward["title"]
	description.text = reward["description"]
	icon.texture = reward["icon"]
	icon.visible = icon.texture != null
	continue_button.disabled = true
	screen.modulate.a = 0.0
	panel.scale = Vector2.ONE * 0.92
	show()
	await get_tree().process_frame
	panel.pivot_offset = panel.size * 0.5
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(screen, "modulate:a", 1.0, 0.3)
	_fade.tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _fade.finished
	if not _active:
		return
	_ready_to_confirm = true
	continue_button.disabled = false
	continue_button.grab_focus()
	opened.emit(title.text)


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventScreenTouch and event.pressed:
		if continue_button.get_global_rect().has_point(event.position):
			_close()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var pad_confirm: bool = event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A and event.pressed
		if not event.is_echo() and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or pad_confirm):
			_close()
		# Block PauseMenu and gameplay input; mouse/touch still reach the UI button.
		get_viewport().set_input_as_handled()


func _close() -> void:
	if not _active or not _ready_to_confirm or _closing:
		return
	_closing = true
	_ready_to_confirm = false
	continue_button.disabled = true
	_fade = create_tween()
	_fade.tween_property(screen, "modulate:a", 0.0, 0.2)
	await _fade.finished
	_release()


func _release() -> void:
	if is_instance_valid(_fade):
		_fade.kill()
	hide()
	if is_instance_valid(_player):
		_player.set("input_locked", _previous_input_lock)
	_active = false
	_closing = false
	_ready_to_confirm = false
	_player = null
	get_tree().paused = false
	closed.emit()
