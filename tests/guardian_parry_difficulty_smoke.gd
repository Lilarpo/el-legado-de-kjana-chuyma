extends Node2D

const BOSS_SCENE := preload("res://scenes/bosses/GuardianSediento.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const SPECTER_SCENE := preload("res://scenes/enemies/espectro_sediento.tscn")
const CONDOR_SCENE := preload("res://scenes/enemies/CondorCorrompido.tscn")

var failures: Array[String] = []
var checks := 0
var boss: GuardianSediento
var player: WayraPlayer

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures.append(label)

func prepare(attack: int, phase: int) -> void:
	boss._set_all_attack_hitboxes(false)
	boss.active = true
	boss.phase = phase
	boss._set_phase_visuals()
	boss.successful_parries = 0
	boss.normal_hits_toward_posture = 0
	boss.state = GuardianSediento.State.IDLE
	boss.global_position = Vector2(640, 280)
	player.global_position = boss.global_position + Vector2(-150, 77)
	player.facing = 1.0
	player.state = WayraPlayer.State.IDLE
	player._damage_invulnerability_left = 0.0
	player._guardian_contact_grace_left = 0.0
	GameState.heal_full()
	boss._player = player
	if attack == GuardianSediento.Attack.SWEEP:
		boss._start_sweep()
	else:
		boss._start_bite(attack == GuardianSediento.Attack.BITE_DOUBLE)
	boss.sprite.pause()

func cue_frame(attack: int) -> void:
	boss.sprite.frame = 1 if attack == GuardianSediento.Attack.SWEEP else 3

func active_frame(attack: int) -> void:
	boss.sprite.frame = 2 if attack == GuardianSediento.Attack.SWEEP else 4

func run() -> void:
	GameState.reset_for_new_game()
	GameState.unlock_ability("counterattack")
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.set_physics_process(false)
	boss = BOSS_SCENE.instantiate()
	add_child(boss)
	boss.set_physics_process(false)
	boss.get_node("ContactDamage").set_physics_process(false)
	boss.configure_arena(player, Vector2(440, 280), Vector2(840, 280), Vector2(640, 280), [])
	player.parry_success.connect(boss.stun)
	var specter: EspectroSediento = SPECTER_SCENE.instantiate()
	add_child(specter)
	specter.set_physics_process(false)
	specter.get_node("ContactDamage").set_physics_process(false)
	check(specter.detection_range == 315.0 and specter.max_chase_distance == 400.0 and specter.chase_speed == 84.0, "Specter detects and pursues farther")
	check(specter.attack_delay_min == 0.46 and specter.attack_delay_max == 1.08 and specter.attack_recovery_duration == 0.48 and specter.attack_windup_duration == 0.5, "Specter attacks more often without shortening telegraph")
	check(specter.max_health == 4, "Specter damage/health balance unchanged")
	var condor: CondorCorrompido = CONDOR_SCENE.instantiate()
	add_child(condor)
	condor.set_physics_process(false)
	condor.get_node("ContactDamage").set_physics_process(false)
	check(condor.detection_range_x == 442.0 and condor.detection_range_y == 320.0 and condor.dive_speed == 297.0, "Condor detection and dive speed increased moderately")
	check(condor.attack_cooldown_min == 1.08 and condor.attack_cooldown_max == 1.8 and condor.dive_recovery_duration == 0.35 and condor.dive_windup_duration == 0.45, "Condor repeats dives sooner with telegraph intact")
	check(condor.max_health == 3, "Condor health unchanged")
	for phase in [1, 2]:
		for attack in [GuardianSediento.Attack.BITE, GuardianSediento.Attack.SWEEP, GuardianSediento.Attack.BITE_DOUBLE]:
			prepare(attack, phase)
			player._enter_parry()
			check(boss.successful_parries == 0 and not boss._perfect_parry_open, "Holding before flash grants no perfect")
			player.state = WayraPlayer.State.IDLE
			cue_frame(attack)
			var frame_duration: float = boss.sprite.sprite_frames.get_frame_duration(boss.sprite.animation, boss.sprite.frame) / boss.sprite.sprite_frames.get_animation_speed(boss.sprite.animation)
			check(is_equal_approx(frame_duration, GuardianSediento.PERFECT_PARRY_WINDOW_DURATION) and boss._perfect_parry_open, "Flash and 0.22 s window open together")
			var flash: ParryFlash = boss._spawned_vfx.back()
			check(is_equal_approx(4.0 / (36.0 * flash.sprite.speed_scale), frame_duration), "Flash length matches the open window")
			player._enter_parry()
			check(boss.successful_parries == 1 and player.counterattack_ready and boss.state == GuardianSediento.State.STAGGER, "Immediate press gives one posture and counterattack")
			var hp := GameState.current_health
			player.take_damage(1, boss, true)
			check(GameState.current_health == hp and player._guardian_contact_grace_left == 0.2, "Perfect parry blocks immediate boss contact")
			boss._on_bite_hitbox_body_entered(player)
			boss._on_sweep_hitbox_body_entered(player)
			check(GameState.current_health == hp and not boss.bite_hitbox.monitoring and not boss.sweep_hitbox.monitoring, "Resolved attack cannot hit again")
	prepare(GuardianSediento.Attack.BITE, 1)
	cue_frame(GuardianSediento.Attack.BITE)
	player.global_position = boss.global_position + Vector2(-220, 77)
	Input.action_release("parry")
	await get_tree().process_frame
	Input.action_press("parry")
	player.global_position = boss.global_position + Vector2(-80, 40)
	var same_frame_hp := GameState.current_health
	player.take_damage(1, boss, true)
	check(GameState.current_health == same_frame_hp and boss.successful_parries == 0, "Same-frame body contact waits for parry input without awarding posture")
	player._enter_parry()
	check(GameState.current_health == same_frame_hp and boss.successful_parries == 1, "Parry input resolves before same-frame contact damage")
	Input.action_release("parry")
	prepare(GuardianSediento.Attack.BITE, 1)
	player._enter_parry()
	cue_frame(GuardianSediento.Attack.BITE)
	check(boss.successful_parries == 0, "Early held parry remains unsuccessful when flash starts")
	Input.action_release("parry")
	await get_tree().process_frame
	Input.action_press("parry")
	player._handle_state_input()
	check(boss.successful_parries == 1, "Fresh press during ongoing parry animation resolves within flash")
	Input.action_release("parry")
	prepare(GuardianSediento.Attack.BITE, 1)
	cue_frame(GuardianSediento.Attack.BITE)
	player.global_position = boss.global_position + Vector2(-220, 77)
	await get_tree().create_timer(0.1).timeout
	player._enter_parry()
	check(boss.successful_parries == 1 and GameState.current_health == GameState.max_health, "Mid-flash press still succeeds")
	prepare(GuardianSediento.Attack.BITE, 1)
	active_frame(GuardianSediento.Attack.BITE)
	player._enter_parry()
	check(boss.successful_parries == 0, "Late press gives no posture")
	boss._on_bite_hitbox_body_entered(player)
	check(GameState.current_health == GameState.max_health - 1, "Late parry does not prevent attack damage")
	prepare(GuardianSediento.Attack.SWEEP, 1)
	active_frame(GuardianSediento.Attack.SWEEP)
	boss._on_sweep_hitbox_body_entered(player)
	check(GameState.current_health == GameState.max_health - 1, "No parry allows sweep damage")
	prepare(GuardianSediento.Attack.BITE, 1)
	boss.state = GuardianSediento.State.IDLE
	player.take_damage(1, boss, true)
	check(GameState.current_health == GameState.max_health - 1, "Body contact still damages without parry")
	prepare(GuardianSediento.Attack.PROJECTILE, 1)
	boss._current_attack = GuardianSediento.Attack.PROJECTILE
	cue_frame(GuardianSediento.Attack.BITE)
	check(not boss.can_be_parried(), "Projectile remains non-parryable")
	print("PARRY DIFFICULTY RESULT: %d checks, %d failures: %s" % [checks, failures.size(), failures])
	MusicManager.stop_music(0.0)
	get_tree().quit(0 if failures.is_empty() else 1)
