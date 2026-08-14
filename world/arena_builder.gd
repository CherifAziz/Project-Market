class_name ArenaBuilder
extends Node3D

const TARGET_SCENE := preload("res://combat/damageable_target.tscn")
const FLOOR_SHADER := preload("res://world/stylized_floor.gdshader")

var _dark_material: StandardMaterial3D
var _cyan_material: StandardMaterial3D
var _magenta_material: StandardMaterial3D
var _warm_material: StandardMaterial3D

func _ready() -> void:
	_dark_material = _make_material(Color("090e20"), 0.82, 0.22)
	_cyan_material = _make_emissive(Color("28ddef"), 4.5)
	_magenta_material = _make_emissive(Color("ff277f"), 4.8)
	_warm_material = _make_emissive(Color("ffc568"), 3.2)
	_build_floor()
	_build_city_shell()
	_build_arena_details()
	_spawn_targets()

func _build_floor() -> void:
	var floor_material := ShaderMaterial.new()
	floor_material.shader = FLOOR_SHADER
	var floor := _create_solid("ArenaFloor", Vector3(0, -0.16, 0), Vector3(34, 0.3, 29), floor_material)
	var floor_mesh := floor.get_node("Mesh") as MeshInstance3D
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_create_solid("NorthCurb", Vector3(0, 0.18, -14.25), Vector3(34, 0.42, 0.5), _dark_material)
	_create_solid("SouthCurb", Vector3(0, 0.18, 14.25), Vector3(34, 0.42, 0.5), _dark_material)
	_create_solid("WestCurb", Vector3(-16.75, 0.18, 0), Vector3(0.5, 0.42, 28), _dark_material)
	_create_solid("EastCurb", Vector3(16.75, 0.18, 0), Vector3(0.5, 0.42, 28), _dark_material)

func _build_city_shell() -> void:
	var buildings := [
		{"position": Vector3(-14.8, 0, -9.7), "size": Vector3(3.8, 8.0, 5.2), "accent": _cyan_material},
		{"position": Vector3(-15.1, 0, -3.0), "size": Vector3(3.1, 5.4, 4.7), "accent": _magenta_material},
		{"position": Vector3(-15.0, 0, 4.1), "size": Vector3(3.5, 9.2, 5.0), "accent": _warm_material},
		{"position": Vector3(-14.8, 0, 10.5), "size": Vector3(4.0, 6.0, 4.5), "accent": _cyan_material},
		{"position": Vector3(14.8, 0, -10.0), "size": Vector3(3.9, 6.6, 4.8), "accent": _magenta_material},
		{"position": Vector3(15.1, 0, -3.6), "size": Vector3(3.0, 10.5, 4.7), "accent": _cyan_material},
		{"position": Vector3(14.9, 0, 3.3), "size": Vector3(3.6, 7.4, 5.2), "accent": _magenta_material},
		{"position": Vector3(15.0, 0, 10.0), "size": Vector3(4.1, 5.5, 4.8), "accent": _warm_material},
		{"position": Vector3(-9.3, 0, -13.1), "size": Vector3(6.0, 9.8, 3.1), "accent": _magenta_material},
		{"position": Vector3(-2.0, 0, -13.0), "size": Vector3(6.2, 6.4, 3.2), "accent": _cyan_material},
		{"position": Vector3(5.3, 0, -13.1), "size": Vector3(5.8, 11.5, 3.0), "accent": _warm_material},
		{"position": Vector3(11.5, 0, -13.0), "size": Vector3(4.3, 7.8, 3.2), "accent": _cyan_material},
	]
	for spec in buildings:
		_add_building(spec.position, spec.size, spec.accent)

	_add_neon_light(Vector3(-12.7, 3.2, -3.0), Color("ff278b"), 7.0, 10.0)
	_add_neon_light(Vector3(12.8, 3.5, -3.5), Color("39eaff"), 7.0, 10.0)
	_add_neon_light(Vector3(4.8, 4.3, -11.1), Color("ffc05b"), 4.5, 8.0)

