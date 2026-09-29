extends Node

const LEVELS := [
	"res://scenes/levels/level01_orillas_del_lago.tscn",
	"res://scenes/levels/level02_ruinas_ancestrales.tscn",
	"res://scenes/levels/level03_santuario_profundo.tscn",
]
const EXPECTED := [
	"protection_potion_01",
	"protection_potion_02",
]
var failures: Array[String] = []
var checks := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.save_file_path = "user://protection_potion_smoke.cfg"
	GameState.delete_save()
	get_tree().current_scene = null
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	print("PASS " if value else "FAIL ", message)
	if not value:
		failures.append(message)

func load_level(path: String) -> Node:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().scene_changed
	await get_tree().process_frame
	var level := get_tree().current_scene
	level.get_node("Player").set_physics_process(false)
	return level

func find_pickups(level: Node) -> Array[Node]:
	var found: Array[Node] = []
	for node in level.get_children():
		if node is ProtectionPotionPickup and not node.is_queued_for_deletion():
			found.append(node)
	return found

func marked_enemies(level: Node) -> Array[Node]:
	var found: Array[Node] = []
	for container_name in ["Enemies", "FutureEnemySpawns", "FutureCondorSpawns"]:
		var container := level.get_node_or_null(container_name)
		if container == null:
			continue
		for enemy: Node in container.get_children():
			if "drops_protection_potion" in enemy and enemy.drops_protection_potion:
				found.append(enemy)
	return found

func kill_enemy(enemy: Node) -> void:
	enemy._die()
	enemy._on_animation_finished()

