extends Node
## Plays both real files and checks all four persistent fragment counts.

const ENDING_SCENE := preload("res://scenes/ui/EndingSequence.tscn")
var failures: Array[String] = []


func _ready() -> void:
	get_tree().current_scene = null
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func wait_for_stage(ending: Control, stage: int, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while ending._stage != stage and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return ending._stage == stage


func run() -> void:
	for count in range(4):
		GameState.reset_for_new_game()
		for i in range(count):
			GameState.register_fragment_collected("test_fragment_%d" % i)
		var ending: Control = ENDING_SCENE.instantiate()
		var finish_count := [0]
		add_child(ending)
		ending.video.finished.connect(func() -> void: finish_count[0] += 1)
		var expected_stage := 2 if count == 3 else 1
		var card_stage := 4 if count == 3 else 3
		var expected_file := "ending_02_epilogue.ogv" if count == 3 else "ending_01_guardian.ogv"
		var expected_title := "CONTINUARÁ" if count == 3 else "FIN"
		check(ending._stage == expected_stage and ending.video.is_playing() and ending.video.stream != null and ending.video.stream.resource_path.ends_with(expected_file), "%d fragments select only %s" % [count, expected_file])
		if count == 0 or count == 3:
			check(await wait_for_stage(ending, card_stage, 25000), "%d fragments: real video finishes on selected card" % count)
		else:
			ending.video.finished.emit()
			check(await wait_for_stage(ending, card_stage, 3000), "%d fragments: finished opens selected card" % count)
		await get_tree().create_timer(4.8).timeout
		check(ending._stage == card_stage and ending.title.text == expected_title and ending.menu_button.visible and ending.menu_button.has_focus() and ending.video.stream == null, "%d fragments: %s persists with menu button and no second video" % [count, expected_title])
		check(finish_count[0] == 1, "%d fragments: finished handled once" % count)
		ending.queue_free()
		await get_tree().process_frame
	GameState.reset_for_new_game()
	var normal_ending: Control = ENDING_SCENE.instantiate()
	add_child(normal_ending)
	normal_ending.video.finished.emit()
	await get_tree().create_timer(4.8).timeout
	normal_ending.menu_button.pressed.emit()
	await get_tree().scene_changed
	var menu := get_tree().current_scene
	check(menu != null and menu.scene_file_path.ends_with("main_menu.tscn") and not get_tree().paused and MusicManager._player.playing and MusicManager._player.stream.resource_path.ends_with("main_menu.mp3"), "Normal ending returns to unpaused menu with menu music")
	normal_ending.queue_free()
	await get_tree().process_frame
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	print("ENDING PLAYBACK RESULT: ", failures.size(), " failures: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
