class_name GuardianCorruptionZone
extends Area2D

signal finished(zone: GuardianCorruptionZone)

@export var telegraph_duration := 0.8
@export var active_duration := 2.4
@export var damage := 1
@export var tick_interval := 0.75

const IMPACT_RISE_DURATION := 0.18
const DISAPPEAR_DURATION := 0.24
const IMPACT_SFX := preload("res://assets/audio/sfx/boss/ground_spike.wav")

enum ZoneState {
	TELEGRAPH,
	IMPACT,
	ACTIVE,
	DISAPPEAR,
}

@onready var ground_glow: Polygon2D = $GroundGlow
@onready var spikes: Array[Sprite2D] = [$SpikeLeft, $SpikeCenter, $SpikeRight]

var owner_boss: Node2D
var _state := ZoneState.TELEGRAPH
var _time_left := 0.0
var _tick_left := 0.0
var _audio: AudioStreamPlayer2D


func _ready() -> void:
	_audio = AudioStreamPlayer2D.new()
	_audio.bus = &"SFX"
	_audio.volume_db = 1.0
	_audio.stream = IMPACT_SFX
	add_child(_audio)
	monitoring = false
	_state = ZoneState.TELEGRAPH
	_time_left = telegraph_duration
	_set_spike_frame(0)


func setup(attack_damage: int, source: Node2D) -> void:
	damage = attack_damage
	owner_boss = source


func _physics_process(delta: float) -> void:
	_time_left -= delta
	match _state:
		ZoneState.TELEGRAPH:
			_update_telegraph()
			if _time_left <= 0.0:
				_begin_impact()
		ZoneState.IMPACT:
			_update_impact()
			if _time_left <= 0.0:
				_activate()
		ZoneState.ACTIVE:
			_tick_damage(delta)
			if _time_left <= 0.0:
				_begin_disappear()
		ZoneState.DISAPPEAR:
			_update_disappear()
			if _time_left <= 0.0:
				finished.emit(self)
				queue_free()


func _update_telegraph() -> void:
	var progress := 1.0 - clampf(_time_left / maxf(telegraph_duration, 0.001), 0.0, 1.0)
	_set_spike_frame(mini(floori(progress * 3.0), 2))
	ground_glow.color = Color(0.36, 0.94, 0.97, 0.18 + absf(sin(Time.get_ticks_msec() * 0.018)) * 0.35)


func _begin_impact() -> void:
	_state = ZoneState.IMPACT
	_audio.play()
	_time_left = IMPACT_RISE_DURATION
	_set_spike_frame(3)
	ground_glow.color = Color(0.78, 1.0, 0.98, 0.72)


func _update_impact() -> void:
	var progress := 1.0 - clampf(_time_left / IMPACT_RISE_DURATION, 0.0, 1.0)
	_set_spike_frame(3 if progress < 0.5 else 4)


func _activate() -> void:
	_state = ZoneState.ACTIVE
	_time_left = active_duration
	_tick_left = 0.0
	_set_spike_frame(5)
	ground_glow.color = Color(0.88, 1.0, 0.98, 0.88)
	monitoring = true


func _tick_damage(delta: float) -> void:
	_tick_left -= delta
	ground_glow.modulate.a = 0.84 + absf(sin(Time.get_ticks_msec() * 0.012)) * 0.16
	if _tick_left > 0.0:
		return
	_tick_left = tick_interval
	for body in get_overlapping_bodies():
		_damage_body(body)


func _begin_disappear() -> void:
	_state = ZoneState.DISAPPEAR
	_time_left = DISAPPEAR_DURATION
	monitoring = false
	_set_spike_frame(6)


func _update_disappear() -> void:
	var progress := 1.0 - clampf(_time_left / DISAPPEAR_DURATION, 0.0, 1.0)
	_set_spike_frame(6 if progress < 0.5 else 7)
	modulate.a = 1.0 - progress * 0.65


func _set_spike_frame(frame_index: int) -> void:
	for spike in spikes:
		spike.frame = frame_index


func _damage_body(body: Node2D) -> void:
	if body.name == "Player" and body.has_method("take_damage"):
		body.take_damage(damage, self)
