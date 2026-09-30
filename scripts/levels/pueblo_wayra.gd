extends Node2D

const GROUND_ROW := 38

@onready var terrain: TileMapLayer = $Terrain
@onready var player: WayraPlayer = $Player
@onready var spawn: Marker2D = $Spawn

var _death_in_progress := false


func _ready() -> void:
	_draw_ground()
	_draw_village_details()
	if GameState.consume_saved_checkpoint_spawn(get_tree().current_scene.scene_file_path):
		player.global_position = GameState.last_checkpoint
	GameState.player_died.connect(_on_player_died)
	_sync_player_health()


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
	player.global_position = GameState.last_checkpoint if GameState.last_checkpoint != Vector2.ZERO else spawn.global_position
	player.velocity = Vector2.ZERO
	player.sprite.modulate.a = 1.0
	player.finish_respawn()
	_death_in_progress = false


func _sync_player_health() -> void:
	player.current_health = GameState.current_health
	player.max_health = GameState.max_health
	player.health_changed.emit()


func _draw_ground() -> void:
	var ground_sections := [Vector2i(0, 62), Vector2i(71, 127), Vector2i(136, 182), Vector2i(191, 239)]
	for section in ground_sections:
		for column in range(section.x, section.y + 1):
			for row in range(GROUND_ROW, 45):
				terrain.set_cell(Vector2i(column, row), 0, Vector2i(0, 0))

	_draw_platform(47, 58, 32)
	_draw_platform(96, 108, 34)
	_draw_platform(153, 165, 31)


func _draw_platform(start_column: int, end_column: int, row: int) -> void:
	for column in range(start_column, end_column + 1):
		terrain.set_cell(Vector2i(column, row), 0, Vector2i(1, 0))
		terrain.set_cell(Vector2i(column, row + 1), 0, Vector2i(0, 0))


func _draw_village_details() -> void:
	_draw_house(18, 29)
	_draw_house(78, 27)
	_draw_house(142, 29)
	_draw_house(202, 26)

	for tile_position in [Vector2i(12, 37), Vector2i(35, 37), Vector2i(67, 37), Vector2i(89, 37), Vector2i(119, 37), Vector2i(147, 37), Vector2i(174, 37), Vector2i(198, 37), Vector2i(222, 37)]:
		terrain.set_cell(tile_position, 0, Vector2i(2, 0))

	for tile_position in [Vector2i(8, 36), Vector2i(55, 36), Vector2i(111, 36), Vector2i(181, 36), Vector2i(232, 36)]:
		terrain.set_cell(tile_position, 0, Vector2i(3, 0))


func _draw_house(start_column: int, roof_row: int) -> void:
	for column in range(start_column, start_column + 12):
		for row in range(roof_row, 38):
			terrain.set_cell(Vector2i(column, row), 0, Vector2i(1, 0))