func _add_building(base_position: Vector3, size: Vector3, accent: Material) -> void:
	var center := base_position + Vector3.UP * size.y * 0.5
	var body := _create_solid("Building", center, size, _dark_material)
	var roof := _create_mesh_box("RoofNeon", Vector3(0, size.y * 0.5 + 0.08, 0), Vector3(size.x * 0.9, 0.08, size.z * 0.9), accent)
	body.add_child(roof)

	var side_facing_x := absf(base_position.x) > absf(base_position.z)
	var row_count := clampi(int(size.y / 1.3), 3, 7)
	var column_count := 3
	for row in range(row_count):
		for column in range(column_count):
			if (row + column + int(absf(base_position.x))) % 4 == 0:
				continue
			var window_position: Vector3
			var window_size: Vector3
			if side_facing_x:
				var face_x := -signf(base_position.x) * (size.x * 0.5 + 0.022)
				window_position = Vector3(face_x, -size.y * 0.5 + 0.9 + row * 1.15, lerpf(-size.z * 0.32, size.z * 0.32, float(column) / 2.0))
				window_size = Vector3(0.045, 0.25, minf(0.52, size.z * 0.15))
			else:
				var face_z := -signf(base_position.z) * (size.z * 0.5 + 0.022)
				window_position = Vector3(lerpf(-size.x * 0.32, size.x * 0.32, float(column) / 2.0), -size.y * 0.5 + 0.9 + row * 1.15, face_z)
				window_size = Vector3(minf(0.58, size.x * 0.15), 0.25, 0.045)
			var window := _create_mesh_box("Window", window_position, window_size, accent)
			body.add_child(window)

func _build_arena_details() -> void:
	for z in [-9.0, -3.0, 3.0, 9.0]:
		_create_decor_box(Vector3(-5.2, 0.022, z), Vector3(1.8, 0.025, 0.075), _cyan_material)
		_create_decor_box(Vector3(5.2, 0.022, z), Vector3(1.8, 0.025, 0.075), _magenta_material)

	_create_solid("CoverA", Vector3(-4.4, 0.38, -1.2), Vector3(2.6, 0.75, 0.52), _dark_material)
	_create_decor_box(Vector3(-4.4, 0.79, -1.2), Vector3(2.2, 0.065, 0.58), _cyan_material)
	_create_solid("CoverB", Vector3(4.2, 0.38, 3.1), Vector3(2.5, 0.75, 0.52), _dark_material)
	_create_decor_box(Vector3(4.2, 0.79, 3.1), Vector3(2.1, 0.065, 0.58), _magenta_material)

	for position in [Vector3(-10.0, 0.08, -7.5), Vector3(9.0, 0.08, 7.0), Vector3(-8.0, 0.08, 8.3)]:
		var puddle_material := _make_material(Color(0.015, 0.045, 0.075, 0.68), 0.82, 0.07, true)
		_create_decor_box(position, Vector3(3.2, 0.018, 1.15), puddle_material)

func _spawn_targets() -> void:
	var target_positions := [
		Vector3(-8.5, 0, -7.5), Vector3(-3.5, 0, -8.8), Vector3(2.5, 0, -8.0), Vector3(8.7, 0, -7.0),
		Vector3(-9.5, 0, -1.4), Vector3(8.7, 0, 0.0), Vector3(-7.2, 0, 5.5), Vector3(-2.2, 0, 7.5),
		Vector3(3.2, 0, 7.2), Vector3(9.2, 0, 7.8), Vector3(1.0, 0, 1.5),
	]
	for index in range(target_positions.size()):
		var target := TARGET_SCENE.instantiate() as DamageableTarget
		target.position = target_positions[index]
		target.rotation.y = index * 0.57
		target.accent_color = Color("ff318e") if index % 2 == 0 else Color("45eaff")
		add_child(target)

func _create_solid(node_name: String, position: Vector3, size: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var mesh := _create_mesh_box("Mesh", Vector3.ZERO, size, material)
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body

func _create_decor_box(position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := _create_mesh_box("Detail", position, size, material)
	add_child(mesh)
	return mesh

func _create_mesh_box(node_name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	return instance

func _add_neon_light(position: Vector3, color: Color, energy: float, light_range: float) -> void:
	var light := OmniLight3D.new()
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.35
	light.shadow_enabled = false
	add_child(light)

func _make_material(color: Color, metallic: float, roughness: float, transparent := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func _make_emissive(color: Color, energy: float) -> StandardMaterial3D:
	var material := _make_material(color.darkened(0.36), 0.42, 0.18)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
