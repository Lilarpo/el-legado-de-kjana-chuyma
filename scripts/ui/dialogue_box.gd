extends CanvasLayer

signal dialogue_finished

@export_range(10.0, 100.0, 1.0) var characters_per_second := 38.0
@export_range(0.05, 0.5, 0.01) var transition_duration := 0.2
@export var warm_panel_style: StyleBoxFlat
@export var spiritual_panel_style: StyleBoxFlat
@export var warm_portrait_style: StyleBoxFlat
@export var spiritual_portrait_style: StyleBoxFlat

@onready var panel: PanelContainer = $PanelContainer
@onready var portrait_frame: PanelContainer = $PanelContainer/MarginContainer/Layout/PortraitFrame
@onready var portrait: TextureRect = $PanelContainer/MarginContainer/Layout/PortraitFrame/Portrait
@onready var speaker_name_label: Label = $PanelContainer/MarginContainer/Layout/DialogueContent/SpeakerName
@onready var dialogue_text: RichTextLabel = $PanelContainer/MarginContainer/Layout/DialogueContent/DialogueText
@onready var continue_indicator: Label = $PanelContainer/MarginContainer/Layout/DialogueContent/ContinueIndicator

const WARM_NAME_COLOR := Color(0.96, 0.76, 0.43, 1.0)
const WARM_INDICATOR_COLOR := Color(0.94, 0.66, 0.35, 1.0)
const SPIRITUAL_NAME_COLOR := Color(0.48, 0.9, 0.86, 1.0)
const SPIRITUAL_INDICATOR_COLOR := Color(0.58, 0.94, 0.9, 1.0)

var _dialogue: Array[String] = []
var _current_line := 0
var _player: Node2D
var _active := false
var _closing := false
var _is_typing := false
var _visible_character_progress := 0.0
var _line_character_count := 0
var _indicator_time := 0.0
var _transition_tween: Tween


func _ready() -> void:
	panel.hide()
	continue_indicator.hide()


func _process(delta: float) -> void:
	if not _active or _closing:
		return

	if _is_typing:
		_visible_character_progress += characters_per_second * delta
		var visible_count := mini(floori(_visible_character_progress), _line_character_count)
		dialogue_text.visible_characters = visible_count
		if visible_count >= _line_character_count:
			_complete_typewriter()
		return

	_indicator_time += delta
	continue_indicator.modulate.a = 0.78 + sin(_indicator_time * 4.0) * 0.18


func show_dialogue(
		dialogue: Array[String],
		speaker_name: String = "",
		portrait_texture: Texture2D = null,
		spiritual_accent := false
	) -> void:
	if dialogue.is_empty() or _active:
		return

	_dialogue = dialogue.duplicate()
	_current_line = 0
	_active = true
	_closing = false
	_player = _find_player()
	if _player != null:
		_player.set("input_locked", true)

	_apply_speaker_presentation(speaker_name, portrait_texture, spiritual_accent)
	panel.modulate.a = 0.0
	panel.show()
	_show_current_line()
	_start_fade(1.0)


func _unhandled_input(event: InputEvent) -> void:
	if not _active or _closing:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_advance_dialogue()
		get_viewport().set_input_as_handled()


func _on_panel_gui_input(event: InputEvent) -> void:
	if not _active or _closing:
		return
	var pressed: bool = (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	) or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		_advance_dialogue()
		get_viewport().set_input_as_handled()


func _show_current_line() -> void:
	var line := _dialogue[_current_line]
	dialogue_text.text = line
	_line_character_count = line.length()
	_visible_character_progress = 0.0
	dialogue_text.visible_characters = 0
	_is_typing = _line_character_count > 0
	continue_indicator.hide()
	_indicator_time = 0.0
	if not _is_typing:
		_complete_typewriter()


func _advance_dialogue() -> void:
	if _is_typing:
		dialogue_text.visible_characters = -1
		_complete_typewriter()
		return

	_current_line += 1
	if _current_line < _dialogue.size():
		_show_current_line()
		return

	_close_dialogue()


func _complete_typewriter() -> void:
	_is_typing = false
	dialogue_text.visible_characters = -1
	continue_indicator.modulate.a = 1.0
	continue_indicator.show()


func _close_dialogue() -> void:
	if _closing:
		return
	_closing = true
	continue_indicator.hide()
	_start_fade(0.0)
	await _transition_tween.finished
	if not is_inside_tree():
		return
	panel.hide()
	_release_player()
	_dialogue.clear()
	_active = false
	_closing = false
	dialogue_finished.emit()


func _apply_speaker_presentation(
		speaker_name: String,
		portrait_texture: Texture2D,
		spiritual_accent: bool
	) -> void:
	speaker_name_label.text = speaker_name.to_upper()
	portrait.texture = _extract_portrait_frame(portrait_texture)
	portrait.visible = portrait.texture != null

	if spiritual_accent:
		panel.add_theme_stylebox_override("panel", spiritual_panel_style)
		portrait_frame.add_theme_stylebox_override("panel", spiritual_portrait_style)
		speaker_name_label.add_theme_color_override("font_color", SPIRITUAL_NAME_COLOR)
		continue_indicator.add_theme_color_override("font_color", SPIRITUAL_INDICATOR_COLOR)
	else:
		panel.add_theme_stylebox_override("panel", warm_panel_style)
		portrait_frame.add_theme_stylebox_override("panel", warm_portrait_style)
		speaker_name_label.add_theme_color_override("font_color", WARM_NAME_COLOR)
		continue_indicator.add_theme_color_override("font_color", WARM_INDICATOR_COLOR)


func _extract_portrait_frame(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	if texture.get_width() >= texture.get_height() * 3 and texture.get_width() % 4 == 0:
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(0, 0, texture.get_width() / 4.0, texture.get_height())
		return frame
	return texture


func _start_fade(target_alpha: float) -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = create_tween()
	_transition_tween.set_trans(Tween.TRANS_QUAD)
	_transition_tween.set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(panel, "modulate:a", target_alpha, transition_duration)


func _find_player() -> Node2D:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return null
	var direct_player := current_scene.get_node_or_null("Player") as Node2D
	if direct_player != null:
		return direct_player
	return current_scene.find_child("Player", true, false) as Node2D


func _release_player() -> void:
	if is_instance_valid(_player):
		_player.set("input_locked", false)
	_player = null


func _exit_tree() -> void:
	_release_player()
