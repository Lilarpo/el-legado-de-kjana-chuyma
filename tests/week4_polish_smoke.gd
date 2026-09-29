extends Node
## Integration regression: real scenes/signals, scripted input and controlled combat frames.
## Run this scene in Godot, or with --headless. Screenshots go to /tmp when rendered.
var failures: Array[String] = []
var checks := 0
var level: Node
var player: WayraPlayer
var boss: GuardianSediento

func check(condition: bool, message: String) -> void:
	checks += 1
	print("PASS " if condition else "FAIL ", message)
	if not condition:
		failures.append(message)

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png("/tmp/week4_%s.png" % label)

func load_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().scene_changed
	await get_tree().process_frame
	level = get_tree().current_scene
	player = level.get_node_or_null("Player")
	if player:
		player.set_physics_process(false)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Keep this runner alive across the same scene transitions used by the game.
	get_tree().current_scene = null
	call_deferred("run")

func run() -> void:
	await load_scene("res://scenes/ui/main_menu.tscn")
	check(level is MainMenu, "Main Menu loads")
	level.get_node("%NewGameButton").pressed.emit()
	await get_tree().scene_changed
	level = get_tree().current_scene
	player = level.get_node("Player")
	player.set_physics_process(false)
	check(level.scene_file_path.ends_with("level01_orillas_del_lago.tscn"), "New game opens level 1")
	await test_pause()
	var leaves := get_tree().get_nodes_in_group("hojas_coca")
	check(leaves.size() == 3, "Level 1 has exactly three leaves")
	leaves[0]._on_body_entered(player)
	leaves[1]._on_body_entered(player)
	check(GameState.leaves_collected == 2 and GameState.max_health == 3, "Two leaves do not upgrade health")
	player.take_damage(1)
	leaves[2]._on_body_entered(player)
	check(GameState.leaves_collected == 0 and GameState.max_health == 4 and GameState.current_health == 3, "Third leaf consumes three and heals exactly the new heart")
	check(player.max_health == 4 and player.current_health == 3 and level.get_node("HUD").hearts.get_child_count() == 4, "Player and HUD synchronize immediately")
	leaves[2]._on_body_entered(player)
	check(GameState.max_health == 4 and GameState.leaves_collected == 0, "Duplicate pickup gives no extra progress")
	var npc = level.get_node("NPCs/KjanaChuyma")
	npc._finale_dialogue_pending = true
	npc._on_dialogue_finished()
	check(GameState.unlocked_abilities.double_jump, "Existing level 1 NPC unlocks Double Jump")
	await dismiss_rewards()
	await load_scene("res://scenes/levels/level02_ruinas_ancestrales.tscn")
	leaves = get_tree().get_nodes_in_group("hojas_coca")
	check(leaves.size() == 3, "Level 2 has exactly three leaves")
	leaves[0]._on_body_entered(player)
	check(GameState.leaves_collected == 1 and GameState.max_health == 4, "Fourth total leaf leaves remainder one")
	leaves[1]._on_body_entered(player)
	leaves[2]._on_body_entered(player)
	npc = level.get_node("NPCs/KjanaChuyma")
	npc._finale_dialogue_pending = true
	npc._on_dialogue_finished()
	check(GameState.unlocked_abilities.counterattack, "Existing level 2 NPC unlocks Counterattack")
	await dismiss_rewards()
	await load_scene("res://scenes/levels/level03_santuario_profundo.tscn")
	leaves = get_tree().get_nodes_in_group("hojas_coca")
	check(leaves.size() == 3, "Level 3 has exactly three leaves")
	for leaf in leaves:
		leaf._on_body_entered(player)
	check(GameState.max_health == 6 and GameState.heart_upgrades == 3 and GameState.leaves_collected == 0 and GameState.collected_leaf_ids.size() == 9, "Nine unique leaves grant exactly three hearts")
	await dismiss_rewards()
	var hazard = level.get_node("Hazards/SedBlanca_Hazard_01")
	check(hazard.get_node("Collision").shape != null and hazard.get_node("Visual/SpectralLayer").find_children("*Flame*", "", true, false).is_empty(), "Sed Blanca keeps collision and has no repeated flames")
	var health_before := GameState.current_health
	hazard._on_body_entered(player)
	check(GameState.current_health == health_before - 1, "Sed Blanca still damages Wayra")
	GameState.heal_full()
	player.global_position = hazard.global_position + Vector2(-300, -180)
	player.camera.reset_smoothing()
	await wait(0.15)
	await capture("sed_blanca")
	boss = level.get_node("BossArena/GuardianSediento")
	player.global_position = level.get_node("BossArena/BossEncounterTrigger").global_position
	player.global_position.y = 977.0
	level._on_boss_trigger_body_entered(player)
	check(boss.global_position.x == 17660.0 and boss.global_position.x - player.global_position.x > 900.0, "Boss starts at x17660, far right with 340px wall margin")
	await wait(1.2)
	check(boss.state == GuardianSediento.State.INTRO and not boss.bite_hitbox.monitoring, "Boss presentation delays attacks")
	await capture("boss_intro")
	boss.set_physics_process(false)
	boss.sprite.pause()
	await test_natural_flash_timing()
	await test_combat()
	await test_regular_enemies()
	boss._spawn_projectile()
	boss._spawn_corruption_zone(0)
	var temporary_nodes: Array = boss._spawned_projectiles.duplicate() + boss._spawned_zones.duplicate() + boss._spawned_vfx.duplicate()
	await test_death(false)
	await get_tree().process_frame
	check(boss.current_health == 12 and boss.phase == 1 and boss.successful_parries == 0 and not boss.active, "Boss retry restores full HP, phase 1, posture zero")
	check(boss._spawned_projectiles.is_empty() and boss._spawned_zones.is_empty() and boss._spawned_vfx.is_empty(), "Retry clears all tracked boss attacks/VFX")
	for node in temporary_nodes:
		check(not is_instance_valid(node), "Temporary boss node destroyed on retry")
	check(level.arena_gate.collision_layer == 0 and level.boss_trigger.monitoring, "Retry reopens gate and rearms encounter")
	check(GameState.max_health == 6 and GameState.collected_leaf_ids.size() == 9 and GameState.unlocked_abilities.counterattack, "Death preserves hearts, collected IDs and abilities")
	for leaf in leaves:
		leaf._on_body_entered(player)
	check(GameState.max_health == 6 and GameState.leaves_collected == 0, "Retry cannot farm collected leaves")
	player.global_position = level.get_node("BossArena/BossEncounterTrigger").global_position
	level._on_boss_trigger_body_entered(player)
	check(boss.active and boss.phase == 1 and boss.current_health == 12 and get_tree().get_nodes_in_group("boss").size() == 1, "Retry starts one fresh boss encounter")
	await wait(0.8) # Let the existing retry music crossfade finish.
	await test_death(true)
	check(get_tree().current_scene is MainMenu and not get_tree().paused and not GameState.death_screen_active, "Death Exit returns to unpaused Main Menu")
	await wait(0.8)
	check(MusicManager._player.stream.resource_path.ends_with("main_menu.mp3"), "Menu music restored after death exit")
	await load_scene("res://scenes/levels/level01_orillas_del_lago.tscn")
	var pause = level.get_node("PauseMenu")
	pause._set_paused(true)
	pause.get_node("%ExitButton").pressed.emit()
	await get_tree().scene_changed
	await wait(0.8)
	check(get_tree().current_scene is MainMenu and not get_tree().paused and MusicManager._player.stream.resource_path.ends_with("main_menu.mp3"), "Pause Exit returns to menu and changes music")
	print("WEEK4 RESULT: ", checks, " checks; ", failures.size(), " failures: ", failures)
	# Release the active audio playback before terminating the test process.
	MusicManager.stop_music(0.0)
	await wait(0.1)
	# Free the current scene before shutdown so ongoing scene tweens can cancel.
	get_tree().current_scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)

