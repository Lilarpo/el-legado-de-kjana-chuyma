extends Node

const LEVEL_1 := "res://scenes/levels/level01_orillas_del_lago.tscn"
const LEVEL_2 := "res://scenes/levels/level02_ruinas_ancestrales.tscn"
const LEVEL_3 := "res://scenes/levels/level03_santuario_profundo.tscn"
const MENU := "res://scenes/ui/main_menu.tscn"
const TEST_SAVE := "user://checkpoint_save_smoke.cfg"

var failures: Array[String] = []
var checks := 0
var scene: Node
var player: WayraPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.save_file_path = TEST_SAVE
	get_tree().current_scene = null
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", message)
	if not ok:
		failures.append(message)


func load_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().scene_changed
	await get_tree().process_frame
	scene = get_tree().current_scene
	player = scene.get_node_or_null("Player")
	if player != null:
		player.set_physics_process(false)


func full_hearts(count: int) -> bool:
	var hearts: HBoxContainer = scene.get_node("HUD").hearts
	if hearts.get_child_count() < count:
		return false
	for index in count:
		var heart: TextureRect = hearts.get_child(index)
		if not heart.visible or heart.texture != heart.get_meta("full_texture"):
			return false
	return true


func die_and_continue(expected_health: int) -> void:
	GameState.take_damage(100)
	await get_tree().create_timer(1.4, true).timeout
	var death_screen: CanvasLayer = scene.get_node("PauseMenu/DeathScreen")
	death_screen.get_node("%ContinueButton").pressed.emit()
	await get_tree().process_frame
	check(not get_tree().paused and GameState.current_health == expected_health and GameState.max_health == expected_health and player.current_health == expected_health and player.max_health == expected_health, "DeathScreen Continue restores %d/%d" % [expected_health, expected_health])
	check(full_hearts(expected_health), "HUD displays %d full hearts after death" % expected_health)


func run() -> void:
	var mode := OS.get_cmdline_user_args()
	if mode.has("write"):
		await write_first_checkpoint()
	elif mode.has("read_one"):
		await read_first_and_write_second()
	elif mode.has("read_two"):
		await read_second_and_finish()
	elif mode.has("write_three"):
		await write_third_checkpoint()
	elif mode.has("read_three"):
		await read_third_and_retry_boss()
	else:
		check(false, "Test mode required")
	print("CHECKPOINT RESULT: ", checks, " checks; ", failures.size(), " failures: ", failures)
	MusicManager.stop_music(0.0)
	await get_tree().create_timer(0.1, true).timeout
	if is_instance_valid(get_tree().current_scene):
		get_tree().current_scene.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)


func write_first_checkpoint() -> void:
	GameState.delete_save()
	GameState.reset_for_new_game()
	await load_scene(LEVEL_1)
	for leaf: HojaCoca in get_tree().get_nodes_in_group("hojas_coca"):
		leaf._on_body_entered(player)
	GameState.unlock_ability("double_jump")
	GameState.register_fragment_collected("fragmento_orillas_del_lago_01")
	GameState.take_damage(2)
	var altar: Altar = scene.get_node("Checkpoint/Santuario_Orillas")
	altar._player_nearby = player
	altar._rest()
	check(GameState.max_health == 4 and GameState.current_health == 4, "Altar heals upgraded life before saving")
	check(GameState.has_valid_save() and GameState.checkpoint_id == "Checkpoint/Santuario_Orillas", "Level 1 altar creates valid save with ID")
	check(full_hearts(4), "HUD shows four full hearts at altar")


func read_first_and_write_second() -> void:
	await load_scene(MENU)
	check(not scene.continue_button.disabled, "Continue enabled after process restart")
	scene.continue_button.pressed.emit()
	await get_tree().scene_changed
	await get_tree().process_frame
	scene = get_tree().current_scene
	player = scene.get_node("Player")
	player.set_physics_process(false)
	var altar: Altar = scene.get_node("Checkpoint/Santuario_Orillas")
	check(scene.scene_file_path == LEVEL_1 and player.global_position == altar.global_position, "Continue restores level 1 altar position")
	check(GameState.max_health == 4 and GameState.current_health == 4 and full_hearts(4), "Continue restores four full hearts and HUD")
	check(GameState.unlocked_abilities.double_jump and GameState.fragments_collected.has("fragmento_orillas_del_lago_01") and GameState.collected_leaf_ids.size() == 3, "Continue restores abilities and unique collectible IDs")
	check(get_tree().get_nodes_in_group("hojas_coca").all(func(leaf: HojaCoca) -> bool: return leaf._is_collected), "Collected leaves stay unavailable after loading")
	await die_and_continue(4)
	await load_scene(LEVEL_2)
	for leaf: HojaCoca in get_tree().get_nodes_in_group("hojas_coca"):
		leaf._on_body_entered(player)
	GameState.unlock_ability("counterattack")
	GameState.register_fragment_collected("fragmento_ruinas_ancestrales_02")
	altar = scene.get_node("Checkpoint/Santuario_Ruinas")
	altar._player_nearby = player
	altar._rest()
	check(GameState.max_health == 5 and GameState.current_health == 5 and GameState.has_valid_save(), "Level 2 altar saves five full hearts")


