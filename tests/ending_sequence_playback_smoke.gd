extends Node
## Runs both real Ogg/Theora files to completion; no synthetic finished signal.

@onready var ending: Control = $EndingSequence
var finished_count := 0
var failures: Array[String] = []


func _ready() -> void:
	ending.video.finished.connect(func() -> void: finished_count += 1)
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png("/tmp/ending_%s.png" % label)


func wait_for_stage(stage: int, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while ending._stage != stage and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return ending._stage == stage


func run() -> void:
	check(ending._stage == 1 and ending.video.is_playing(), "Guardian cinematic is playing")
	await get_tree().create_timer(1.0).timeout
	await capture("video_1")
	var reached_fin: bool = await wait_for_stage(3, 20000)
	check(reached_fin and finished_count == 1, "First file emits finished and opens FIN")
	if not reached_fin:
		finish()
		return
	await get_tree().create_timer(1.1).timeout
	await capture("fin")
	var reached_second: bool = await wait_for_stage(2, 5000)
	check(reached_second and finished_count >= 1, "First file emits finished and automatically starts epilogue")
	if not reached_second:
		finish()
		return
	check(ending.video.stream != null and ending.video.stream.resource_path.ends_with("ending_02_epilogue.ogv"), "Second cinematic uses epilogue file")
	await get_tree().create_timer(1.0).timeout
	await capture("video_2")
	var reached_final: bool = await wait_for_stage(4, 22000)
	check(reached_final and finished_count == 2, "Second file emits finished and opens CONTINUARÁ")
	if reached_final:
		await get_tree().create_timer(4.7).timeout
		check(ending.title.text == "CONTINUARÁ" and ending.menu_button.visible and ending.menu_button.has_focus(), "Final card keeps title and focuses return button")
		await capture("continuara")
	finish()


func finish() -> void:
	print("ENDING PLAYBACK RESULT: ", failures.size(), " failures: ", failures)
	ending.video.stop()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().quit(0 if failures.is_empty() else 1)
