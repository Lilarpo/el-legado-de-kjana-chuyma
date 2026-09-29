extends CanvasLayer

@onready var overlay: ColorRect = $Overlay
@onready var menu_panels: MenuPanels = $MenuPanels
var _fade: Tween


func _ready() -> void:
	overlay.hide()
	%ResumeButton.pressed.connect(_set_paused.bind(false))
	%OptionsButton.pressed.connect(_open_options)
	%ControlsButton.pressed.connect(_open_controls)
	%ExitButton.pressed.connect(_exit_to_menu)
	menu_panels.closed.connect(_focus_resume)


func _unhandled_input(event: InputEvent) -> void:
	if GameState.death_screen_active or not event.is_action_pressed("pause"):
		return
	if menu_panels.is_open():
		menu_panels.close_panels()
	else:
		_set_paused(not get_tree().paused)
	get_viewport().set_input_as_handled()


func _set_paused(should_pause: bool) -> void:
	if GameState.death_screen_active:
		return
	if is_instance_valid(_fade):
		_fade.kill()
	get_tree().paused = should_pause
	overlay.visible = should_pause
	if should_pause:
		overlay.modulate.a = 0.0
		_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_fade.tween_property(overlay, "modulate:a", 1.0, 0.2)
		_focus_resume()
	else:
		UIAudioManager.play_back()


func _open_options() -> void:
	$Overlay/Center.hide()
	menu_panels.open_options()


func _open_controls() -> void:
	$Overlay/Center.hide()
	menu_panels.open_controls()


func _focus_resume() -> void:
	$Overlay/Center.show()
	%ResumeButton.grab_focus()


func _exit_to_menu() -> void:
	AudioSettings.save_settings()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