func read_second_and_finish() -> void:
	await load_scene(MENU)
	check(not scene.continue_button.disabled, "Continue enabled for level 2 save")
	scene.continue_button.pressed.emit()
	await get_tree().scene_changed
	await get_tree().process_frame
	scene = get_tree().current_scene
	player = scene.get_node("Player")
	player.set_physics_process(false)
	var altar: Altar = scene.get_node("Checkpoint/Santuario_Ruinas")
	check(scene.scene_file_path == LEVEL_2 and player.global_position == altar.global_position, "Continue restores level 2 altar")
	check(GameState.max_health == 5 and GameState.current_health == 5 and full_hearts(5), "Continue restores five full hearts")
	check(GameState.unlocked_abilities.double_jump and GameState.unlocked_abilities.counterattack and GameState.fragments_collected.size() == 2 and GameState.collected_leaf_ids.size() == 6, "Progress persists across second restart")
	await die_and_continue(5)
	for id: String in ["santuario_hoja_01_descenso", "santuario_hoja_02_camara_combate", "santuario_hoja_03_ruta_extrema"]:
		GameState.register_leaf_collected(id)
	await die_and_continue(6)
	await load_scene(MENU)
	scene.new_game_button.pressed.emit()
	await get_tree().scene_changed
	await get_tree().process_frame
	scene = get_tree().current_scene
	check(scene.scene_file_path == LEVEL_1 and GameState.max_health == 3 and GameState.current_health == 3 and GameState.collected_leaf_ids.is_empty() and GameState.fragments_collected.is_empty() and not GameState.unlocked_abilities.double_jump and not GameState.has_valid_save(), "New Game clears save and all progress")
	var broken := ConfigFile.new()
	broken.set_value("checkpoint", "scene", "res://missing.tscn")
	broken.save(TEST_SAVE)
	await load_scene(MENU)
	check(scene.continue_button.disabled, "Invalid or incomplete save disables Continue")
	GameState.delete_save()


func write_third_checkpoint() -> void:
	GameState.delete_save()
	GameState.reset_for_new_game()
	for id: String in [
		"orillas_hoja_01_entrada", "orillas_hoja_02_camino_secundario", "orillas_hoja_03_sed_blanca",
		"ruinas_hoja_01_ruta_superior", "ruinas_hoja_02_plataforma_oculta", "ruinas_hoja_03_profundidades",
		"santuario_hoja_01_descenso", "santuario_hoja_02_camara_combate", "santuario_hoja_03_ruta_extrema",
	]:
		GameState.register_leaf_collected(id)
	GameState.unlock_ability("double_jump")
	GameState.unlock_ability("counterattack")
	GameState.register_fragment_collected("fragmento_orillas_del_lago_01")
	GameState.register_fragment_collected("fragmento_ruinas_ancestrales_02")
	await load_scene(LEVEL_3)
	var altar: Altar = scene.get_node("Checkpoint/Santuario_Profundo")
	altar._player_nearby = player
	altar._rest()
	check(GameState.has_valid_save() and GameState.max_health == 6 and GameState.current_health == 6, "Level 3 altar saves six full hearts")


func read_third_and_retry_boss() -> void:
	await load_scene(MENU)
	check(not scene.continue_button.disabled, "Continue enabled for level 3 save")
	scene.continue_button.pressed.emit()
	await get_tree().scene_changed
	await get_tree().process_frame
	scene = get_tree().current_scene
	player = scene.get_node("Player")
	player.set_physics_process(false)
	var altar: Altar = scene.get_node("Checkpoint/Santuario_Profundo")
	check(scene.scene_file_path == LEVEL_3 and player.global_position == altar.global_position, "Continue restores level 3 altar")
	check(GameState.max_health == 6 and GameState.current_health == 6 and full_hearts(6), "Level 3 Continue restores six full hearts")
	var boss: GuardianSediento = scene.get_node("BossArena/GuardianSediento")
	check(boss.current_health == 12 and boss.phase == 1 and boss.successful_parries == 0 and not boss.active, "Boss loads fresh, outside combat")
	player.global_position = scene.get_node("BossArena/BossEncounterTrigger").global_position
	scene._on_boss_trigger_body_entered(player)
	var save := ConfigFile.new()
	check(save.load(TEST_SAVE) == OK and save.get_value("checkpoint", "id") == "Checkpoint/Santuario_Profundo", "Boss retry checkpoint does not overwrite altar save")
	boss._spawn_projectile()
	boss._spawn_corruption_zone(0)
	await die_and_continue(6)
	check(boss.current_health == 12 and boss.phase == 1 and boss.successful_parries == 0 and not boss.active and boss._spawned_projectiles.is_empty() and boss._spawned_zones.is_empty(), "Boss and temporary attacks reset on death")
	GameState.delete_save()