func test_pause() -> void:
	var pause = level.get_node("PauseMenu")
	for iteration in 2:
		var event := InputEventAction.new()
		event.action = &"pause"
		event.pressed = true
		Input.parse_input_event(event)
		await get_tree().process_frame
		event = InputEventAction.new()
		event.action = &"pause"
		event.pressed = false
		Input.parse_input_event(event)
		await wait(0.25)
		check(get_tree().paused and pause.overlay.visible and pause.can_process(), "Pause opens and processes input while paused")
		pause.get_node("%ResumeButton").pressed.emit()
		check(not get_tree().paused and not pause.overlay.visible, "Resume closes pause")
	pause._set_paused(true)
	await wait(0.25)
	await capture("pause")
	pause.get_node("%OptionsButton").pressed.emit()
	var panels: MenuPanels = pause.menu_panels
	check(panels.options_panel.visible and panels.can_process(), "Shared Options works during pause")
	var volumes := Vector3(AudioSettings.master_volume, AudioSettings.music_volume, AudioSettings.sfx_volume)
	panels.master_slider.value = 40
	panels.music_slider.value = 30
	panels.sfx_slider.value = 20
	check(is_equal_approx(AudioSettings.master_volume, 0.4) and is_equal_approx(AudioSettings.music_volume, 0.3) and is_equal_approx(AudioSettings.sfx_volume, 0.2), "All three sliders control existing AudioSettings")
	await capture("options")
	AudioSettings.set_master_volume(volumes.x)
	AudioSettings.set_music_volume(volumes.y)
	AudioSettings.set_sfx_volume(volumes.z)
	panels.close_options_button.pressed.emit()
	check(not panels.is_open() and get_tree().paused and pause.overlay.visible, "Options Back returns to Pause")
	pause.get_node("%ControlsButton").pressed.emit()
	check(panels.controls_panel.visible, "Shared Controls opens")
	await capture("controls")
	panels.close_controls_button.pressed.emit()
	check(not panels.is_open() and get_tree().paused, "Controls Back returns to Pause")
	await wait(0.7) # Complete the initial scene-music fade before comparing playback.
	var music = MusicManager._player
	var position: float = music.get_playback_position()
	await wait(0.4)
	print("Pause audio: ", music.playing, ", paused=", music.stream_paused, ", position=", position, " -> ", music.get_playback_position(), ", stream=", music.stream.resource_path)
	check(music.playing and not music.stream_paused and music.get_playback_position() > position, "Music advances during pause")
	check(pause.find_children("*Restart*", "", true, false).is_empty(), "Pause has no Restart button")
	pause.get_node("%ResumeButton").pressed.emit()

