extends Node2D

const LEVEL_MUSIC := preload("res://assets/audio/music/ruinas_ancestrales.mp3")

@onready var player: WayraPlayer = $Player
@onready var default_spawn: Marker2D = $PlayerSpawn
@onready var ability_notice: Label = $AbilityUnlockNotice/Panel/Label

var _death_in_progress := false


func _ready() -> void:
	MusicManager.play_music(LEVEL_MUSIC, 0.6)
	_place_player_at_requested_spawn()
	_initialize_level_respawn()
	_connect_enemies()
	GameState.player_died.connect(_on_player_died)
	$AbilityUnlockNotice.hide()
	_sync_player_health()
	if not GameState.unlocked_abilities.get("double_jump", false):
		push_warning("Ruinas Ancestrales requiere el Doble Salto obtenido en Orillas del Lago.")


func _place_player_at_requested_spawn() -> void:
	if GameState.consume_saved_checkpoint_spawn(get_tree().current_scene.scene_file_path):
		player.global_position = GameState.last_checkpoint
		return
	if GameState.pending_spawn_id.is_empty():
		return
	var requested_spawn := get_node_or_null("SpawnPoints/%s" % GameState.pending_spawn_id)
	if requested_spawn is Marker2D:
		player.global_position = requested_spawn.global_position
	GameState.pending_spawn_id = &""


func _initialize_level_respawn() -> void:
	var current_scene_path := get_tree().current_scene.scene_file_path
	if GameState.checkpoint_scene != current_scene_path:
		GameState.set_checkpoint(player.global_position, current_scene_path)


func _connect_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("take_damage") and not player.attack_hit.is_connected(enemy.take_damage):
			player.attack_hit.connect(enemy.take_damage)
		if enemy.has_method("stun") and not player.parry_success.is_connected(enemy.stun):
			player.parry_success.connect(enemy.stun)


func _on_player_died() -> void:
	if _death_in_progress:
		return
	_death_in_progress = true
	$PauseMenu/DeathScreen.present(player, _respawn_player)


func _respawn_player() -> void:
	GameState.restore_leaves_to_checkpoint()
	get_tree().call_group("kill_zones", "restore_to_snapshot")
	get_tree().call_group("enemies", "restore_to_snapshot")
	GameState.heal_full()
	_sync_player_health()
	player.global_position = GameState.last_checkpoint if GameState.last_checkpoint != Vector2.ZERO else default_spawn.global_position
	player.velocity = Vector2.ZERO
	player.sprite.modulate.a = 1.0
	player.finish_respawn()
	_death_in_progress = false


func _sync_player_health() -> void:
	player.current_health = GameState.current_health
	player.max_health = GameState.max_health
	player.health_changed.emit()

