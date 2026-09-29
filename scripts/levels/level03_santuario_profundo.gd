extends Node2D

@onready var player: WayraPlayer = $Player
@onready var default_spawn: Marker2D = $PlayerSpawn
@onready var boss: GuardianSediento = $BossArena/GuardianSediento
@onready var boss_hud: BossHUD = $BossHUD
@onready var boss_trigger: Area2D = $BossArena/BossEncounterTrigger
@onready var arena_gate: StaticBody2D = $BossAnteChamber/ArenaGate
@onready var gate_collision: CollisionShape2D = $BossAnteChamber/ArenaGate/Collision
@onready var gate_visual: BossArenaBarrier = $BossAnteChamber/ArenaGate/Visual
@onready var end_game_trigger: Area2D = $PostBoss/EndGameTrigger

const FRAGMENT_SCENE := preload("res://scenes/objects/fragmento_legado.tscn")
const ENDING_SCENE := "res://scenes/ui/EndingSequence.tscn"
const BOSS_RETRY_OFFSET := Vector2(-120.0, 0.0)
const LEVEL_MUSIC := preload("res://assets/audio/music/santuario_profundo.mp3")
const BOSS_MUSIC := preload("res://assets/audio/music/guardian_sediento.mp3")

var _death_in_progress := false
var _boss_fight_active := false
var _ending_transition := false
var _fragment_3: FragmentoLegado


func _ready() -> void:
	MusicManager.play_music(LEVEL_MUSIC, 0.6)
	_place_player_at_requested_spawn()
	_initialize_level_respawn()
	_connect_enemies()
	_setup_boss_encounter()
	GameState.player_died.connect(_on_player_died)
	if not GameState.fragment_collected.is_connected(_on_fragment_collected):
		GameState.fragment_collected.connect(_on_fragment_collected)
	_sync_player_health()
	if not GameState.unlocked_abilities.get("double_jump", false):
		push_warning("Santuario Profundo requiere el Doble Salto.")
	if not GameState.unlocked_abilities.get("counterattack", false):
		push_warning("Santuario Profundo está diseñado para llegar con el Contraataque desbloqueado.")


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


func _setup_boss_encounter() -> void:
	var corruption_points: Array[Vector2] = [
		$BossArena/BossCorruptionPoint_01.global_position,
		$BossArena/BossCorruptionPoint_02.global_position,
		$BossArena/BossCorruptionPoint_03.global_position,
	]
	boss.configure_arena(
		player,
		$BossArena/BossAttackPoint_Left.global_position,
		$BossArena/BossAttackPoint_Right.global_position,
		$BossArena/BossCenter.global_position,
		corruption_points
	)
	boss_hud.bind_boss(boss)
	player.attack_hit.connect(boss.take_damage)
	player.parry_success.connect(boss.stun)
	boss.defeated.connect(_on_guardian_defeated)
	boss_trigger.body_entered.connect(_on_boss_trigger_body_entered)
	end_game_trigger.body_entered.connect(_on_end_game_trigger_body_entered)
	_set_gate_closed(false)
	end_game_trigger.monitoring = GameState.can_begin_finale()
	if GameState.guardian_defeated:
		boss.visible = false
		boss_trigger.monitoring = false
		_spawn_fragment_3()
	else:
		boss.reset_boss_fight()


func _on_boss_trigger_body_entered(body: Node2D) -> void:
	if body != player or _boss_fight_active or GameState.guardian_defeated:
		return
	_boss_fight_active = true
	boss_trigger.set_deferred("monitoring", false)
	var retry_position: Vector2 = $BossAnteChamber/BossArenaEntrance.global_position + BOSS_RETRY_OFFSET
	GameState.set_checkpoint(retry_position, get_tree().current_scene.scene_file_path)
	_set_gate_closed(true)
	MusicManager.play_music(BOSS_MUSIC, 0.6)
	boss.start_fight()


func _set_gate_closed(closed: bool) -> void:
	arena_gate.collision_layer = 1 if closed else 0
	gate_collision.set_deferred("disabled", not closed)
	gate_visual.set_closed(closed, not is_inside_tree())


func _on_guardian_defeated() -> void:
	_boss_fight_active = false
	GameState.register_guardian_defeated()
	_set_gate_closed(false)
	MusicManager.play_music(LEVEL_MUSIC, 0.8)
	_spawn_fragment_3()


func _spawn_fragment_3() -> void:
	if GameState.fragments_collected.has(GameState.FINAL_FRAGMENT_ID) or is_instance_valid(_fragment_3):
		return
	_fragment_3 = FRAGMENT_SCENE.instantiate() as FragmentoLegado
	_fragment_3.fragment_id = GameState.FINAL_FRAGMENT_ID
	$Collectibles.add_child(_fragment_3)
	_fragment_3.global_position = $PostBoss/Fragment3Spawn_AfterBoss.global_position


func _on_fragment_collected(id: String) -> void:
	if id != GameState.FINAL_FRAGMENT_ID:
		return
	if GameState.try_begin_finale():
		_begin_ending()


func _on_end_game_trigger_body_entered(body: Node2D) -> void:
	if body == player and GameState.try_begin_finale():
		_begin_ending()


func _begin_ending() -> void:
	if _ending_transition:
		return
	_ending_transition = true
	end_game_trigger.set_deferred("monitoring", false)
	player.input_locked = true
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	boss._clear_temporary_attacks()
	boss_hud.hide()
	$HUD.hide()
	$PauseMenu.hide()
	$PauseMenu.set_process_unhandled_input(false)
	MusicManager.stop_music(0.4)
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)
	var fade_rect := ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.modulate.a = 0.0
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)
	var fade_tween := create_tween()
	fade_tween.tween_property(fade_rect, "modulate:a", 1.0, 0.5)
	await fade_tween.finished
	if is_inside_tree():
		get_tree().change_scene_to_file(ENDING_SCENE)


func _on_player_died() -> void:
	if _death_in_progress:
		return
	_death_in_progress = true
	$PauseMenu/DeathScreen.present(player, _respawn_player)


func _respawn_player() -> void:
	if _boss_fight_active:
		_boss_fight_active = false
		boss.reset_boss_fight()
		_set_gate_closed(false)
		MusicManager.play_music(LEVEL_MUSIC, 0.6)
	GameState.restore_leaves_to_checkpoint()
	get_tree().call_group("kill_zones", "restore_to_snapshot")
	get_tree().call_group("enemies", "restore_to_snapshot")
	GameState.heal_full()
	_sync_player_health()
	player.global_position = GameState.last_checkpoint if GameState.last_checkpoint != Vector2.ZERO else default_spawn.global_position
	player.velocity = Vector2.ZERO
	player.sprite.modulate.a = 1.0
	player.finish_respawn()
	if not GameState.guardian_defeated:
		boss_trigger.set_deferred("monitoring", true)
	_death_in_progress = false


func _sync_player_health() -> void:
	player.current_health = GameState.current_health
	player.max_health = GameState.max_health
	player.health_changed.emit()
