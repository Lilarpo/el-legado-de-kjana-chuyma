extends CanvasLayer

@onready var hearts: HBoxContainer = $MarginContainer/Content/Hearts
@onready var leaves_label: Label = $MarginContainer/Content/LeavesDisplay/LeavesLabel
@onready var fragments_label: Label = $MarginContainer/Content/FragmentsDisplay/FragmentsLabel
@onready var potion_icon: TextureRect = $MarginContainer/Content/PotionDisplay/PotionIcon
@onready var potion_label: Label = $MarginContainer/Content/PotionDisplay/PotionLabel
@onready var shield_label: Label = $MarginContainer/Content/PotionDisplay/ShieldLabel
@onready var potion_button: Button = $MarginContainer/Content/PotionDisplay/PotionButton
@onready var resource_displays: Array[Control] = [
	$MarginContainer/Content/FragmentsDisplay,
	$MarginContainer/Content/LeavesDisplay,
	$MarginContainer/Content/PotionDisplay,
]


func _ready() -> void:
	GameState.health_changed.connect(_on_health_changed)
	GameState.leaves_changed.connect(_on_leaves_changed)
	GameState.fragment_collected.connect(_on_fragment_collected)
	GameState.protection_changed.connect(_on_protection_changed)
	potion_button.pressed.connect(_on_potion_pressed)
	_on_health_changed(GameState.current_health, GameState.max_health)
	_on_leaves_changed(GameState.leaves_collected)
	_update_fragments()
	_on_protection_changed(GameState.protection_potions, GameState.protection_hits_remaining)


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

func _on_protection_changed(potions: int, hits: int) -> void:
	potion_label.text = "x%d" % potions
	shield_label.text = "ESCUDO %d" % hits
	shield_label.visible = hits > 0
	potion_button.disabled = potions <= 0 or hits > 0


func _on_potion_pressed() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var player := scene.get_node_or_null("Player") as WayraPlayer
	if player != null:
		player.try_use_protection_potion()


func align_mobile_resources_to_pause(pause_bottom: float, gap: float = 22.0) -> void:
	# Keep the three right-aligned rows together, measured from the visible pause button.
	var delta := pause_bottom + gap - resource_displays[0].global_position.y
	for display in resource_displays:
		display.position.y += delta
