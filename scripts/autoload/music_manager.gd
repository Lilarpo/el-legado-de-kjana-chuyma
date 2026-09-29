extends Node

const SILENCE_DB := -60.0

var _player: AudioStreamPlayer
var _fade: Tween
var _request_id := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.name = "MusicPlayer"
	_player.bus = &"Music"
	add_child(_player)


func play_music(stream: AudioStream, fade_time := 0.6) -> void:
	if stream == null:
		stop_music(fade_time)
		return
	if _same_stream(stream) and _player.playing:
		# Returning to the menu can supersede a pending level crossfade.
		_request_id += 1
		_cancel_fade()
		if fade_time > 0.0 and not is_zero_approx(_player.volume_db):
			_fade = create_tween()
			_fade.tween_property(_player, "volume_db", 0.0, fade_time * 0.5)
		else:
			_player.volume_db = 0.0
		return
	_request_id += 1
	var request := _request_id
	_cancel_fade()
	if _player.playing and fade_time > 0.0:
		_fade = create_tween()
		_fade.tween_property(_player, "volume_db", SILENCE_DB, fade_time * 0.5)
		await _fade.finished
		if request != _request_id:
			return
	_player.stop()
	_configure_loop(stream)
	_player.stream = stream
	_player.volume_db = SILENCE_DB if fade_time > 0.0 else 0.0
	_player.play()
	if fade_time > 0.0:
		_fade = create_tween()
		_fade.tween_property(_player, "volume_db", 0.0, fade_time * 0.5)


func stop_music(fade_time := 0.6) -> void:
	_request_id += 1
	var request := _request_id
	_cancel_fade()
	if not _player.playing:
		return
	if fade_time > 0.0:
		_fade = create_tween()
		_fade.tween_property(_player, "volume_db", SILENCE_DB, fade_time)
		await _fade.finished
		if request != _request_id:
			return
	_player.stop()
	_player.stream = null
	_player.volume_db = 0.0


func _same_stream(stream: AudioStream) -> bool:
	if _player.stream == stream:
		return true
	return _player.stream != null and not stream.resource_path.is_empty() \
		and _player.stream.resource_path == stream.resource_path


func _configure_loop(stream: AudioStream) -> void:
	if "loop" in stream:
		stream.set("loop", true)


func _cancel_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null
