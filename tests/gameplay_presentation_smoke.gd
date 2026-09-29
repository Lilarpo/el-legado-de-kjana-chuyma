extends Node

var checks := 0
var failures: Array[String] = []
var level: Node
var player: WayraPlayer
var boss: GuardianSediento
const LEVEL1 := "res://scenes/levels/level01_orillas_del_lago.tscn"
const MENU := "res://scenes/ui/main_menu.tscn"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	GameState.save_file_path = "user://presentation_smoke.cfg"
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", message)
	if not ok:
		failures.append(message)

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout

func load_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)
	await get_tree().scene_changed
	await get_tree().process_frame
	level = get_tree().current_scene
	player = level.get_node_or_null("Player")
	if player != null:
		player.set_physics_process(false)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png("/tmp/legado_%s.png" % label)

func press_key(key: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)

func close_reward() -> void:
	RewardOverlay.continue_button.pressed.emit()
	await wait(0.3)
	check(not RewardOverlay.visible and not get_tree().paused and not player.input_locked, "Reward closes and restores gameplay")

func run() -> void:
	GameState.reset_for_new_game()
	await load_scene(LEVEL1)
	var npc := level.get_node("NPCs/KjanaChuyma")
	npc._finale_dialogue_pending = true
	npc._on_dialogue_finished()
	check(GameState.unlocked_abilities.double_jump, "Double Jump granted before presentation")
	await wait(0.45)
	check(RewardOverlay.visible and RewardOverlay.title.text == "DOBLE SALTO" and get_tree().paused and player.input_locked, "Double Jump opens paused reward")
	await capture("reward_double_jump")
	var music_position: float = MusicManager._player.get_playback_position()
	press_key(KEY_ESCAPE)
	await wait(0.2)
	check(get_tree().paused and not level.get_node("PauseMenu/Overlay").visible, "Pause key cannot steal reward pause")
	check(MusicManager._player.playing and MusicManager._player.get_playback_position() > music_position, "Music continues while reward pauses gameplay")
	press_key(KEY_E)
	await wait(0.3)
	check(not get_tree().paused and not RewardOverlay.visible, "E confirms reward")
	npc._finale_dialogue_pending = true
	npc._on_dialogue_finished()
	await wait(0.1)
	check(not RewardOverlay.visible and RewardOverlay._queue.is_empty(), "Repeated dialogue does not repeat ability reward")
	var leaves := get_tree().get_nodes_in_group("hojas_coca")
	leaves[0]._on_body_entered(player)
	leaves[1]._on_body_entered(player)
	check(GameState.max_health == 3 and GameState.leaves_collected == 2, "Two coca leave existing upgrade rule intact")
	leaves[2]._on_body_entered(player)
	check(GameState.max_health == 4 and GameState.leaves_collected == 0 and level.get_node("HUD").hearts.get_child_count() == 4, "Third coca updates progress and HUD before modal")
	await wait(0.45)
	check(RewardOverlay.title.text == "NUEVO CORAZÓN" and RewardOverlay.icon.texture.resource_path.ends_with("heart_full.png"), "Heart reward reuses HUD icon")
	await capture("reward_heart")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	Input.parse_input_event(pad)
	pad = pad.duplicate()
	pad.pressed = false
	Input.parse_input_event(pad)
	await wait(0.3)
	check(not RewardOverlay.visible and not get_tree().paused, "Gamepad confirmation closes reward")
	if RewardOverlay._active:
		await close_reward()
	leaves[2]._on_body_entered(player)
	await wait(0.1)
	check(GameState.max_health == 4 and not RewardOverlay.visible, "Closing or duplicate pickup cannot duplicate heart")
	var altar := level.get_node("Checkpoint/Santuario_Orillas")
	altar._player_nearby = player
	altar._rest()
	check(GameState.has_valid_save(), "Checkpoint still saves after rewards")
	await cross_door("Transitions/LevelTransition_To_RuinasAncestrales", 2, "RUINAS ANCESTRALES")
	npc = level.get_node("NPCs/KjanaChuyma")
	npc._finale_dialogue_pending = true
	npc._on_dialogue_finished()
	check(GameState.unlocked_abilities.counterattack, "Counterattack granted before overlay")
	await wait(0.45)
	check(RewardOverlay.title.text == "CONTRAATAQUE", "Counterattack uses same reward scene")
	await capture("reward_counterattack")
	var touch := InputEventScreenTouch.new()
	touch.position = RewardOverlay.continue_button.get_global_rect().get_center()
	touch.pressed = true
	get_viewport().push_input(touch, true)
	touch = touch.duplicate()
	touch.pressed = false
	get_viewport().push_input(touch, true)
	await wait(0.3)
	check(not RewardOverlay.visible and not get_tree().paused, "Touch on Continue closes reward")
	if RewardOverlay._active:
		await close_reward()
	npc._finale_dialogue_pending = true
	npc._on_dialogue_finished()
	await wait(0.1)
	check(not RewardOverlay.visible, "Counterattack reward cannot repeat")
	await cross_door("Transitions/LevelTransition_To_SantuarioProfundo", 3, "SANTUARIO PROFUNDO")
	await test_boss()
	await load_scene(MENU)
	level.continue_button.pressed.emit()
	await get_tree().scene_changed
	await wait(0.15)
	level = get_tree().current_scene
	player = level.get_node("Player")
	player.set_physics_process(false)
	check(level.scene_file_path == LEVEL1 and GameState.max_health == 4 and GameState.unlocked_abilities.double_jump, "Saved checkpoint preserves earlier progress")
	check(not RewardOverlay.visible and RewardOverlay._queue.is_empty() and get_tree().root.get_node_or_null("LevelTitleCard") == null, "Continue shows neither old rewards nor title card")
	GameState.delete_save()
	print("PRESENTATION RESULT: ", checks, " checks; ", failures.size(), " failures: ", failures)
	MusicManager.stop_music(0.0)
	await wait(0.1)
	get_tree().current_scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)

