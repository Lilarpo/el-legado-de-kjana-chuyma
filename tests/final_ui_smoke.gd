extends Node2D

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const CONTROLS_SCENE := preload("res://scenes/ui/MobileControls.tscn")
const PANELS_SCENE := preload("res://scenes/ui/menu_panels.tscn")

var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures.append(label)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var hud := HUD_SCENE.instantiate()
	hud.name = "HUD"
	add_child(hud)
	var controls := CONTROLS_SCENE.instantiate()
	controls.force_mobile_controls = true
	add_child(controls)
	await get_tree().process_frame
	await get_tree().process_frame
	var fragment: Control = hud.resource_displays[0]
	var pause_bottom: float = controls.pause_button.position.y + controls.BUTTON_SIZES["PauseButton"]
	check(is_equal_approx(fragment.global_position.y - pause_bottom, 22.0), "Android resources start 22 px below Pause")
	check(hud.resource_displays[1].global_position.y > fragment.global_position.y and hud.resource_displays[2].global_position.y > hud.resource_displays[1].global_position.y, "Resources retain fragment/coca/potion order")
	check(fragment.global_position.x > get_viewport_rect().size.x * 0.65, "Resources remain on the right")
	var before: float = fragment.global_position.y
	controls._layout_buttons()
	await get_tree().process_frame
	check(is_equal_approx(fragment.global_position.y, before), "Mobile alignment is idempotent")
	var original_size := get_window().size
	for width in [1280, 1440, 1560, 1600]:
		get_window().size = Vector2i(width, 720)
		await get_tree().process_frame
		await get_tree().process_frame
		var actual_bottom: float = controls.pause_button.position.y + controls.BUTTON_SIZES["PauseButton"]
		check(is_equal_approx(fragment.global_position.y - actual_bottom, 22.0), "Pause/resource gap at %d px window" % width)
	get_window().size = original_size
	await get_tree().process_frame
	var panels := PANELS_SCENE.instantiate()
	add_child(panels)
	panels.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panels.size = get_viewport_rect().size
	await get_tree().process_frame
	panels.open_controls()
	check(panels.controls_tabs.get_tab_count() == 2 and panels.controls_tabs.get_tab_title(0) == "PC" and panels.controls_tabs.get_tab_title(1) == "ANDROID", "Both control tabs load")
	check(panels.controls_tabs.current_tab == 0, "PC tab opens by default on PC")
	var panel_rect: Rect2 = panels.get_node("ControlsPanel/Center/Panel").get_global_rect()
	check(panel_rect.position.y >= 0 and panel_rect.end.y <= get_viewport_rect().size.y, "Controls panel fits the 720 px viewport")
	var key_text: String = panels.keyboard_label.text
	check(key_text.contains("Poción") and key_text.contains("Q") and key_text.contains("Pausa") and key_text.contains("Escape"), "Keyboard labels include actual potion/pause bindings")
	for name in ["Left", "Right", "Jump", "Attack", "Parry", "Interact", "Potion", "Pause"]:
		var icon := panels.get_node("ControlsPanel/Center/Panel/Content/ControlsTabs/ANDROID/%sRow/Icon" % name) as TextureRect
		check(icon.texture is AtlasTexture and (icon.texture as AtlasTexture).atlas.resource_path.ends_with("mobile_controls_sheet.png"), "%s reuses mobile sprite sheet" % name)
	panels.controls_tabs.current_tab = 1
	check(panels.controls_tabs.current_tab == 1, "Android tab can be selected")
	panels.close_panels()
	check(not panels.controls_panel.visible, "Controls panel closes")
	panels.queue_free()
	controls.queue_free()
	hud.queue_free()
	await get_tree().process_frame
	print("FINAL UI SMOKE: ", failures.size(), " failures")
	get_tree().quit(0 if failures.is_empty() else 1)
