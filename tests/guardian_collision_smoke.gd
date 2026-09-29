extends Node2D
## Focused overlap and visual-debug test; run with Godot --debug-collisions.
const BOSS_SCENE := preload("res://scenes/bosses/GuardianSediento.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

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

func tick() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/guardian_collision_%s.png" % label)

func set_pose(animation: StringName, frame: int) -> void:
	boss.sprite.play(animation)
	boss.sprite.pause()
	boss.sprite.frame = frame
	boss._stabilize_sprite_grounding()

func run() -> void:
	GameState.reset_for_new_game()
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector2(100, 100)
	boss = BOSS_SCENE.instantiate()
	add_child(boss)
	boss.global_position = Vector2(640, 280)
	boss.configure_arena(player, Vector2(440, 280), Vector2(840, 280), Vector2(640, 280), [])
	player.attack_hit.connect(boss.take_damage)
	boss.set_physics_process(false)
	boss.visible = true
	boss.active = true
	boss.state = GuardianSediento.State.IDLE
	set_pose(&"idle_phase1", 0)
	check(boss.body_collision.position.y + boss.body_collision.shape.size.y * 0.5 == 100.0, "Grounding anchor remains at y=100")
	await capture("idle_phase1")
	GameState.heal_full()
	player.global_position = boss.global_position + Vector2(0, -140)
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)
	await get_tree().create_timer(0.55).timeout
	check(GameState.current_health < GameState.max_health, "Landing on the boss head triggers contact damage")
	player.set_physics_process(false)
	player.global_position = Vector2(100, 100)
	await tick()
	for sample in [[Vector2(-81, 60), "left"], [Vector2(81, 60), "right"], [Vector2(0, -65), "above"], [Vector2(0, 108), "below"]]:
		await contact(sample[0], true, sample[1])
	for sample in [[Vector2(-130, 0), "far left"], [Vector2(130, 0), "far right"], [Vector2(0, -100), "above head"], [Vector2(0, 145), "below body"]]:
		await contact(sample[0], false, sample[1])
	await vulnerable_hit(Vector2(-98, -35), true, "Head and upper body can be hit")
	await vulnerable_hit(Vector2(-200, -35), false, "Attack outside visible body misses")
	boss.state = GuardianSediento.State.ATTACK_WINDUP
	boss.hurt_box.monitorable = false
	set_pose(&"bite_phase1", 4)
	await capture("bite_phase1")
	await attack_contact(true, Vector2(115, 77), true, "Phase 1 bite touches grounded Wayra")
	await attack_contact(true, Vector2(170, 77), false, "Phase 1 bite misses beyond mouth range")
	set_pose(&"sweep_phase1", 2)
	await capture("sweep_phase1")
	await attack_contact(false, Vector2(120, 77), true, "Phase 1 sweep touches near telegraph")
	await attack_contact(false, Vector2(175, 77), false, "Phase 1 sweep misses beyond telegraph")
	boss.phase = 2
	boss._set_phase_visuals()
	boss.state = GuardianSediento.State.IDLE
	set_pose(&"idle_phase2", 0)
	await capture("idle_phase2")
	await contact(Vector2(-85, 60), true, "Phase 2 left coil")
	await contact(Vector2(85, 60), true, "Phase 2 right coil")
	await contact(Vector2(0, -65), true, "Phase 2 head")
	await vulnerable_hit(Vector2(-98, -35), true, "Phase 2 upper body can be hit")
	boss.state = GuardianSediento.State.ATTACK_WINDUP
	boss.hurt_box.monitorable = false
	set_pose(&"bite_phase2", 4)
	await capture("bite_phase2")
	await attack_contact(true, Vector2(-115, 77), true, "Phase 2 left-facing bite")
	set_pose(&"sweep_phase2", 2)
	await capture("sweep_phase2")
	await attack_contact(false, Vector2(-120, 77), true, "Phase 2 sweep")
	boss._set_all_attack_hitboxes(false)
	boss.state = GuardianSediento.State.VULNERABLE
	boss.hurt_box.monitorable = true
	set_pose(&"vulnerable_phase2", 0)
	await capture("vulnerable_phase2")
	boss._die()
	set_pose(&"death", 0)
	await capture("death")
	await tick()
	check(boss.collision_layer == 0 and boss.body_collision.disabled and boss.body_coil_collision.disabled and not boss.bite_hitbox.monitoring and not boss.sweep_hitbox.monitoring, "Death deactivates both body colliders and attacks")
	boss.reset_boss_fight()
	await tick()
	check(not boss.body_collision.disabled and not boss.body_coil_collision.disabled, "Retry restores both body colliders")
	print("GUARDIAN COLLISION RESULT: ", checks, " checks; ", failures.size(), " failures: ", failures)
	MusicManager.stop_music(0.0)
	await get_tree().create_timer(0.1, true).timeout
	get_tree().quit(0 if failures.is_empty() else 1)

func contact(offset: Vector2, should_hit: bool, label: String) -> void:
	boss.state = GuardianSediento.State.IDLE
	GameState.heal_full()
	player._damage_invulnerability_left = 0.0
	player.state = WayraPlayer.State.IDLE
	player.global_position = boss.global_position + offset
	await tick()
	await get_tree().create_timer(0.1).timeout
	check((GameState.current_health < GameState.max_health) == should_hit, label + " contact")
	player.global_position = Vector2(100, 100)
	await tick()

func vulnerable_hit(offset: Vector2, should_hit: bool, label: String) -> void:
	boss.active = true
	boss.state = GuardianSediento.State.VULNERABLE
	boss.hurt_box.monitorable = true
	boss.current_health = boss.max_health
	player.state = WayraPlayer.State.IDLE
	player.global_position = boss.global_position + offset
	player.facing = 1
	player._enter_attack()
	await tick()
	check((boss.current_health < boss.max_health) == should_hit, label)
	player.hit_box.monitoring = false
	player.global_position = Vector2(100, 100)
	await tick()

func attack_contact(bite: bool, offset: Vector2, should_hit: bool, label: String) -> void:
	boss.state = GuardianSediento.State.ATTACK_ACTIVE
	boss._attack_damage_done = false
	GameState.heal_full()
	player._damage_invulnerability_left = 0.0
	player.state = WayraPlayer.State.IDLE
	player.global_position = boss.global_position + offset
	boss._face_player()
	if bite:
		boss._set_bite_active(true)
	else:
		boss._set_sweep_active(true)
	await tick()
	check((GameState.current_health < GameState.max_health) == should_hit, label)
	boss._set_all_attack_hitboxes(false)
	player.global_position = Vector2(100, 100)
	await tick()