func cross_door(path: String, number: int, heading: String) -> void:
	var labels := level.get_node("Transitions").find_children("*", "Label", true, false)
	check(labels.is_empty(), "Exit map name removed from world")
	level.get_node(path)._on_body_entered(player)
	await get_tree().scene_changed
	level = get_tree().current_scene
	player = level.get_node("Player")
	player.set_physics_process(false)
	var card := get_tree().root.get_node("LevelTitleCard") as LevelTitleCard
	check(card.backdrop.modulate.a == 1.0 and get_tree().paused, "New map loads fully covered by black")
	await wait(0.55)
	check(card.number_label.text == "MAPA %d" % number and card.name_label.text == heading and player.input_locked, "Correct title and locked movement for map %d" % number)
	await capture("title_map_%d" % number)
	var position := player.global_position
	Input.action_press("move_right")
	await wait(0.15)
	Input.action_release("move_right")
	check(player.global_position == position and get_tree().paused, "Player cannot move during title")
	await wait(2.2)
	check(not get_tree().paused and not player.input_locked and not is_instance_valid(card), "Title finishes and releases gameplay")
	var music_name := "ruinas_ancestrales.mp3" if number == 2 else "santuario_profundo.mp3"
	check(MusicManager._player.stream.resource_path.ends_with(music_name) and MusicManager._player.playing, "Destination music plays through existing manager")
	level._respawn_player()
	check(get_tree().root.get_node_or_null("LevelTitleCard") == null, "Respawn does not repeat title")

func reset_guard(phase: int = 1) -> void:
	boss.reset_boss_fight()
	boss.active = true
	boss.visible = true
	boss.phase = phase
	boss.state = GuardianSediento.State.IDLE
	boss._set_phase_visuals()
	boss.sprite.pause()
	player.global_position = boss.global_position + Vector2(-150, 0)
	player.facing = 1
	player.counterattack_ready = false
	level.boss_hud.show_fight()

