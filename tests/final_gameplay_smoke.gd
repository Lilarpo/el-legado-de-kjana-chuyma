extends Node2D
## Focused integration test for physical contact, projectile and ending transition.
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const SPECTER_SCENE := preload("res://scenes/enemies/espectro_sediento.tscn")
const CONDOR_SCENE := preload("res://scenes/enemies/CondorCorrompido.tscn")
const BOSS_SCENE := preload("res://scenes/bosses/GuardianSediento.tscn")
const PROJECTILE_SCENE := preload("res://scenes/bosses/GuardianCorruptionProjectile.tscn")
const LEVEL3 := "res://scenes/levels/level03_santuario_profundo.tscn"

var failures: Array[String] = []
var checks := 0
var arena: Node2D
var player: WayraPlayer
var _hold_target: Node2D
var _hold_offset := Vector2.ZERO


func check(ok: bool, description: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", description)
	if not ok:
		failures.append(description)


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png("/tmp/finalpass_%s.png" % label)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	call_deferred("run")


func _physics_process(_delta: float) -> void:
	if is_instance_valid(_hold_target) and is_instance_valid(player):
		player.global_position = _hold_target.global_position + _hold_offset
		player.velocity = Vector2.ZERO


func run() -> void:
	GameState.reset_for_new_game()
	arena = Node2D.new()
	arena.name = "ContactTestArena"
	get_tree().root.add_child(arena)
	get_tree().current_scene = arena
	player = PLAYER_SCENE.instantiate()
	arena.add_child(player)
	player.global_position = Vector2(100, 100)

	var specter: EspectroSediento = SPECTER_SCENE.instantiate()
	arena.add_child(specter)
	specter.global_position = Vector2(500, 300)
	specter.set_physics_process(false)
	await capture("specter")
	check(is_equal_approx(specter.sprite.scale.x / 2.25, 2.65 / 2.25), "Specter visual scale is +17.8%")
	check(specter.body_collision.shape.size == Vector2(34, 68) and specter.hurt_box.get_node("Collision").shape.size == Vector2(38, 72), "Specter body and hurtbox follow silhouette")
	for pair in [[Vector2(0, -66), "above"], [Vector2(29, -8), "side"], [Vector2(0, 44), "below"], [Vector2(-29, -56), "diagonal"]]:
		await check_contact(specter, pair[0], "Specter " + pair[1])
	_hold_target = null
	player.global_position = Vector2(100, 100)
	specter.queue_free()
	await get_tree().process_frame

	var condor: CondorCorrompido = CONDOR_SCENE.instantiate()
	arena.add_child(condor)
	condor.global_position = Vector2(500, 300)
	condor.spawn_position = condor.global_position
	condor.set_physics_process(false)
	await capture("condor")
	check(is_equal_approx(condor.sprite.scale.x / 1.5, 1.75 / 1.5), "Condor visual scale is +16.7%")
	check(condor.body_collision.shape.size == Vector2(64, 34) and condor.attack_hitbox.get_node("Collision").shape.size == Vector2(90, 54), "Condor body and attack hitbox follow silhouette")
	check(condor.detection_range_x == 384.0 and condor.detection_range_y == 276.0 and condor.attack_cooldown_min == 1.23 and condor.attack_cooldown_max == 2.05, "Condor detects farther and attacks more often")
	for pair in [[Vector2(0, -43), "above"], [Vector2(42, 0), "side"], [Vector2(0, 40), "below"], [Vector2(-40, -37), "diagonal"]]:
		await check_contact(condor, pair[0], "Condor " + pair[1])
	_hold_target = null
	player.global_position = Vector2(500 + 370, 300 + 120)
	await get_tree().physics_frame
	check(condor._can_detect_player(), "Condor sees player 370px horizontally away")
	player.global_position = condor.global_position + Vector2(80, 20)
	player.facing = -1.0
	condor._enter_state(CondorCorrompido.State.DIVE_WINDUP)
	condor._process_dive_windup(0.31)
	check(condor._perfect_flash_shown and condor.state == CondorCorrompido.State.DIVE_WINDUP and condor.try_perfect_parry(player), "Condor keeps visible perfect-parry telegraph before dive")
	condor.queue_free()
	await get_tree().process_frame

	var boss: GuardianSediento = BOSS_SCENE.instantiate()
	arena.add_child(boss)
	boss.global_position = Vector2(500, 300)
	boss.configure_arena(player, Vector2(100, 300), Vector2(900, 300), Vector2(500, 300), [])
	boss.set_physics_process(false)
	boss.visible = true
	boss.active = false
	boss.state = GuardianSediento.State.IDLE
	_hold_target = boss
	_hold_offset = Vector2(0, -86)
	GameState.heal_full()
	player._damage_invulnerability_left = 0.0
	await wait(0.15)
	check(GameState.current_health == GameState.max_health, "Inactive boss body cannot damage before encounter")
	_hold_target = null
	boss.active = true
	await check_contact(boss, Vector2(0, -65), "Guardian above")
	check(boss.successful_parries == 0 and not player.counterattack_ready, "Body contact never adds boss posture or counter charge")
	boss.state = GuardianSediento.State.VULNERABLE
	GameState.heal_full()
	player._damage_invulnerability_left = 0.0
	_hold_target = boss
	_hold_offset = Vector2(0, -86)
	await wait(0.15)
	check(GameState.current_health == GameState.max_health, "Guardian body is harmless during vulnerability")
	_hold_target = null
	player.global_position = Vector2(100, 100)
	boss.state = GuardianSediento.State.INTRO

	var projectile: GuardianCorruptionProjectile = PROJECTILE_SCENE.instantiate()
	arena.add_child(projectile)
	projectile.global_position = Vector2(400, 100)
	projectile.setup(Vector2.RIGHT, 1, boss)
	var initial_lifetime: float = projectile.lifetime
	await wait(0.12)
	await capture("projectile")
	check(projectile.global_position.x > 440 and projectile.lifetime < initial_lifetime and projectile.speed == 520.0, "Guardian energy ball keeps speed and lifetime")
	check(projectile.get_node_or_null("Core") != null and projectile.get_node_or_null("Collision") != null, "Energy ball keeps its visible core and collider")
	check(arena.find_children("*Trail*", "", true, false).is_empty(), "Energy ball creates no trail nodes")
	GameState.heal_full()
	player._damage_invulnerability_left = 0.0
	projectile._on_body_entered(player)
	check(GameState.current_health == GameState.max_health - 1, "Energy ball still deals one damage on impact")
	await get_tree().process_frame
	check(not is_instance_valid(projectile), "Energy ball still disappears on impact")

	GameState.reset_for_new_game()
	GameState.unlock_ability("double_jump")
	GameState.unlock_ability("counterattack")
	get_tree().change_scene_to_file(LEVEL3)
	await get_tree().scene_changed
	var level = get_tree().current_scene
	player = level.get_node("Player")
	var captured_types: Dictionary = {}
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var kind := "specter" if enemy is EspectroSediento else ("condor" if enemy is CondorCorrompido else "")
		if kind.is_empty() or captured_types.has(kind):
			continue
		captured_types[kind] = true
		enemy.set_physics_process(false)
		player.global_position = enemy.global_position + Vector2(-100, 0)
		player.set_physics_process(false)
		player.camera.reset_smoothing()
		await wait(0.1)
		await capture("world_" + kind)
		enemy.set_physics_process(true)
		if captured_types.size() == 2:
			break
	check(captured_types.has("specter") and captured_types.has("condor"), "Both resized enemies present in the decorated level")
	GameState.heal_full()
	boss = level.get_node("BossArena/GuardianSediento")
	check(level.get_node("Collectibles").find_children("*", "FragmentoLegado", true, false).is_empty(), "Fragment #3 is absent before boss death")
	player.global_position = level.get_node("BossArena/BossEncounterTrigger").global_position
	player.set_physics_process(false)
	level._on_boss_trigger_body_entered(player)
	await wait(0.8)
	check(MusicManager._player.stream.resource_path.ends_with("guardian_sediento.mp3"), "Boss music is active before definitive defeat")
	boss._die()
	check(boss.state == GuardianSediento.State.DEAD and not GameState.guardian_defeated, "Boss death animation begins before reward/finale")
	var deadline := Time.get_ticks_msec() + 5000
	while not GameState.guardian_defeated and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	check(GameState.guardian_defeated and is_instance_valid(level._fragment_3), "Fragment #3 appears only after complete boss death")
	check(not GameState.finale_triggered, "Ending waits for indispensable final fragment pickup")
	level._fragment_3._on_body_entered(player)
	check(GameState.final_fragment_collected and GameState.finale_triggered and player.input_locked, "Final fragment starts ending once and locks gameplay")
	check(not level.get_node("HUD").visible and not level.boss_hud.visible and not level.get_node("PauseMenu").visible, "Gameplay HUD and pause menu disappear before ending")
	level._on_fragment_collected(GameState.FINAL_FRAGMENT_ID)
	check(GameState.finale_triggered, "Repeated final-fragment signal cannot restart ending")
	await get_tree().scene_changed
	var ending = get_tree().current_scene
	check(ending.scene_file_path.ends_with("EndingSequence.tscn") and not get_tree().paused, "EndingSequence replaces gameplay once")
	check(ending.video is VideoStreamPlayer and ending.video.stream != null and ending.video.stream.resource_path.ends_with("ending_01_guardian.ogv"), "First ending video starts after boss death and final fragment")
	check(not MusicManager._player.playing, "Boss and gameplay music are stopped during the ending")
	ending.video.finished.emit()
	await wait(1.2)
	check(ending.title.modulate.a > 0.95 and ending.title.text == "FIN" and not ending.menu_button.visible, "FIN fades in alone on black")
	await wait(3.0)
	check(ending.video.stream != null and ending.video.stream.resource_path.ends_with("ending_02_epilogue.ogv") and ending.video.visible, "Epilogue begins automatically after FIN")
	ending.video.finished.emit()
	await wait(1.3)
	check(ending.title.modulate.a > 0.95 and ending.title.text == "CONTINUARÁ" and not ending.menu_button.visible, "CONTINUARÁ fades in alone on black")
	await capture("continuara")
	await wait(3.3)
	check(ending.menu_button.visible and ending.menu_button.text == "[ VOLVER AL MENÚ ]", "Return button appears after hold")
	ending.menu_button.pressed.emit()
	await get_tree().scene_changed
	await wait(0.8)
	check(get_tree().current_scene is MainMenu and not get_tree().paused and MusicManager._player.stream.resource_path.ends_with("main_menu.mp3"), "Return to Main Menu restores menu music and unpaused tree")
	print("FINAL GAMEPLAY RESULT: ", checks, " checks; ", failures.size(), " failures: ", failures)
	MusicManager.stop_music(0.0)
	await wait(0.1)
	get_tree().quit(0 if failures.is_empty() else 1)


func check_contact(enemy: Node2D, offset: Vector2, label: String) -> void:
	GameState.heal_full()
	player._damage_invulnerability_left = 0.0
	player.state = WayraPlayer.State.IDLE
	_hold_target = enemy
	_hold_offset = offset
	for frame in 4:
		await get_tree().physics_frame
	await wait(0.12)
	check(GameState.current_health == GameState.max_health - 1, label + " contact deals one damage")
	await wait(0.23)
	check(GameState.current_health == GameState.max_health - 1, label + " sustained contact respects i-frames")
	if label == "Specter above":
		await wait(0.45)
		check(GameState.current_health == GameState.max_health - 2, "Contact can damage again after i-frames expire")
	_hold_target = null
	player.global_position = Vector2(100, 100)
	await wait(0.76)
