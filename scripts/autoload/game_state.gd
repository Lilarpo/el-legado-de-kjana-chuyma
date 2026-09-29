extends Node

signal health_changed(current_health: int, max_health: int)
signal player_died
@warning_ignore("unused_signal")
signal fragment_collected(id: String)
signal leaves_changed(total: int)
signal leaves_restored(remaining_ids: Array[String])
signal ability_unlocked(ability_id: String)
signal heart_upgraded(maximum: int)
signal guardian_defeated_changed(defeated: bool)
signal finale_ready

@export var max_health: int = 3
@export var current_health: int = 3
@export var fragments_collected: Array[String] = []
@export var leaves_collected: int = 0
var collected_leaf_ids: Array[String] = []
var heart_upgrades := 0
var death_screen_active := false
const MAX_HEART_UPGRADES := 3

var checkpoint_leaves: int = 0
var checkpoint_leaf_ids: Array[String] = []
@export var unlocked_abilities: Dictionary = {
	"double_jump": false,
	"counterattack": false,
}
@export var last_checkpoint: Vector2 = Vector2.ZERO
@export var checkpoint_scene: String = ""
var pending_spawn_id: StringName = &""
var guardian_defeated := false
var final_fragment_collected := false
var finale_triggered := false
var checkpoint_id := ""
var resume_from_save := false
var save_file_path := "user://savegame.cfg"

const SAVE_SCENES := [
	"res://scenes/levels/level01_orillas_del_lago.tscn",
	"res://scenes/levels/level02_ruinas_ancestrales.tscn",
	"res://scenes/levels/level03_santuario_profundo.tscn",
	"res://scenes/levels/pueblo_wayra.tscn",
]

const FINAL_FRAGMENT_ID := "fragmento_santuario_profundo_03"


func reset_for_new_game() -> void:
	heart_upgrades = 0
	death_screen_active = false
	max_health = 3
	current_health = max_health
	fragments_collected.clear()
	leaves_collected = 0
	collected_leaf_ids.clear()
	checkpoint_leaves = 0
	checkpoint_leaf_ids.clear()
	unlocked_abilities["double_jump"] = false
	unlocked_abilities["counterattack"] = false
	last_checkpoint = Vector2.ZERO
	checkpoint_scene = ""
	checkpoint_id = ""
	resume_from_save = false
	pending_spawn_id = &""
	guardian_defeated = false
	final_fragment_collected = false
	finale_triggered = false
	health_changed.emit(current_health, max_health)
	leaves_changed.emit(leaves_collected)
	leaves_restored.emit(checkpoint_leaf_ids.duplicate())
	guardian_defeated_changed.emit(false)


func unlock_ability(ability_id: String) -> void:
	if not unlocked_abilities.has(ability_id) or unlocked_abilities[ability_id]:
		return
	unlocked_abilities[ability_id] = true
	ability_unlocked.emit(ability_id)

func heal_full() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)

func take_damage(amount: int) -> void:
	var was_alive := current_health > 0
	current_health = max(current_health - max(amount, 0), 0)
	health_changed.emit(current_health, max_health)
	if was_alive and current_health <= 0:
		player_died.emit()

func set_checkpoint(pos: Vector2, scene_path: String, altar_id: String = "") -> void:
	last_checkpoint = pos
	checkpoint_scene = scene_path
	checkpoint_id = altar_id
	checkpoint_leaves = leaves_collected
	checkpoint_leaf_ids = collected_leaf_ids.duplicate()


func collect_leaf(id: String) -> void:
	register_leaf_collected(id)


func register_leaf_collected(id: String) -> void:
	if id.is_empty() or collected_leaf_ids.has(id):
		return

	collected_leaf_ids.append(id)
	leaves_collected += 1
	var previous_upgrades := heart_upgrades
	while leaves_collected >= 3 and heart_upgrades < MAX_HEART_UPGRADES:
		leaves_collected -= 3
		heart_upgrades += 1
		max_health += 1
		current_health = mini(current_health + 1, max_health)
		health_changed.emit(current_health, max_health)
	leaves_changed.emit(leaves_collected)
	# Presentation only: notify after the health and coca HUD have updated.
	for upgrade in range(previous_upgrades, heart_upgrades):
		heart_upgraded.emit(max_health - (heart_upgrades - upgrade - 1))


func register_fragment_collected(id: String) -> void:
	if id.is_empty() or fragments_collected.has(id):
		return

	fragments_collected.append(id)
	if id == FINAL_FRAGMENT_ID:
		final_fragment_collected = true
	fragment_collected.emit(id)
	# S3: reunir los 3 fragmentos decidirá el final A/B; esa lógica aún no se implementa.


func register_guardian_defeated() -> void:
	if guardian_defeated:
		return
	guardian_defeated = true
	guardian_defeated_changed.emit(true)


func can_begin_finale() -> bool:
	return guardian_defeated and final_fragment_collected


func try_begin_finale() -> bool:
	if finale_triggered or not can_begin_finale():
		return false
	finale_triggered = true
	finale_ready.emit()
	return true


func restore_leaves_to_checkpoint() -> void:
	# Collected IDs and spent leaves persist, including hearts earned since resting.
	checkpoint_leaves = leaves_collected
	checkpoint_leaf_ids = collected_leaf_ids.duplicate()
	leaves_changed.emit(leaves_collected)
	leaves_restored.emit(collected_leaf_ids.duplicate())

func respawn() -> void:
	heal_full()
	if not checkpoint_scene.is_empty():
		get_tree().change_scene_to_file(checkpoint_scene)


