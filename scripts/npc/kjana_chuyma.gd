extends Area2D

signal dialogue_requested(
	dialogue: Array[String],
	speaker_name: String,
	portrait_texture: Texture2D,
	spiritual_accent: bool
)

@export var level_one_finale := false
@export var grants_double_jump := false
@export var is_mama_tika := false
@export var level_two_finale := false
@export var grants_counterattack := false
@export var idle_texture: Texture2D
@export var portrait_texture: Texture2D
@export_range(1.0, 12.0, 0.5) var idle_fps := 5.0

const IDLE_FRAME_COUNT := 4

const FIRST_DIALOGUE: Array[String] = [
	"El viento trae nombres, Wayra... el tuyo aún no lo has escuchado.",
	"El lago guarda lo que el templo perdió. Ve, y que tus manos aprendan antes que tu lengua.",
	"Cuando dudas, detente. Cuando te golpeen, detente más rápido.",
]

const LEVEL_ONE_FINALE_DIALOGUE: Array[String] = [
	"Has recuperado una parte del legado.",
	"Pero las ruinas que te esperan exigen que aprendas a alcanzar lugares que antes estaban fuera de tu alcance.",
	"Deja que el viento te sostenga una vez más en el aire.",
]

const MAMA_TIKA_DIALOGUE: Array[String] = [
	"Wayra, la Sed Blanca está alcanzando las orillas.",
	"Kjana-Chuyma dejó un legado entre estas ruinas. Debes encontrarlo antes de que la corrupción avance.",
]

const LEVEL_TWO_FINALE_DIALOGUE: Array[String] = [
	"Has aprendido a alcanzar lugares que antes parecían imposibles.",
	"Ahora debes aprender a convertir la defensa en fuerza.",
	"El origen de la corrupción está cerca. Lleva el legado al Santuario Profundo.",
]

@onready var interaction_hint: Label = $InteractionHint
@onready var sprite: AnimatedSprite2D = $Sprite

var _player_in_range: Node2D
var _finale_dialogue_pending := false


func _ready() -> void:
	_configure_idle_animation()
	interaction_hint.hide()


func _configure_idle_animation() -> void:
	if idle_texture == null:
		push_warning("%s no tiene textura idle asignada." % name)
		return
	if idle_texture.get_width() % IDLE_FRAME_COUNT != 0:
		push_warning("%s necesita un spritesheet horizontal divisible entre 4." % name)
		return

	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"idle")
	frames.set_animation_speed(&"idle", idle_fps)
	frames.set_animation_loop(&"idle", true)
	var frame_width := floori(float(idle_texture.get_width()) / float(IDLE_FRAME_COUNT))
	var frame_height := idle_texture.get_height()
	for frame_index in IDLE_FRAME_COUNT:
		var atlas := AtlasTexture.new()
		atlas.atlas = idle_texture
		atlas.region = Rect2(
			frame_index * frame_width,
			0,
			frame_width,
			frame_height
		)
		frames.add_frame(&"idle", atlas)
	sprite.sprite_frames = frames
	sprite.play(&"idle")


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range == null or _player_in_range.get("input_locked"):
		return
	if event.is_action_pressed("interact"):
		_finale_dialogue_pending = level_one_finale or level_two_finale
		dialogue_requested.emit(
			_get_dialogue(),
			_get_speaker_name(),
			portrait_texture if portrait_texture != null else idle_texture,
			not is_mama_tika
		)
		get_viewport().set_input_as_handled()


func _get_speaker_name() -> String:
	return "Mama Tika" if is_mama_tika else "Kjana-Chuyma"


func _get_dialogue() -> Array[String]:
	if is_mama_tika:
		return MAMA_TIKA_DIALOGUE
	if level_one_finale:
		return LEVEL_ONE_FINALE_DIALOGUE
	if level_two_finale:
		return LEVEL_TWO_FINALE_DIALOGUE
	return FIRST_DIALOGUE


func _on_dialogue_finished() -> void:
	if not _finale_dialogue_pending:
		return
	_finale_dialogue_pending = false
	unlock_double_jump()
	unlock_counterattack()


func unlock_double_jump() -> void:
	if grants_double_jump:
		GameState.unlock_ability("double_jump")


func unlock_counterattack() -> void:
	if grants_counterattack:
		GameState.unlock_ability("counterattack")


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		_player_in_range = body
		sprite.flip_h = body.global_position.x < global_position.x
		interaction_hint.show()


func _on_body_exited(body: Node2D) -> void:
	if body == _player_in_range:
		_player_in_range = null
		interaction_hint.hide()