func run() -> void:
	GameState.reset_for_new_game()
	var level := await load_level(LEVELS[0])
	var player: WayraPlayer = level.get_node("Player")
	var potion_scene: ProtectionPotionPickup = load("res://scenes/objects/ProtectionPotionPickup.tscn").instantiate()
	check(potion_scene.get_node("Sprite").texture.resource_path == ProtectionPotionPickup.ICON_PATH, "Pickup uses definitive PNG")
	var sprite: Sprite2D = potion_scene.get_node("Sprite")
	var image := sprite.texture.get_image()
	var visible_size := Vector2(image.get_used_rect().size) * sprite.scale
	check(image.get_pixel(0, 0).a == 0.0 and visible_size.x >= 28.0 and visible_size.x <= 36.0 and visible_size.y >= 28.0 and visible_size.y <= 36.0, "Transparent PNG renders near 32 pixels")
	check(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and level.get_node("HUD").potion_icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "World and HUD use nearest filtering")
	check(level.get_node("HUD").potion_icon.texture.resource_path == sprite.texture.resource_path and level.get_node("HUD").potion_icon.custom_minimum_size == Vector2(28, 28), "HUD uses same PNG at 28 by 28")
	potion_scene.free()
	GameState.set_checkpoint(Vector2(100, 600), LEVELS[0], "potion_test")
	check(GameState.save_at_checkpoint(), "Baseline checkpoint saved")
	var normal = level.get_node("Enemies/Enemy_Zone02_A")
	kill_enemy(normal)
	check(find_pickups(level).is_empty(), "Unmarked enemy drops nothing")
	var first = level.get_node("Enemies/Enemy_Zone05_B")
	kill_enemy(first)
	check(find_pickups(level).size() == 1, "First carrier drops exactly one potion")
	find_pickups(level)[0]._on_body_entered(player)
	check(GameState.protection_potions == 1 and GameState.collected_potion_drop_ids == [EXPECTED[0]], "First potion and ID recorded only on pickup")
	check(GameState.load_save() and GameState.protection_potions == 1 and GameState.collected_potion_drop_ids.has(EXPECTED[0]), "First pickup survives reload before another checkpoint")
	level = await load_level(LEVELS[0])
	kill_enemy(level.get_node("Enemies/Enemy_Zone05_B"))
	check(find_pickups(level).is_empty(), "First carrier cannot be farmed after reload")

	var all_ids: Array[String] = []
	for index in LEVELS.size():
		level = await load_level(LEVELS[index])
		var marked := marked_enemies(level)
		check(marked.size() == [1, 0, 1][index], "Level %d has correct carrier count" % (index + 1))
		for enemy: Node in marked:
			all_ids.append(enemy.potion_drop_id)
	check(all_ids == EXPECTED, "Only two unique drops exist across all three levels")
	check(not "drops_protection_potion" in level.get_node("BossArena/GuardianSediento"), "Boss has no potion drop")
	player = level.get_node("Player")
	var second = level.get_node("FutureCondorSpawns/Condor_Level3_03")
	kill_enemy(second)
	check(find_pickups(level).size() == 1 and not GameState.collected_potion_drop_ids.has(EXPECTED[1]), "Second drop is not consumed on enemy death")
	level = await load_level(LEVELS[2])
	player = level.get_node("Player")
	second = level.get_node("FutureCondorSpawns/Condor_Level3_03")
	kill_enemy(second)
	check(find_pickups(level).size() == 1, "Uncollected second drop remains available after reload")
	find_pickups(level)[0]._on_body_entered(player)
	check(GameState.protection_potions == 2 and GameState.collected_potion_drop_ids == EXPECTED, "Both pickups give exactly two stored potions")
	check(level.get_node("HUD").potion_label.text == "x2", "HUD shows x2")
	level = await load_level(LEVELS[2])
	player = level.get_node("Player")
	kill_enemy(level.get_node("FutureCondorSpawns/Condor_Level3_03"))
	check(find_pickups(level).is_empty(), "Second carrier cannot be farmed after pickup")
	player.try_use_protection_potion()
	check(GameState.protection_potions == 1 and GameState.protection_hits_remaining == 3 and level.get_node("HUD").potion_label.text == "x1", "First use gives three charges and x1")
	player.try_use_protection_potion()
	check(GameState.protection_potions == 1 and GameState.protection_hits_remaining == 3, "Active protection cannot stack")
	var hp := GameState.current_health
	for expected_hits in [2, 1, 0]:
		player._damage_invulnerability_left = 0.0
		player.take_damage(1)
		check(GameState.protection_hits_remaining == expected_hits and GameState.current_health == hp, "Shield absorbs one valid hit")
	player._damage_invulnerability_left = 0.0
	player.take_damage(1)
	check(GameState.current_health == hp - 1, "Fourth hit damages a heart")
	player.try_use_protection_potion()
	check(GameState.protection_potions == 0 and GameState.protection_hits_remaining == 3 and level.get_node("HUD").potion_label.text == "x0", "Second use gives three charges and x0")
	check(GameState.load_save() and GameState.protection_potions == 0 and GameState.protection_hits_remaining == 0 and GameState.collected_potion_drop_ids == EXPECTED, "Continue keeps spent inventory and both IDs but not shield")
	var older_save := ConfigFile.new()
	older_save.load(GameState.save_file_path)
	older_save.set_value("progress", "collected_potion_drop_ids", ["l1_enemy_zone05_b", "l3_condor_level3_03"])
	older_save.save(GameState.save_file_path)
	check(GameState.load_save() and GameState.collected_potion_drop_ids == EXPECTED, "Prior carrier IDs migrate to the two definitive IDs")
	GameState.reset_for_new_game()
	check(GameState.protection_potions == 0 and GameState.protection_hits_remaining == 0 and GameState.collected_potion_drop_ids.is_empty(), "New game resets both drops")
	GameState.register_potion_collected(EXPECTED[0])
	var previous_save := ConfigFile.new()
	previous_save.load(GameState.save_file_path)
	check(previous_save.get_value("progress", "protection_potions") == 0, "New game cannot overwrite previous save before its first checkpoint")
	GameState.reset_for_new_game()
	GameState.delete_save()
	print("POTION RESULT: %d checks, %d failures: %s" % [checks, failures.size(), failures])
	MusicManager.stop_music(0.0)
	if is_instance_valid(get_tree().current_scene):
		get_tree().current_scene.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
