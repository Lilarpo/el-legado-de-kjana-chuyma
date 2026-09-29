extends Node

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "audio"

const DEFAULT_MASTER := 0.85
const DEFAULT_MUSIC := 0.75
const DEFAULT_SFX := 0.65

const BUS_BASE_DB := {
	&"Master": 0.0,
	&"Music": -14.0,
	&"SFX": -10.0,
	&"UI": -14.0,
}

var master_volume := DEFAULT_MASTER
var music_volume := DEFAULT_MUSIC
var sfx_volume := DEFAULT_SFX


func _ready() -> void:
	load_settings()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_bus(&"Master", master_volume)


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_bus(&"Music", music_volume)


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_bus(&"SFX", sfx_volume)
	_apply_bus(&"UI", sfx_volume)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		master_volume = _read_normalized(config, "master_volume", DEFAULT_MASTER)
		music_volume = _read_normalized(config, "music_volume", DEFAULT_MUSIC)
		sfx_volume = _read_normalized(config, "sfx_volume", DEFAULT_SFX)
	apply_settings()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "master_volume", master_volume)
	config.set_value(SECTION, "music_volume", music_volume)
	config.set_value(SECTION, "sfx_volume", sfx_volume)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_error("No se pudo guardar la configuración de audio: %s" % error_string(error))


func apply_settings() -> void:
	_apply_bus(&"Master", master_volume)
	_apply_bus(&"Music", music_volume)
	_apply_bus(&"SFX", sfx_volume)
	_apply_bus(&"UI", sfx_volume)


func _apply_bus(bus_name: StringName, normalized_value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_warning("AudioSettings: no existe el bus %s." % bus_name)
		return
	var muted := normalized_value <= 0.0001
	AudioServer.set_bus_mute(bus_index, muted)
	if not muted:
		AudioServer.set_bus_volume_db(
			bus_index,
			float(BUS_BASE_DB.get(bus_name, 0.0)) + linear_to_db(normalized_value)
		)


func _read_normalized(config: ConfigFile, key: String, fallback: float) -> float:
	var value: Variant = config.get_value(SECTION, key, fallback)
	if value is float or value is int:
		return clampf(float(value), 0.0, 1.0)
	return fallback