func prepare_attack(attack: int, phase: int) -> void:
	boss._set_all_attack_hitboxes(false)
	boss.active = true
	boss.phase = phase
	boss._set_phase_visuals()
	player.global_position = boss.global_position + Vector2(-150, 77)
	player.facing = 1
	player.state = WayraPlayer.State.IDLE
	if attack == GuardianSediento.Attack.SWEEP:
		boss._start_sweep()
	else:
		boss._start_bite(attack == GuardianSediento.Attack.BITE_DOUBLE)
	boss.sprite.pause()

func open_flash(attack: int) -> void:
	boss.sprite.frame = 1 if attack == GuardianSediento.Attack.SWEEP else 3

func test_combat() -> void:
	for phase in [1, 2]:
		boss.successful_parries = 0
		for attack in [GuardianSediento.Attack.BITE, GuardianSediento.Attack.SWEEP, GuardianSediento.Attack.BITE_DOUBLE]:
			prepare_attack(attack, phase)
			player.counterattack_ready = false
			var posture_before := boss.successful_parries
			player._enter_parry()
			open_flash(attack)
			player._on_parry_zone_body_entered(boss)
			check(boss.successful_parries == posture_before and not player.counterattack_ready, "P%d attack%d: early hold/contact cannot grant perfect" % [phase, attack])
			var flash = boss._spawned_vfx.back()
			var animation_duration: float = 4.0 / (36.0 * flash.get_node("Sprite").speed_scale)
			check(animation_duration >= 0.099 and animation_duration <= 0.16, "Flash covers actual pre-hit frame")
			var health_before := GameState.current_health
			player.take_damage(1, boss)
			check(GameState.current_health == health_before and boss.successful_parries == posture_before, "Normal block grants no posture")
			player.state = WayraPlayer.State.IDLE
			player._enter_parry()
			check(boss.successful_parries == posture_before + 1 and player.counterattack_ready, "P%d attack%d: press during flash grants exactly one posture and one charge" % [phase, attack])
			boss.stun(boss)
			check(boss.successful_parries == posture_before + 1, "Perfect confirmation cannot be reused")
		check(boss.state == GuardianSediento.State.VULNERABLE and boss.successful_parries == 3 and boss._state_time_left == 4.0, "Exactly third perfect opens four-second vulnerability")
		boss.current_health = 12
		player._enter_attack()
		check(player.counterattack_ready, "Whiff keeps counterattack charge")
		player._register_attack_target(boss)
		check(boss.current_health == 10 and not player.counterattack_ready, "First connecting counter deals x2 and consumes charge")
		player._enter_attack()
		player._register_attack_target(boss)
		check(boss.current_health == 9, "Next attack deals normal damage")
		boss._end_vulnerability()
		player.counterattack_ready = true
		player._enter_attack()
		player._register_attack_target(boss)
		check(boss.current_health == 9 and player.counterattack_ready and boss.successful_parries == 0, "Invulnerable hit preserves charge and posture recovers to zero")
	prepare_attack(GuardianSediento.Attack.BITE, 1)
	boss.sprite.frame = 4
	player.counterattack_ready = false
	player._enter_parry()
	check(boss.successful_parries == 0 and not player.counterattack_ready, "Late press after flash grants no perfect")
	prepare_attack(GuardianSediento.Attack.SWEEP, 1)
	open_flash(GuardianSediento.Attack.SWEEP)
	player.global_position.x -= 1000
	player._enter_parry()
	check(boss.successful_parries == 0 and not player.counterattack_ready, "Out-of-range flash cannot be parried")
	boss._set_all_attack_hitboxes(false)
	for attack in [GuardianSediento.Attack.PROJECTILE, GuardianSediento.Attack.CORRUPTION]:
		boss._current_attack = attack
		boss.state = GuardianSediento.State.ATTACK_WINDUP
		check(not boss.can_be_parried() and not boss.try_perfect_parry(player), "Projectile/hazard cannot grant perfect")
	boss.phase = 1
	boss.state = GuardianSediento.State.VULNERABLE
	boss.current_health = 7
	boss.take_damage(1)
	check(boss.state == GuardianSediento.State.PHASE_TRANSITION and not boss._perfect_parry_open, "Half HP transition clears parry window")
	boss._finish_phase_transition()
	check(boss.phase == 2, "Phase 2 still activates")
	boss.sprite.pause()
	await wait(0.25)
	var flashes_left := 0
	for node in boss._spawned_vfx:
		if is_instance_valid(node) and node.scene_file_path == "res://scenes/vfx/ParryFlash.tscn":
			flashes_left += 1
	check(flashes_left == 0, "Parry flashes self-destruct")

