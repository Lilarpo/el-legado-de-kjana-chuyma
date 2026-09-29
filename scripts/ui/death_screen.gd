extends CanvasLayer

@onready var overlay: ColorRect = $Overlay
@onready var content: Control = $Overlay/Center/Content
var _respawn: Callable
var _ready_to_continue := false


func _ready() -> void:
	hide()
	%ContinueButton.pressed.connect(_continue)
	%ExitButton.pressed.connect(_exit_to_menu)


func present(player: WayraPlayer, respawn_callback: Callable) -> void:
	if GameState.death_screen_active:
		return
	GameState.death_screen_active = true
	_respawn = respawn_callback
	_ready_to_continue = false
	player.begin_death()
	get_tree().paused = true
	overlay.modulate.a = 0.0
	content.hide()
	show()
	# Let the existing one-shot finish while the gameplay tree is paused.
	await get_tree().create_timer(0.5, true).timeout
	var fade := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(overlay, "modulate:a", 1.0, 0.6)
	await fade.finished
	content.show()
	_ready_to_continue = true
	%ContinueButton.grab_focus()


func _continue() -> void:
	if not _ready_to_continue:
		return
	_ready_to_continue = false
	if _respawn.is_valid():
		_respawn.call()
	hide()
	GameState.death_screen_active = false
	get_tree().paused = false


func _exit_to_menu() -> void:
	if not _ready_to_continue:
		return
	_ready_to_continue = false
	AudioSettings.save_settings()
	GameState.death_screen_active = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
