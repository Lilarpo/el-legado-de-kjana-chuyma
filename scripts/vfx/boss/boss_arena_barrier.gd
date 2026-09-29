class_name BossArenaBarrier
extends Node2D

const ARCHITECTURE_TEXTURE := preload("res://assets/sprites/environment/orillas_lago/tiles/inca_back2.png")
const BLOCK_REGION := Rect2(0, 0, 16, 32)
const BARRIER_SFX := preload("res://assets/audio/sfx/environment/boss_barrier.wav")

@onready var architecture: Node2D = $Architecture
@onready var energy: Polygon2D = $Energy
@onready var seal_core: Polygon2D = $SealCore

var _transition: Tween
var _closed := false
var _audio: AudioStreamPlayer2D


func _ready() -> void:
	_audio = AudioStreamPlayer2D.new()
	_audio.bus = &"SFX"
	_audio.volume_db = -1.0
	_audio.stream = BARRIER_SFX
	add_child(_audio)
	_build_architecture()
	visible = false


func _process(_delta: float) -> void:
	if not visible:
		return
	var pulse := (sin(Time.get_ticks_msec() * 0.006) + 1.0) * 0.5
	energy.color.a = 0.48 + pulse * 0.22
	seal_core.rotation = Time.get_ticks_msec() * 0.00035
	seal_core.modulate.a = 0.66 + pulse * 0.24


func set_closed(closed: bool, immediate := false) -> void:
	var changed := closed != _closed
	_closed = closed
	if _transition != null and _transition.is_valid():
		_transition.kill()
	if immediate:
		visible = closed
		scale.y = 1.0 if closed else 0.05
		modulate.a = 1.0 if closed else 0.0
		return
	if changed:
		_audio.pitch_scale = 1.0 if closed else 0.88
		_audio.play()
	if closed:
		visible = true
		scale.y = 0.05
		modulate.a = 0.0
		_transition = create_tween().set_parallel(true)
		_transition.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_transition.tween_property(self, "scale:y", 1.0, 0.35)
		_transition.tween_property(self, "modulate:a", 1.0, 0.28)
	else:
		_transition = create_tween().set_parallel(true)
		_transition.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_transition.tween_property(self, "scale:y", 0.05, 0.3)
		_transition.tween_property(self, "modulate:a", 0.0, 0.24)
		_transition.chain().tween_callback(hide)


func _build_architecture() -> void:
	for y in range(-160, 161, 32):
		_add_block(Vector2(-22, y))
		_add_block(Vector2(22, y), true)


func _add_block(block_position: Vector2, flipped := false) -> void:
	var sprite := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = ARCHITECTURE_TEXTURE
	atlas.region = BLOCK_REGION
	sprite.texture = atlas
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = block_position
	sprite.flip_h = flipped
	sprite.modulate = Color(0.7, 0.9, 0.92, 1.0)
	architecture.add_child(sprite)