func swing(counter: bool = false) -> void:
	player.counterattack_ready = counter
	player.state = WayraPlayer.State.ATTACK
	player._hit_targets.clear()
	player._register_attack_target(boss)
	player._register_attack_target(boss) # Duplicate body/area contacts in one swing.

func perfect() -> void:
	boss._start_bite(false)
	boss.sprite.pause()
	boss.sprite.frame = 3
	player.state = WayraPlayer.State.IDLE
	player._enter_parry()

func test_boss() -> void:
	boss = level.get_node("BossArena/GuardianSediento")
	boss.set_physics_process(false)
	reset_guard()
	player.global_position = boss.global_position + Vector2(-90, 45)
	player._enter_attack()
	await wait(0.08)
	check(boss.normal_hits_toward_posture == 1, "Real hitbox/body contact counts one guard hit")
	player.hit_box.monitoring = false
	for phase in [1, 2]:
		reset_guard(phase)
		for index in 3:
			swing()
		check(boss.normal_hits_toward_posture == 3 and boss.successful_parries == 0 and boss.current_health == 12, "P%d three connected swings = 3/4, no HP or posture damage" % phase)
		swing()
		check(boss.normal_hits_toward_posture == 0 and boss.successful_parries == 1, "P%d fourth swing = one posture point" % phase)
		for index in 4:
			swing()
		check(boss.successful_parries == 2, "P%d eight swings = two posture points" % phase)
		for index in 4:
			swing()
		check(boss.successful_parries == 3 and boss.state == GuardianSediento.State.VULNERABLE and boss._state_time_left == 4.0 and boss.current_health == 12, "P%d twelve swings reuse original four-second vulnerability" % phase)
		swing(true)
		check(boss.current_health == 10 and boss.normal_hits_toward_posture == 0 and boss.successful_parries == 3 and not player.counterattack_ready, "Vulnerability deals x2 damage without posture increments")
		boss._end_vulnerability()
		check(boss.successful_parries == 0 and boss.normal_hits_toward_posture == 0, "Recovery resets both counters")
		swing(true)
		check(boss.normal_hits_toward_posture == 1 and boss.current_health == 10, "Counterattack on guard counts once despite x2 damage")
		reset_guard(phase)
		perfect()
		check(boss.successful_parries == 1, "Perfect Parry still gives one posture point")
		for index in 4:
			swing()
		perfect()
		check(boss.state == GuardianSediento.State.VULNERABLE, "Perfect + four swings + Perfect breaks shared posture")
		reset_guard(phase)
		for index in 3:
			perfect()
		check(boss.successful_parries == 3 and boss.state == GuardianSediento.State.VULNERABLE, "Three Perfect Parries remain fastest route")
	reset_guard()
	boss._start_bite(false)
	boss.sprite.pause()
	player.state = WayraPlayer.State.IDLE
	player._enter_parry()
	boss.sprite.frame = 3
	player._on_parry_zone_body_entered(boss)
	check(boss.successful_parries == 0, "Holding Parry before flash still gives no posture")
	boss.state = GuardianSediento.State.IDLE
	swing()
	check(level.boss_hud.normal_hits_label.text == "GOLPES 1/4", "Boss HUD displays guard hit progress")
	player.camera.global_position = boss.global_position
	player.camera.reset_smoothing()
	await capture("boss_guard_hits")
	boss._start_phase_transition()
	check(boss.successful_parries == 0 and boss.normal_hits_toward_posture == 0, "Phase transition resets both counters")
	swing()
	check(boss.normal_hits_toward_posture == 0, "Phase transition rejects guard hits")
	boss.reset_boss_fight()
	check(boss.normal_hits_toward_posture == 0 and boss.successful_parries == 0, "Encounter reset clears all posture progress")
