extends Control

const GUARDIAN_VIDEO := "res://assets/video/ending/ending_01_guardian.ogv"
const EPILOGUE_VIDEO := "res://assets/video/ending/ending_02_epilogue.ogv"
const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const VIDEO_FADE_TIME := 0.35
const FIN_FADE_IN_TIME := 0.65
const FIN_HOLD_TIME := 2.5
const FIN_FADE_OUT_TIME := 0.5
const CONTINUARA_FADE_IN_TIME := 0.85
const CONTINUARA_HOLD_TIME := 3.0

@onready var video: VideoStreamPlayer = $VideoFrame/Video
@onready var fade: ColorRect = $Fade
@onready var ending_text: Control = $EndingText
@onready var title: Label = $EndingText/Center/Content/Title
@onready var accent: ColorRect = $EndingText/Center/Content/Accent
@onready var menu_button: Button = $EndingText/Center/Content/MenuButton

var _stage := 0
var _returning_to_menu := false


func _ready() -> void:
	get_tree().paused = false
	MusicManager.stop_music(0.0)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	video.finished.connect(_on_video_finished)
	menu_button.pressed.connect(_return_to_menu)
	video.hide()
	ending_text.hide()
	menu_button.hide()
	accent.hide()
	fade.modulate.a = 1.0
	_start_video(1)


func _start_video(number: int) -> void:
	_stage = number
	var path := GUARDIAN_VIDEO if number == 1 else EPILOGUE_VIDEO
	if not ResourceLoader.exists(path, "VideoStream"):
		push_warning("No se encontró el video del final: %s" % path)
		_skip_missing_video(number)
		return
	var stream := load(path) as VideoStream
	if stream == null:
		push_warning("No se pudo cargar el video del final: %s" % path)
		_skip_missing_video(number)
		return
	video.stream = stream
	video.show()
	video.play()
	if not video.is_playing():
		push_warning("No se pudo reproducir el video del final: %s" % path)
		_clear_video()
		_skip_missing_video(number)
		return
	_fade_to(0.0, VIDEO_FADE_TIME)


func _skip_missing_video(number: int) -> void:
	if number == 1:
		_show_fin()
	else:
		_show_continuara()


func _on_video_finished() -> void:
	if _stage == 1:
		_show_fin()
	elif _stage == 2:
		_show_continuara()


func _show_fin() -> void:
	if _stage != 1:
		return
	_stage = 3
	await _fade_to(1.0, VIDEO_FADE_TIME)
	_clear_video()
	title.text = "FIN"
	title.modulate.a = 0.0
	ending_text.show()
	await _fade_title(1.0, FIN_FADE_IN_TIME)
	await get_tree().create_timer(FIN_HOLD_TIME).timeout
	await _fade_title(0.0, FIN_FADE_OUT_TIME)
	ending_text.hide()
	_start_video(2)


func _show_continuara() -> void:
	if _stage != 2:
		return
	_stage = 4
	await _fade_to(1.0, VIDEO_FADE_TIME)
	_clear_video()
	title.text = "CONTINUARÁ"
	title.modulate.a = 0.0
	ending_text.show()
	await _fade_title(1.0, CONTINUARA_FADE_IN_TIME)
	await get_tree().create_timer(CONTINUARA_HOLD_TIME).timeout
	accent.show()
	menu_button.modulate.a = 0.0
	menu_button.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await _fade_button()
	menu_button.grab_focus()


func _clear_video() -> void:
	video.stop()
	video.hide()
	video.stream = null


func _fade_to(alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", alpha, duration)
	await tween.finished


func _fade_title(alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(title, "modulate:a", alpha, duration)
	await tween.finished


func _fade_button() -> void:
	var tween := create_tween()
	tween.tween_property(menu_button, "modulate:a", 1.0, 0.35)
	await tween.finished


func _return_to_menu() -> void:
	if _returning_to_menu or _stage != 4 or not menu_button.visible:
		return
	_returning_to_menu = true
	_clear_video()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
