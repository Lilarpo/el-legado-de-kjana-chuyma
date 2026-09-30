extends Node2D

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const CONTROLS_SCENE := preload("res://scenes/ui/MobileControls.tscn")
const INTERACTABLE_SCENE := preload("res://scenes/npc/kjana_chuyma.tscn")

var failures: Array[String] = []
var controls: CanvasLayer


func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures.append(label)


func _ready() -> void:
	call_deferred("run")


func mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = pressed
	if DisplayServer.get_name() == "headless":
		controls._input(event)
	else:
		event.device = InputEvent.DEVICE_ID_MOUSE
		Input.parse_input_event(event)


func touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	Input.parse_input_event(event)


func action(name: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	Input.parse_input_event(event)


func run() -> void:
	GameState.reset_for_new_game()
	var player := PLAYER_SCENE.instantiate()
	player.name = "Player"
	add_child(player)
	player.set_physics_process(false)
	controls = CONTROLS_SCENE.instantiate()
	controls.force_mobile_controls = true
	add_child(controls)
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png("/tmp/mobile_controls_layout.png")
	check(controls.root.visible and controls.layer == 7, "Forced controls visible above HUD")
	var expected := ["move_left", "move_right", "jump", "attack", "parry", "interact", "use_protection_potion", "pause"]
	var names := ["LeftButton", "RightButton", "JumpButton", "AttackButton", "ParryButton", "InteractButton", "PotionButton", "PauseButton"]
	for i in names.size():
		var button: TouchScreenButton = controls.root.get_node(names[i])
		var atlas := button.texture_normal as AtlasTexture
		check(button.action == expected[i] and atlas != null and atlas.region == Rect2((i % 4) * 443.5, (i / 4) * 443.5, 443.5, 443.5), "%s uses existing action and correct atlas cell" % names[i])
	check(not controls.interact_button.visible and not controls.potion_button.visible, "Context buttons hidden by default")
	GameState.register_potion_collected("mobile_test_potion")
	check(controls.potion_button.visible, "Potion appears when inventory has one")
	GameState.use_protection_potion()
	check(not controls.potion_button.visible, "Potion hides immediately when inventory reaches zero")
	GameState.register_potion_collected("mobile_test_potion_2")
	check(controls.potion_button.visible and controls.potion_button.modulate.a < 0.5, "Potion dims while protection is active")
	GameState.clear_protection()
	check(controls.potion_button.modulate.a > 0.7, "Potion restores opacity after shield ends")
	var npc := INTERACTABLE_SCENE.instantiate()
	add_child(npc)
	npc._player_in_range = player
	controls._update_interact_button()
	check(controls.interact_button.visible, "Interact appears from existing NPC range state")
	if DisplayServer.get_name() != "headless":
		var dialogue_requests := [0]
		npc.dialogue_requested.connect(func(_lines, _speaker, _portrait, _spiritual): dialogue_requests[0] += 1)
		touch(2, controls.interact_button.position + Vector2.ONE * 41.0, true)
		await get_tree().process_frame
		check(dialogue_requests[0] == 1, "Touch Interact sends exactly one existing NPC dialogue request")
		touch(2, controls.interact_button.position + Vector2.ONE * 41.0, false)
	if DisplayServer.get_name() != "headless":
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png("/tmp/mobile_controls_context.png")
	npc._player_in_range = null
	controls._update_interact_button()
	check(not controls.interact_button.visible, "Interact hides after leaving range")
	var right: TouchScreenButton = controls.root.get_node("RightButton")
	var jump: TouchScreenButton = controls.root.get_node("JumpButton")
	mouse(right.position + Vector2.ONE * 50.0, true)
	await get_tree().process_frame
	check(Input.is_action_pressed("move_right"), "PC debug click holds move_right")
	action(&"jump", true)
	await get_tree().process_frame
	check(Input.is_action_pressed("move_right") and Input.is_action_pressed("jump"), "InputMap accepts movement and jump simultaneously")
	action(&"jump", false)
	mouse(right.position + Vector2.ONE * 50.0, false)
	await get_tree().process_frame
	check(not Input.is_action_pressed("move_right") and not Input.is_action_pressed("jump"), "Releasing both actions clears input")
	if DisplayServer.get_name() != "headless":
		touch(0, right.position + Vector2.ONE * 50.0, true)
		await get_tree().process_frame
		check(right.is_pressed() and Input.is_action_pressed("move_right"), "Rendered runtime accepts right finger")
		touch(1, jump.position + Vector2.ONE * 50.0, true)
		await get_tree().process_frame
		check(right.is_pressed() and jump.is_pressed() and Input.is_action_pressed("jump"), "Rendered runtime accepts two independent fingers")
		touch(1, jump.position + Vector2.ONE * 50.0, false)
		touch(0, right.position + Vector2.ONE * 50.0, false)
		await get_tree().process_frame
		var parry_button: TouchScreenButton = controls.root.get_node("ParryButton")
		touch(3, parry_button.position + Vector2.ONE * 53.0, true)
		await get_tree().process_frame
		check(Input.is_action_just_pressed("parry"), "Touch Parry produces just_pressed for Perfect Parry")
		touch(3, parry_button.position + Vector2.ONE * 53.0, false)
		var attack_button: TouchScreenButton = controls.root.get_node("AttackButton")
		touch(5, attack_button.position + Vector2.ONE * 50.0, true)
		await get_tree().process_frame
		check(Input.is_action_just_pressed("attack"), "Touch Attack uses existing just_pressed action")
		touch(5, attack_button.position + Vector2.ONE * 50.0, false)
		touch(6, controls.potion_button.position + Vector2.ONE * 39.0, true)
		await get_tree().process_frame
		check(Input.is_action_just_pressed("use_protection_potion"), "Touch Potion uses existing action")
		player._handle_state_input()
		check(GameState.protection_potions == 0 and GameState.protection_hits_remaining == 3 and not controls.potion_button.visible, "Touch Potion activates protection and hides at zero stock")
		touch(6, controls.potion_button.position + Vector2.ONE * 39.0, false)
	var pause := preload("res://scenes/ui/pause_menu.tscn").instantiate()
	add_child(pause)
	if DisplayServer.get_name() != "headless":
		touch(4, controls.pause_button.position + Vector2.ONE * 25.0, true)
		await get_tree().process_frame
		await get_tree().process_frame
		check(get_tree().paused and not controls.root.visible, "Touch Pause opens existing menu and hides controls")
		touch(4, controls.pause_button.position + Vector2.ONE * 25.0, false)
	else:
		pause._set_paused(true)
		await get_tree().process_frame
		check(get_tree().paused and not controls.root.visible, "Existing pause state hides gameplay controls")
	pause._set_paused(false)
	await get_tree().process_frame
	check(not get_tree().paused and controls.root.visible, "Resume restores gameplay controls")
	pause.queue_free()
	controls.queue_free()
	npc.queue_free()
	player.queue_free()
	await get_tree().process_frame
	var pc_player := PLAYER_SCENE.instantiate()
	pc_player.name = "Player"
	add_child(pc_player)
	pc_player.set_physics_process(false)
	var pc_controls := CONTROLS_SCENE.instantiate()
	add_child(pc_controls)
	await get_tree().process_frame
	check(not pc_controls.root.visible, "PC controls stay hidden when force_mobile_controls is false")
	pc_controls.queue_free()
	pc_player.queue_free()
	await get_tree().process_frame
	print("MOBILE CONTROLS RESULT: ", failures.size(), " failures: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
