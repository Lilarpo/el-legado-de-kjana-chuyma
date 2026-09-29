class_name MainMenu
extends Control

const NEW_GAME_SCENE := "res://scenes/levels/level01_orillas_del_lago.tscn"
const TRANSITION_DURATION := 0.45
const MENU_MUSIC := preload("res://assets/audio/music/main_menu.mp3")

@onready var new_game_button: Button = %NewGameButton
@onready var continue_button: Button = %ContinueButton
@onready var options_button: Button = %OptionsButton
@onready var controls_button: Button = %ControlsButton
@onready var quit_button: Button = %QuitButton
@onready var menu_panels: MenuPanels = $MenuPanels
@onready var fade_overlay: ColorRect = %FadeOverlay

var _transitioning := false


func _ready() -> void:
	get_tree().paused = false
	MusicManager.play_music(MENU_MUSIC, 0.6)
	continue_button.disabled = not GameState.has_valid_save()
	continue_button.focus_mode = Control.FOCUS_NONE if continue_button.disabled else Control.FOCUS_ALL
	fade_overlay.modulate.a = 0.0
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	options_button.pressed.connect(_open_options)
	controls_button.pressed.connect(_open_controls)
	quit_button.pressed.connect(_on_quit_pressed)
	menu_panels.closed.connect(_on_panels_closed)
	new_game_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and menu_panels.is_open():
		UIAudioManager.play_back()
		menu_panels.close_panels()
		get_viewport().set_input_as_handled()


func _on_new_game_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	_set_menu_enabled(false)
	MusicManager.stop_music(TRANSITION_DURATION)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(fade_overlay, "modulate:a", 1.0, TRANSITION_DURATION)
	await tween.finished
	if not GameState.delete_save():
		push_warning("No se pudo eliminar el guardado anterior.")
	GameState.reset_for_new_game()
	get_tree().change_scene_to_file(NEW_GAME_SCENE)


func _on_continue_pressed() -> void:
	if _transitioning or not GameState.load_save():
		continue_button.disabled = true
		continue_button.focus_mode = Control.FOCUS_NONE
		return
	_transitioning = true
	_set_menu_enabled(false)
	MusicManager.stop_music(TRANSITION_DURATION)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(fade_overlay, "modulate:a", 1.0, TRANSITION_DURATION)
	await tween.finished
	get_tree().change_scene_to_file(GameState.checkpoint_scene)


func _open_options() -> void:
	if _transitioning:
		return
	_set_menu_enabled(false)
	menu_panels.open_options()


func _open_controls() -> void:
	if _transitioning:
		return
	_set_menu_enabled(false)
	menu_panels.open_controls()


func _on_panels_closed() -> void:
	_set_menu_enabled(true)
	options_button.grab_focus()


func _on_quit_pressed() -> void:
	if _transitioning:
		return
	AudioSettings.save_settings()
	get_tree().quit()


func _set_menu_enabled(enabled: bool) -> void:
	continue_button.disabled = not enabled or not GameState.has_valid_save()
	new_game_button.disabled = not enabled
	options_button.disabled = not enabled
	controls_button.disabled = not enabled
	quit_button.disabled = not enabled
