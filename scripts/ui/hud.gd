extends CanvasLayer

@onready var hearts: HBoxContainer = $MarginContainer/Content/Hearts
@onready var leaves_label: Label = $MarginContainer/Content/LeavesDisplay/LeavesLabel
@onready var fragments_label: Label = $MarginContainer/Content/FragmentsDisplay/FragmentsLabel


func _ready() -> void:
	GameState.health_changed.connect(_on_health_changed)
	GameState.leaves_changed.connect(_on_leaves_changed)
	GameState.fragment_collected.connect(_on_fragment_collected)
	_on_health_changed(GameState.current_health, GameState.max_health)
	_on_leaves_changed(GameState.leaves_collected)
	_update_fragments()


func _on_health_changed(current_health: int, max_health: int) -> void:
	while hearts.get_child_count() < max_health:
		var extra := hearts.get_child(0).duplicate() as TextureRect
		hearts.add_child(extra)
	for index in hearts.get_child_count():
		var heart: TextureRect = hearts.get_child(index)
		heart.visible = index < max_health
		heart.texture = heart.get_meta("full_texture") if index < current_health else heart.get_meta("empty_texture")


func update_from_player() -> void:
	# Player can emit during its _ready, before this sibling initializes.
	if not is_node_ready():
		return
	var player := get_tree().current_scene.get_node_or_null("Player")
	if player != null:
		_on_health_changed(player.current_health, player.max_health)


func _on_leaves_changed(total: int) -> void:
	leaves_label.text = str(total)


func _on_fragment_collected(_id: String) -> void:
	_update_fragments()


func _update_fragments() -> void:
	fragments_label.text = "%d/3" % GameState.fragments_collected.size()