func save_at_checkpoint() -> bool:
	if checkpoint_id.is_empty() or not SAVE_SCENES.has(checkpoint_scene):
		return false
	var save := ConfigFile.new()
	save.set_value("checkpoint", "scene", checkpoint_scene)
	save.set_value("checkpoint", "id", checkpoint_id)
	save.set_value("checkpoint", "position", last_checkpoint)
	save.set_value("progress", "current_health", current_health)
	save.set_value("progress", "max_health", max_health)
	save.set_value("progress", "heart_upgrades", heart_upgrades)
	save.set_value("progress", "leaves_collected", leaves_collected)
	save.set_value("progress", "collected_leaf_ids", collected_leaf_ids)
	save.set_value("progress", "fragments_collected", fragments_collected)
	save.set_value("progress", "double_jump", unlocked_abilities.get("double_jump", false))
	save.set_value("progress", "counterattack", unlocked_abilities.get("counterattack", false))
	save.set_value("progress", "guardian_defeated", guardian_defeated)
	save.set_value("progress", "final_fragment_collected", final_fragment_collected)
	save.set_value("progress", "finale_triggered", finale_triggered)
	var result := save.save(save_file_path)
	if result != OK:
		push_warning("No se pudo guardar la partida: %s" % error_string(result))
	return result == OK


func has_valid_save() -> bool:
	return not _read_save_data().is_empty()


func load_save() -> bool:
	var data := _read_save_data()
	if data.is_empty():
		return false
	checkpoint_scene = data["scene"]
	checkpoint_id = data["id"]
	last_checkpoint = data["position"]
	max_health = data["max_health"]
	current_health = max_health
	heart_upgrades = data["heart_upgrades"]
	leaves_collected = data["leaves_collected"]
	collected_leaf_ids.clear()
	for leaf_id: String in data["collected_leaf_ids"]:
		collected_leaf_ids.append(leaf_id)
	fragments_collected.clear()
	for fragment_id: String in data["fragments_collected"]:
		fragments_collected.append(fragment_id)
	checkpoint_leaves = leaves_collected
	checkpoint_leaf_ids = collected_leaf_ids.duplicate()
	unlocked_abilities["double_jump"] = data["double_jump"]
	unlocked_abilities["counterattack"] = data["counterattack"]
	guardian_defeated = data["guardian_defeated"]
	final_fragment_collected = data["final_fragment_collected"]
	finale_triggered = data["finale_triggered"]
	death_screen_active = false
	pending_spawn_id = &""
	resume_from_save = true
	health_changed.emit(current_health, max_health)
	leaves_changed.emit(leaves_collected)
	leaves_restored.emit(collected_leaf_ids.duplicate())
	guardian_defeated_changed.emit(guardian_defeated)
	return true


func delete_save() -> bool:
	if not FileAccess.file_exists(save_file_path):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(save_file_path)) == OK


func consume_saved_checkpoint_spawn(scene_path: String) -> bool:
	if not resume_from_save or checkpoint_scene != scene_path:
		return false
	resume_from_save = false
	return true


func _read_save_data() -> Dictionary:
	var save := ConfigFile.new()
	if save.load(save_file_path) != OK:
		return {}
	var fields := {
		"scene": ["checkpoint", "scene"],
		"id": ["checkpoint", "id"],
		"position": ["checkpoint", "position"],
		"current_health": ["progress", "current_health"],
		"max_health": ["progress", "max_health"],
		"heart_upgrades": ["progress", "heart_upgrades"],
		"leaves_collected": ["progress", "leaves_collected"],
		"collected_leaf_ids": ["progress", "collected_leaf_ids"],
		"fragments_collected": ["progress", "fragments_collected"],
		"double_jump": ["progress", "double_jump"],
		"counterattack": ["progress", "counterattack"],
		"guardian_defeated": ["progress", "guardian_defeated"],
		"final_fragment_collected": ["progress", "final_fragment_collected"],
		"finale_triggered": ["progress", "finale_triggered"],
	}
	var data := {}
	for key: String in fields:
		var section: String = fields[key][0]
		var field: String = fields[key][1]
		if not save.has_section_key(section, field):
			return {}
		data[key] = save.get_value(section, field)
	if not (data["scene"] is String and SAVE_SCENES.has(data["scene"]) and ResourceLoader.exists(data["scene"], "PackedScene")):
		return {}
	if not (data["id"] is String and not data["id"].is_empty() and data["position"] is Vector2):
		return {}
	if not (data["max_health"] is int and data["heart_upgrades"] is int and data["current_health"] is int):
		return {}
	if data["heart_upgrades"] < 0 or data["heart_upgrades"] > MAX_HEART_UPGRADES or data["max_health"] != 3 + data["heart_upgrades"]:
		return {}
	if data["current_health"] < 1 or data["current_health"] > data["max_health"]:
		return {}
	if not (data["leaves_collected"] is int and data["leaves_collected"] >= 0 and data["collected_leaf_ids"] is Array and data["fragments_collected"] is Array):
		return {}
	if not _valid_unique_ids(data["collected_leaf_ids"]) or not _valid_unique_ids(data["fragments_collected"]):
		return {}
	for flag: String in ["double_jump", "counterattack", "guardian_defeated", "final_fragment_collected", "finale_triggered"]:
		if not data[flag] is bool:
			return {}
	if data["final_fragment_collected"] != data["fragments_collected"].has(FINAL_FRAGMENT_ID):
		return {}
	if data["finale_triggered"] and not (data["guardian_defeated"] and data["final_fragment_collected"]):
		return {}
	return data


func _valid_unique_ids(ids: Array) -> bool:
	var seen := {}
	for id: Variant in ids:
		if not id is String or id.is_empty() or seen.has(id):
			return false
		seen[id] = true
	return true