func test_death(exit_to_menu: bool) -> void:
	player.take_damage(GameState.max_health)
	var death = level.get_node("PauseMenu/DeathScreen")
	check(GameState.current_health == 0 and get_tree().paused and player.input_locked, "Zero HP stops gameplay immediately")
	var position := player.global_position
	var music_position: float = MusicManager._player.get_playback_position()
	await wait(1.25)
	check(death.visible and death.content.visible and is_equal_approx(death.overlay.modulate.a, 1.0), "MORISTE appears after animation and black fade")
	check(player.global_position == position and MusicManager._player.playing and MusicManager._player.get_playback_position() > music_position, "Gameplay stops while death music continues")
	await capture("death")
	if exit_to_menu:
		death.get_node("%ExitButton").pressed.emit()
		await get_tree().scene_changed
	else:
		death.get_node("%ContinueButton").pressed.emit()
		check(not get_tree().paused and not death.visible and not player.input_locked and player.current_health == GameState.max_health and player.global_position == GameState.last_checkpoint, "Continue uses checkpoint, restores control and full health")
		player.set_physics_process(false)

func test_natural_flash_timing() -> void:
	for phase in [1, 2]:
		for attack in [GuardianSediento.Attack.BITE, GuardianSediento.Attack.SWEEP, GuardianSediento.Attack.BITE_DOUBLE]:
			prepare_attack(attack, phase)
			boss._restore_intro_camera(false)
			player.camera.reset_smoothing()
			player.state = WayraPlayer.State.IDLE
			boss.sprite.play()
			var deadline := Time.get_ticks_msec() + 2000
			while not boss._perfect_parry_open and Time.get_ticks_msec() < deadline:
				await get_tree().process_frame
			check(boss._perfect_parry_open and boss.state == GuardianSediento.State.ATTACK_WINDUP, "Natural animation opens perfect window before hitbox")
			var opened := Time.get_ticks_msec()
			while boss._perfect_parry_open and Time.get_ticks_msec() < deadline:
				await get_tree().process_frame
			var elapsed := float(Time.get_ticks_msec() - opened) / 1000.0
			# Desktop rendering/capture can stall frames; measure wall time only headless.
			var timing_ok := DisplayServer.get_name() != "headless" or (elapsed >= 0.075 and elapsed <= 0.20)
			check(timing_ok and boss.state == GuardianSediento.State.ATTACK_ACTIVE, "Natural perfect window closes as hitbox activates (%.3fs)" % elapsed)
			boss.sprite.pause()
			boss._set_all_attack_hitboxes(false)
			await get_tree().process_frame
	# Capture a separate controlled pose so PNG readback cannot alter timing tests.
	prepare_attack(GuardianSediento.Attack.SWEEP, 1)
	open_flash(GuardianSediento.Attack.SWEEP)
	await capture("sweep_flash")
	boss._set_all_attack_hitboxes(false)
	GameState.heal_full()

