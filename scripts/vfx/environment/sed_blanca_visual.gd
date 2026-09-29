class_name SedBlancaVisual
extends Node2D

@export_range(64.0, 2000.0, 1.0) var hazard_width := 600.0
@export_range(32.0, 160.0, 1.0) var hazard_height := 80.0

const SURFACE_TEXTURE := preload("res://assets/sprites/environment/santuario_profundo/hazards/sed_blanca/sed_blanca_surface.png")
const EDGE_TEXTURE := preload("res://assets/sprites/environment/santuario_profundo/hazards/sed_blanca/sed_blanca_edge.png")
const TILE_WIDTH := 64.0

@onready var spectral_layer: Node2D = $SpectralLayer



func _ready() -> void:
	_build_surface()


func _process(_delta: float) -> void:
	var ticks := Time.get_ticks_msec()
	var pulse := (sin(ticks * 0.0018) + 1.0) * 0.5
	spectral_layer.modulate = Color(0.9 + pulse * 0.1, 0.96 + pulse * 0.04, 1.0, 0.86 + pulse * 0.08)


func _build_surface() -> void:
	for child in spectral_layer.get_children():
		child.queue_free()

	var body := Polygon2D.new()
	body.name = "CorruptionBody"
	body.polygon = PackedVector2Array([
		Vector2(-hazard_width * 0.5, -hazard_height * 0.5),
		Vector2(hazard_width * 0.5, -hazard_height * 0.5),
		Vector2(hazard_width * 0.5, hazard_height * 0.5),
		Vector2(-hazard_width * 0.5, hazard_height * 0.5),
	])
	body.color = Color(0.09, 0.25, 0.29, 0.96)
	spectral_layer.add_child(body)

	var depth := Polygon2D.new()
	depth.name = "TealDepth"
	depth.polygon = PackedVector2Array([
		Vector2(-hazard_width * 0.5, 8.0),
		Vector2(hazard_width * 0.5, 8.0),
		Vector2(hazard_width * 0.5, hazard_height * 0.5),
		Vector2(-hazard_width * 0.5, hazard_height * 0.5),
	])
	depth.color = Color(0.035, 0.12, 0.16, 0.82)
	spectral_layer.add_child(depth)

	var start_x := -hazard_width * 0.5
	var x := start_x
	while x < hazard_width * 0.5:
		var segment_width := minf(TILE_WIDTH, hazard_width * 0.5 - x)
		_add_texture_segment(SURFACE_TEXTURE, Vector2(x + segment_width * 0.5, -9.0), segment_width, 32.0, 0.7)
		_add_texture_segment(EDGE_TEXTURE, Vector2(x + segment_width * 0.5, -32.0), segment_width, 16.0, 1.0)
		x += segment_width

	var ridge := Polygon2D.new()
	ridge.name = "SpectralRidge"
	var ridge_points := PackedVector2Array()
	ridge_points.append(Vector2(-hazard_width * 0.5, -31.0))
	var point_count := ceili(hazard_width / 24.0)
	for index in range(point_count + 1):
		var px := minf(-hazard_width * 0.5 + index * 24.0, hazard_width * 0.5)
		var py := -34.0 - float((index * 7) % 3) * 2.0
		ridge_points.append(Vector2(px, py))
	ridge_points.append(Vector2(hazard_width * 0.5, -29.0))
	ridge.color = Color(0.84, 1.0, 0.97, 0.78)
	ridge.polygon = ridge_points
	spectral_layer.add_child(ridge)



func _add_texture_segment(texture: Texture2D, segment_position: Vector2, width: float, height: float, alpha: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0.0, 0.0, width, height)
	sprite.position = segment_position
	sprite.modulate.a = alpha
	spectral_layer.add_child(sprite)
