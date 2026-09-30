extends CanvasLayer

@export var force_mobile_controls := false

const BUTTON_SIZES := {
	"LeftButton": 100.0, "RightButton": 100.0, "JumpButton": 100.0,
	"AttackButton": 100.0, "ParryButton": 106.0,
	"InteractButton": 82.0, "PotionButton": 78.0, "PauseButton": 50.0,
}
const BASE_CELL_SIZE := 443.5
const NORMAL_OPACITY := 0.8
const DIMMED_OPACITY := 0.4
const PRESSED_SCALE := 0.94

@onready var root: Control = $Root
@onready var interact_button: TouchScreenButton = $Root/InteractButton
@onready var potion_button: TouchScreenButton = $Root/PotionButton
@onready var pause_button: TouchScreenButton = $Root/PauseButton

var _player: WayraPlayer
var _buttons: Array[TouchScreenButton] = []
var _mouse_button: TouchScreenButton


func _ready() -> void:
	add_to_group("mobile_controls")
	_player = get_parent().get_node_or_null("Player") as WayraPlayer
	var enabled := force_mobile_controls or OS.get_name() == "Android" or DisplayServer.is_touchscreen_available()
	root.visible = enabled
	if not enabled:
		set_process(false)
		set_process_input(false)
		return
	for name in BUTTON_SIZES:
		var button := root.get_node(name) as TouchScreenButton
		_buttons.append(button)
		button.pressed.connect(_on_button_pressed.bind(button))
		button.released.connect(_on_button_released.bind(button))
	root.resized.connect(_layout_buttons)
	GameState.protection_changed.connect(_on_protection_changed)
	_layout_buttons()
	_on_protection_changed(GameState.protection_potions, GameState.protection_hits_remaining)
	_update_interact_button()
	_hide_keyboard_hints()


func _process(_delta: float) -> void:
	var gameplay_visible := not get_tree().paused and not GameState.death_screen_active
	gameplay_visible = gameplay_visible and is_instance_valid(_player) and not _player.input_locked
	var dialogue := get_parent().get_node_or_null("DialogueBox")
	if dialogue != null and dialogue.get("_active"):
		gameplay_visible = false
	root.visible = gameplay_visible
	if gameplay_visible:
		_update_interact_button()


func _layout_buttons() -> void:
	var viewport_size := root.size
	var margin := 36.0
	var bottom := viewport_size.y - margin - 50.0
	_set_button_position("LeftButton", Vector2(margin + 50.0, bottom))
	_set_button_position("RightButton", Vector2(margin + 176.0, bottom))
	_set_button_position("AttackButton", Vector2(viewport_size.x - margin - 180.0, bottom))
	_set_button_position("ParryButton", Vector2(viewport_size.x - margin - 53.0, bottom))
	_set_button_position("JumpButton", Vector2(viewport_size.x - margin - 116.0, bottom - 116.0))
	_set_button_position("InteractButton", Vector2(viewport_size.x - margin - 180.0, bottom - 230.0))
	_set_button_position("PotionButton", Vector2(viewport_size.x - margin - 53.0, bottom - 230.0))
	_set_button_position("PauseButton", Vector2(viewport_size.x - 24.0 - 25.0, 24.0 + 25.0))
	call_deferred("_align_hud_to_pause")


func _align_hud_to_pause() -> void:
	var hud := get_parent().get_node_or_null("HUD")
	if hud != null and hud.is_node_ready():
		hud.align_mobile_resources_to_pause(pause_button.position.y + BUTTON_SIZES["PauseButton"])


func _set_button_position(name: String, center: Vector2) -> void:
	var button := root.get_node(name) as TouchScreenButton
	button.position = center - Vector2.ONE * (BUTTON_SIZES[name] * 0.5)


func _on_protection_changed(potions: int, hits: int) -> void:
	potion_button.visible = potions > 0
	potion_button.modulate.a = DIMMED_OPACITY if hits > 0 else NORMAL_OPACITY


func _update_interact_button() -> void:
	var in_range := false
	for candidate in get_tree().get_nodes_in_group("mobile_interactables"):
		if candidate.has_method("is_player_in_interaction_range") and candidate.is_player_in_interaction_range(_player):
			in_range = true
			break
	interact_button.visible = in_range


func _hide_keyboard_hints() -> void:
	var hud := get_parent().get_node_or_null("HUD")
	if hud != null:
		hud.potion_button.hide()


func _on_button_pressed(button: TouchScreenButton) -> void:
	button.scale = Vector2.ONE * (BUTTON_SIZES[button.name] / BASE_CELL_SIZE) * PRESSED_SCALE
	button.modulate.a = DIMMED_OPACITY if button == potion_button and GameState.protection_hits_remaining > 0 else 0.95


func _on_button_released(button: TouchScreenButton) -> void:
	button.scale = Vector2.ONE * (BUTTON_SIZES[button.name] / BASE_CELL_SIZE)
	button.modulate.a = DIMMED_OPACITY if button == potion_button and GameState.protection_hits_remaining > 0 else NORMAL_OPACITY


func _input(event: InputEvent) -> void:
	# Mouse emulation is limited to the explicit PC debug mode. Real touch uses
	# TouchScreenButton's independent finger indices and InputMap actions.
	if not force_mobile_controls or not (event is InputEventMouseButton):
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		if not root.visible:
			return
		for button in _buttons:
			if not button.visible or button == potion_button and GameState.protection_hits_remaining > 0:
				continue
			var radius: float = BUTTON_SIZES[button.name] * 0.5
			if (button.position + Vector2.ONE * radius).distance_to(event.position) <= radius:
				_mouse_button = button
				_send_debug_action(button, true)
				break
	elif _mouse_button != null:
		_send_debug_action(_mouse_button, false)
		_mouse_button = null


func _send_debug_action(button: TouchScreenButton, pressed: bool) -> void:
	if pressed:
		button.scale = Vector2.ONE * (BUTTON_SIZES[button.name] / BASE_CELL_SIZE) * PRESSED_SCALE
	else:
		button.scale = Vector2.ONE * (BUTTON_SIZES[button.name] / BASE_CELL_SIZE)
	_send_action_event(button.action, pressed)


func _send_action_event(action: StringName, pressed: bool) -> void:
	var action_event := InputEventAction.new()
	action_event.action = action
	action_event.pressed = pressed
	action_event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(action_event)
