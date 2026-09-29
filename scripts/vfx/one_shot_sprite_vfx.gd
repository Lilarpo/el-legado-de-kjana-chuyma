class_name OneShotSpriteVFX
extends Node2D

@export var sprite_sheet: Texture2D
@export var frame_size := Vector2i(32, 32)
@export_range(1, 64, 1) var frame_count := 1
@export_range(1, 32, 1) var columns := 1
@export_range(1.0, 60.0, 1.0) var frames_per_second := 16.0
@export var display_scale := Vector2.ONE
@export var tint := Color.WHITE

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	if sprite_sheet == null or frame_size.x <= 0 or frame_size.y <= 0:
		queue_free()
		return

	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"play")
	frames.set_animation_loop(&"play", false)
	frames.set_animation_speed(&"play", frames_per_second)
	for frame_index in frame_count:
		var frame := AtlasTexture.new()
		frame.atlas = sprite_sheet
		frame.region = Rect2i(
			(frame_index % columns) * frame_size.x,
			floori(float(frame_index) / float(columns)) * frame_size.y,
			frame_size.x,
			frame_size.y
		)
		frames.add_frame(&"play", frame)

	sprite.sprite_frames = frames
	sprite.scale = display_scale
	sprite.modulate = tint
	sprite.animation_finished.connect(queue_free)
	sprite.play(&"play")