func test_regular_enemies() -> void:
	var checked_types: Dictionary = {}
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var kind: String = enemy.get_script().resource_path
		if checked_types.has(kind):
			continue
		checked_types[kind] = true
		enemy.restore_to_snapshot()
		enemy.set_physics_process(false)
		player.counterattack_ready = true
		var before: int = enemy.current_health
		player._enter_attack()
		player._register_attack_target(enemy)
		check(enemy.current_health == maxi(before - 2, 0) and not player.counterattack_ready, "Counter damage reaches existing enemy: " + kind.get_file())
		if enemy.current_health > 0:
			enemy.set_physics_process(true)
			await wait(0.4) # Respect existing hurt invulnerability.
			enemy.set_physics_process(false)
			player._enter_attack()
			player._register_attack_target(enemy)
			check(enemy.current_health == maxi(before - 3, 0), "Existing enemy next hit deals normal damage")
		enemy.restore_to_snapshot()
		enemy.set_physics_process(true)
	check(checked_types.has("res://scripts/enemies/espectro_sediento.gd") and checked_types.has("res://scripts/enemies/condor_corrompido.gd"), "Both Espectro and Condor exercised")


func dismiss_rewards() -> void:
	# Integration setup now acknowledges the same reward modal as the player.
	await wait(0.4)
	while RewardOverlay._active or not RewardOverlay._queue.is_empty():
		if RewardOverlay._ready_to_confirm:
			RewardOverlay.continue_button.pressed.emit()
		await wait(0.4)
