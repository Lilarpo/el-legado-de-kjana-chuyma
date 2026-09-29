extends Node

const MOVE_SFX := preload("res://assets/audio/sfx/ui/move.wav")
const ACCEPT_SFX := preload("res://assets/audio/sfx/ui/accept.wav")
const BACK_SFX := preload("res://assets/audio/sfx/ui/back.wav")

var _player: AudioStreamPlayer
var _last_move_time := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.name = "UIAudioPlayer"
	_player.bus = &"UI"
	_player.max_polyphony = 4
	add_child(_player)
	get_tree().node_added.connect(_on_node_added)
	_connect_buttons(get_tree().root)


func play_back() -> void:
	_play(BACK_SFX)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_connect_button(node)


func _connect_buttons(root: Node) -> void:
	if root is BaseButton:
		_connect_button(root)
	for child in root.get_children():
		_connect_buttons(child)


func _connect_button(button: BaseButton) -> void:
	if not button.focus_entered.is_connected(_on_button_focused):
		button.focus_entered.connect(_on_button_focused)
	if not button.mouse_entered.is_connected(_on_button_focused):
		button.mouse_entered.connect(_on_button_focused)
	var pressed_callback := _on_button_pressed.bind(button)
	if not button.pressed.is_connected(pressed_callback):
		button.pressed.connect(pressed_callback)


func _on_button_focused() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_move_time < 70:
		return
	_last_move_time = now
	_play(MOVE_SFX)


func _on_button_pressed(button: BaseButton) -> void:
	var normalized_name := String(button.name).to_lower()
	if "close" in normalized_name or "back" in normalized_name or "cancel" in normalized_name:
		play_back()
	else:
		_play(ACCEPT_SFX)


func _play(stream: AudioStream) -> void:
	_player.stream = stream
	_player.play()
