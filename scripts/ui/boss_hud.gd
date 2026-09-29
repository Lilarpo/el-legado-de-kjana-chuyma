class_name BossHUD
extends CanvasLayer

@onready var panel: Control = $BossPanel
@onready var health_bar: ProgressBar = $BossPanel/HealthBar
@onready var phase_label: Label = $BossPanel/PhaseLabel
@onready var normal_hits_label: Label = $BossPanel/NormalHits
var _posture_feedback: Tween

@onready var posture_count: Label = $BossPanel/PostureCount
@onready var posture_pips: Array[TextureRect] = [
	$BossPanel/Posture/Pip1,
	$BossPanel/Posture/Pip2,
	$BossPanel/Posture/Pip3,
]


func _ready() -> void:
	panel.visible = false


func bind_boss(boss: GuardianSediento) -> void:
	boss.fight_started.connect(show_fight)
	boss.health_changed.connect(update_health)
	boss.phase_changed.connect(update_phase)
	boss.posture_changed.connect(update_posture)
	boss.normal_hits_changed.connect(update_normal_hits)
	boss.fight_ended.connect(hide_fight)
	update_health(boss.current_health, boss.max_health)
	update_phase(boss.phase)
	update_posture(boss.successful_parries, boss.parries_required)
	update_normal_hits(boss.normal_hits_toward_posture, boss.NORMAL_HITS_PER_POSTURE)


func show_fight() -> void:
	panel.visible = true


func hide_fight() -> void:
	panel.visible = false


func update_health(current: int, maximum: int) -> void:
	health_bar.max_value = maxi(maximum, 1)
	health_bar.value = clampi(current, 0, maxi(maximum, 1))


func update_phase(value: int) -> void:
	phase_label.text = "FASE %d" % value


func update_posture(current: int, required: int) -> void:
	if current > 0 and panel.visible:
		if is_instance_valid(_posture_feedback):
			_posture_feedback.kill()
		posture_count.modulate = Color(1.5, 1.25, 0.7)
		_posture_feedback = create_tween()
		_posture_feedback.tween_property(posture_count, "modulate", Color.WHITE, 0.3)
	posture_count.text = "%d/%d" % [current, required]
	for index in posture_pips.size():
		var pip := posture_pips[index]
		var is_filled := index < current
		pip.texture = pip.get_meta("filled_texture") if is_filled else pip.get_meta("empty_texture")
		pip.modulate = Color(0.34, 0.96, 1.0, 1.0) if is_filled else Color(0.28, 0.5, 0.54, 0.9)
		pip.visible = index < required


func update_normal_hits(current: int, required: int) -> void:
	normal_hits_label.text = "GOLPES %d/%d" % [current, required]
