class_name MenuPanels
extends Control

signal closed

@onready var controls_panel: Control = %ControlsPanel
@onready var close_controls_button: Button = %CloseControlsButton
@onready var options_panel: Control = %OptionsPanel
@onready var close_options_button: Button = %CloseOptionsButton
@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SFXSlider
@onready var master_value: Label = %MasterValue
@onready var music_value: Label = %MusicValue
@onready var sfx_value: Label = %SFXValue

func _ready() -> void:
	controls_panel.hide()
	options_panel.hide()
	close_controls_button.pressed.connect(close_panels)
	close_options_button.pressed.connect(close_panels)
	master_slider.value_changed.connect(_on_master_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	_sync_audio_controls()


func open_options() -> void:
	controls_panel.hide()
	_sync_audio_controls()
	options_panel.show()
	master_slider.grab_focus()


func open_controls() -> void:
	options_panel.hide()
	controls_panel.show()
	close_controls_button.grab_focus()


func is_open() -> bool:
	return options_panel.visible or controls_panel.visible


func close_panels() -> void:
	if options_panel.visible:
		AudioSettings.save_settings()
	options_panel.hide()
	controls_panel.hide()
	closed.emit()


func _sync_audio_controls() -> void:
	master_slider.set_value_no_signal(AudioSettings.master_volume * 100.0)
	music_slider.set_value_no_signal(AudioSettings.music_volume * 100.0)
	sfx_slider.set_value_no_signal(AudioSettings.sfx_volume * 100.0)
	_update_volume_label(master_value, master_slider.value)
	_update_volume_label(music_value, music_slider.value)
	_update_volume_label(sfx_value, sfx_slider.value)


func _on_master_volume_changed(value: float) -> void:
	AudioSettings.set_master_volume(value / 100.0)
	_update_volume_label(master_value, value)


func _on_music_volume_changed(value: float) -> void:
	AudioSettings.set_music_volume(value / 100.0)
	_update_volume_label(music_value, value)


func _on_sfx_volume_changed(value: float) -> void:
	AudioSettings.set_sfx_volume(value / 100.0)
	_update_volume_label(sfx_value, value)


func _update_volume_label(label: Label, value: float) -> void:
	label.text = "%d%%" % roundi(value)

