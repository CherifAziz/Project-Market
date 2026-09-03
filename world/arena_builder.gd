class_name ArenaBuilder
extends Node3D

const FLOOR_SHADER := preload("res://world/stylized_floor.gdshader")

var _asphalt: StandardMaterial3D
var _warm_stone: StandardMaterial3D
var _light_stone: StandardMaterial3D
var _warm_concrete: StandardMaterial3D
var _taupe_concrete: StandardMaterial3D
var _dark_metal: StandardMaterial3D
var _glass: StandardMaterial3D
var _road_marking: StandardMaterial3D
var _terracotta: StandardMaterial3D
var _muted_blue: StandardMaterial3D
var _soil: StandardMaterial3D
var _trunk: StandardMaterial3D
var _foliage: StandardMaterial3D
var _foliage_light: StandardMaterial3D

func _ready() -> void:
	_asphalt = _make_material(Color("414443"), 0.0, 0.92)
	_warm_stone = _make_material(Color("b8aa94"), 0.0, 0.76)
	_light_stone = _make_material(Color("d4c8b5"), 0.0, 0.72)
	_warm_concrete = _make_material(Color("a89d8d"), 0.0, 0.82)
	_taupe_concrete = _make_material(Color("827b70"), 0.0, 0.78)
	_dark_metal = _make_material(Color("343d40"), 0.28, 0.46)
	_glass = _make_material(Color("53686b"), 0.32, 0.28)
	_road_marking = _make_material(Color("ddd4c1"), 0.0, 0.88)
	_terracotta = _make_material(Color("9b6450"), 0.0, 0.72)
	_muted_blue = _make_material(Color("657d81"), 0.05, 0.58)
	_soil = _make_material(Color("554538"), 0.0, 1.0)
	_trunk = _make_material(Color("684f3c"), 0.0, 0.96)
	_foliage = _make_material(Color("536b45"), 0.0, 0.94)
	_foliage_light = _make_material(Color("71815a"), 0.0, 0.94)

	_build_ground_and_streets()
	_build_city_shell()
	_build_urban_details()

func _build_ground_and_streets() -> void:
	var floor_material := ShaderMaterial.new()
	floor_material.shader = FLOOR_SHADER
	var floor := _create_solid("ArenaFloor", Vector3(0, -0.16, 0), Vector3(34, 0.3, 29), floor_material)
	var floor_mesh := floor.get_node("Mesh") as MeshInstance3D
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# The collidable perimeter is unchanged; only its material language changes.
	_create_solid("NorthCurb", Vector3(0, 0.18, -14.25), Vector3(34, 0.42, 0.5), _warm_stone)
	_create_solid("SouthCurb", Vector3(0, 0.18, 14.25), Vector3(34, 0.42, 0.5), _warm_stone)
	_create_solid("WestCurb", Vector3(-16.75, 0.18, 0), Vector3(0.5, 0.42, 28), _warm_stone)
	_create_solid("EastCurb", Vector3(16.75, 0.18, 0), Vector3(0.5, 0.42, 28), _warm_stone)

	# A quiet financial-district intersection organizes the composition.
	_create_decor_box(Vector3(0, 0.012, 0), Vector3(7.5, 0.035, 28.4), _asphalt)
	_create_decor_box(Vector3(0, 0.02, 1.0), Vector3(33.4, 0.04, 5.3), _asphalt)
	_create_decor_box(Vector3(-9.9, 0.014, 6.2), Vector3(6.5, 0.032, 6.3), _light_stone)
	_create_decor_box(Vector3(9.8, 0.014, -6.2), Vector3(6.6, 0.032, 6.0), _light_stone)

	# Curbs are visual only so the original movement surface stays untouched.
	for x_value in [-3.86, 3.86]:
		_create_decor_box(Vector3(float(x_value), 0.075, -6.9), Vector3(0.16, 0.14, 8.1), _warm_stone)
		_create_decor_box(Vector3(float(x_value), 0.075, 8.0), Vector3(0.16, 0.14, 6.8), _warm_stone)
	for z_value in [-1.72, 3.72]:
		_create_decor_box(Vector3(-10.2, 0.075, float(z_value)), Vector3(12.7, 0.14, 0.16), _warm_stone)
		_create_decor_box(Vector3(10.2, 0.075, float(z_value)), Vector3(12.7, 0.14, 0.16), _warm_stone)

	# Restrained road markings and two zebra crossings guide the eye.
	for z_value in [-11.0, -7.3, 7.1, 10.8]:
		_create_decor_box(Vector3(0, 0.046, float(z_value)), Vector3(0.12, 0.018, 1.8), _road_marking)
	for x_value in [-13.0, -9.2, 8.6, 12.4]:
		_create_decor_box(Vector3(float(x_value), 0.052, 1.0), Vector3(1.9, 0.018, 0.11), _road_marking)
	_add_crosswalk_vertical(-4.0)
	_add_crosswalk_horizontal(5.6)

func _add_crosswalk_vertical(z_center: float) -> void:
	for index in range(7):
		var z_offset := (float(index) - 3.0) * 0.48
		_create_decor_box(Vector3(0, 0.054, z_center + z_offset), Vector3(5.8, 0.02, 0.26), _road_marking)

func _add_crosswalk_horizontal(x_center: float) -> void:
	for index in range(6):
		var x_offset := (float(index) - 2.5) * 0.48
		_create_decor_box(Vector3(x_center + x_offset, 0.055, 1.0), Vector3(0.26, 0.02, 3.9), _road_marking)

func _build_city_shell() -> void:
	var buildings := [
		{"position": Vector3(-14.8, 0, -9.7), "size": Vector3(3.8, 8.0, 5.2), "facade": _warm_concrete, "accent": _terracotta},
		{"position": Vector3(-15.1, 0, -3.0), "size": Vector3(3.1, 5.4, 4.7), "facade": _light_stone, "accent": _muted_blue},
		{"position": Vector3(-15.0, 0, 4.1), "size": Vector3(3.5, 9.2, 5.0), "facade": _taupe_concrete, "accent": _warm_stone},
		{"position": Vector3(-14.8, 0, 10.5), "size": Vector3(4.0, 6.0, 4.5), "facade": _warm_concrete, "accent": _terracotta},
		{"position": Vector3(14.8, 0, -10.0), "size": Vector3(3.9, 6.6, 4.8), "facade": _light_stone, "accent": _muted_blue},
		{"position": Vector3(15.1, 0, -3.6), "size": Vector3(3.0, 10.5, 4.7), "facade": _taupe_concrete, "accent": _warm_stone},
		{"position": Vector3(14.9, 0, 3.3), "size": Vector3(3.6, 7.4, 5.2), "facade": _warm_concrete, "accent": _terracotta},
		{"position": Vector3(15.0, 0, 10.0), "size": Vector3(4.1, 5.5, 4.8), "facade": _light_stone, "accent": _muted_blue},
		{"position": Vector3(-9.3, 0, -13.1), "size": Vector3(6.0, 9.8, 3.1), "facade": _taupe_concrete, "accent": _terracotta},
		{"position": Vector3(-2.0, 0, -13.0), "size": Vector3(6.2, 6.4, 3.2), "facade": _light_stone, "accent": _muted_blue},
		{"position": Vector3(5.3, 0, -13.1), "size": Vector3(5.8, 11.5, 3.0), "facade": _warm_concrete, "accent": _warm_stone},
		{"position": Vector3(11.5, 0, -13.0), "size": Vector3(4.3, 7.8, 3.2), "facade": _light_stone, "accent": _terracotta},
	]
	for spec_value in buildings:
		var spec: Dictionary = spec_value
		var building_position: Vector3 = spec["position"]
		var building_size: Vector3 = spec["size"]
		var facade: Material = spec["facade"]
		var accent: Material = spec["accent"]
		_add_building(building_position, building_size, facade, accent)

func _add_building(base_position: Vector3, size: Vector3, facade: Material, accent: Material) -> void:
	var center := base_position + Vector3.UP * size.y * 0.5
	var body := _create_solid("Building", center, size, facade)
	body.add_to_group("camera_occluder")
	var side_facing_x := absf(base_position.x) > absf(base_position.z)
	var inward_sign := -signf(base_position.x if side_facing_x else base_position.z)

	# Dark plinth and restrained canopy give each primitive a believable scale.
	var plinth_position: Vector3
	var plinth_size: Vector3
	var canopy_position: Vector3
	var canopy_size: Vector3
	if side_facing_x:
		var face_x := inward_sign * (size.x * 0.5 + 0.025)
		plinth_position = Vector3(face_x, -size.y * 0.5 + 0.42, 0)
		plinth_size = Vector3(0.06, 0.72, size.z * 0.92)
		canopy_position = Vector3(face_x + inward_sign * 0.28, -size.y * 0.5 + 1.35, 0)
		canopy_size = Vector3(0.62, 0.12, minf(2.0, size.z * 0.55))
	else:
		var face_z := inward_sign * (size.z * 0.5 + 0.025)
		plinth_position = Vector3(0, -size.y * 0.5 + 0.42, face_z)
		plinth_size = Vector3(size.x * 0.92, 0.72, 0.06)
		canopy_position = Vector3(0, -size.y * 0.5 + 1.35, face_z + inward_sign * 0.28)
		canopy_size = Vector3(minf(2.0, size.x * 0.55), 0.12, 0.62)
	body.add_child(_create_mesh_box("Plinth", plinth_position, plinth_size, _dark_metal))
	body.add_child(_create_mesh_box("Canopy", canopy_position, canopy_size, accent))

	# Large tinted bays replace the previous glowing window confetti.
	var row_count := clampi(int((size.y - 1.8) / 1.25), 2, 7)
	var column_count := 3
	for row in range(row_count):
		for column in range(column_count):
			var row_y := -size.y * 0.5 + 1.45 + float(row) * 1.18
			var column_ratio := float(column) / float(column_count - 1)
			var window_position: Vector3
			var window_size: Vector3
			if side_facing_x:
				window_position = Vector3(inward_sign * (size.x * 0.5 + 0.032), row_y, lerpf(-size.z * 0.3, size.z * 0.3, column_ratio))
				window_size = Vector3(0.045, 0.58, minf(0.72, size.z * 0.18))
			else:
				window_position = Vector3(lerpf(-size.x * 0.3, size.x * 0.3, column_ratio), row_y, inward_sign * (size.z * 0.5 + 0.032))
				window_size = Vector3(minf(0.76, size.x * 0.18), 0.58, 0.045)
			body.add_child(_create_mesh_box("Window", window_position, window_size, _glass))

	# A simple parapet silhouette catches the low sun.
	var parapet_y := size.y * 0.5 + 0.22
	body.add_child(_create_mesh_box("RoofFront", Vector3(0, parapet_y, -size.z * 0.43), Vector3(size.x * 0.92, 0.35, 0.14), _warm_stone))
	body.add_child(_create_mesh_box("RoofBack", Vector3(0, parapet_y, size.z * 0.43), Vector3(size.x * 0.92, 0.35, 0.14), _warm_stone))
	body.add_child(_create_mesh_box("RoofLeft", Vector3(-size.x * 0.43, parapet_y, 0), Vector3(0.14, 0.35, size.z * 0.78), _warm_stone))
	body.add_child(_create_mesh_box("RoofRight", Vector3(size.x * 0.43, parapet_y, 0), Vector3(0.14, 0.35, size.z * 0.78), _warm_stone))

func _build_urban_details() -> void:
	# Existing cover remains mechanically identical and becomes planted street furniture.
	_create_solid("CoverA", Vector3(-4.4, 0.38, -1.2), Vector3(2.6, 0.75, 0.52), _warm_stone)
	_create_decor_box(Vector3(-4.4, 0.77, -1.2), Vector3(2.25, 0.08, 0.42), _soil)
	_add_planter_foliage(Vector3(-4.4, 0.83, -1.2), 4, 0.34)
	_create_solid("CoverB", Vector3(4.2, 0.38, 3.1), Vector3(2.5, 0.75, 0.52), _warm_stone)
	_create_decor_box(Vector3(4.2, 0.77, 3.1), Vector3(2.15, 0.08, 0.42), _soil)
	_add_planter_foliage(Vector3(4.2, 0.83, 3.1), 4, 0.34)

	for tree_position in [
		Vector3(-11.5, 0, -5.4), Vector3(-11.0, 0, 5.0),
		Vector3(11.4, 0, -5.1), Vector3(10.7, 0, 5.2), Vector3(7.8, 0, -10.8),
	]:
		_add_tree(tree_position)

	_add_bench(Vector3(10.2, 0, -9.3), PI)
	_add_bench(Vector3(-8.7, 0, -10.6), PI * 0.5)

	for lamp_position in [Vector3(-6.2, 0, -6.6), Vector3(6.2, 0, -6.6), Vector3(-6.2, 0, 8.4), Vector3(6.2, 0, 8.4)]:
		_add_lamp_post(lamp_position)

	for bollard_x in [-6.2, -5.35, -4.5, 4.45, 5.3, 6.15]:
		_add_bollard(Vector3(float(bollard_x), 0, 3.95))

	_add_steps(Vector3(-12.8, 0, -3.0), Vector3(1, 0, 0))
	_add_steps(Vector3(12.8, 0, 3.3), Vector3(-1, 0, 0))
	_add_steps(Vector3(-2.0, 0, -11.5), Vector3(0, 0, 1))

func _add_planter_foliage(center: Vector3, count: int, spread: float) -> void:
	for index in range(count):
		var ratio := float(index) / maxf(float(count - 1), 1.0)
		var position := center + Vector3(lerpf(-spread, spread, ratio), 0.18 + 0.05 * float(index % 2), 0)
		_create_decor_sphere(position, 0.22 + 0.03 * float(index % 2), _foliage if index % 2 == 0 else _foliage_light)

func _add_tree(base_position: Vector3) -> void:
	_create_decor_box(base_position + Vector3.UP * 0.18, Vector3(1.25, 0.35, 1.25), _warm_stone)
	_create_decor_box(base_position + Vector3.UP * 0.37, Vector3(0.98, 0.08, 0.98), _soil)
	_create_decor_cylinder(base_position + Vector3.UP * 1.15, 0.14, 1.7, _trunk)
	_create_decor_sphere(base_position + Vector3(-0.28, 2.05, 0.05), 0.72, _foliage)
	_create_decor_sphere(base_position + Vector3(0.32, 2.0, 0.12), 0.68, _foliage_light)
	_create_decor_sphere(base_position + Vector3(0.04, 2.48, -0.08), 0.76, _foliage)

func _add_bench(base_position: Vector3, rotation_y: float) -> void:
	var bench := Node3D.new()
	bench.name = "Bench"
	bench.position = base_position
	bench.rotation.y = rotation_y
	add_child(bench)
	bench.add_child(_create_mesh_box("Seat", Vector3(0, 0.42, 0), Vector3(1.65, 0.13, 0.48), _terracotta))
	bench.add_child(_create_mesh_box("Back", Vector3(0, 0.78, 0.19), Vector3(1.65, 0.62, 0.1), _terracotta))
	bench.add_child(_create_mesh_box("LegLeft", Vector3(-0.62, 0.2, 0), Vector3(0.12, 0.4, 0.36), _dark_metal))
	bench.add_child(_create_mesh_box("LegRight", Vector3(0.62, 0.2, 0), Vector3(0.12, 0.4, 0.36), _dark_metal))

func _add_lamp_post(base_position: Vector3) -> void:
	_create_decor_cylinder(base_position + Vector3.UP * 1.25, 0.075, 2.5, _dark_metal)
	_create_decor_box(base_position + Vector3(0, 2.46, -0.14), Vector3(0.22, 0.18, 0.48), _dark_metal)
	_create_decor_box(base_position + Vector3(0, 2.39, -0.26), Vector3(0.15, 0.04, 0.22), _light_stone)

func _add_bollard(base_position: Vector3) -> void:
	_create_decor_cylinder(base_position + Vector3.UP * 0.34, 0.09, 0.68, _dark_metal)

func _add_steps(base_position: Vector3, direction: Vector3) -> void:
	for index in range(3):
		var depth := 0.42 + float(index) * 0.22
		var step_position := base_position - direction * float(index) * 0.22 + Vector3.UP * (0.055 + float(index) * 0.055)
		var step_size := Vector3(1.8, 0.11 + float(index) * 0.11, depth)
		if absf(direction.x) > 0.5:
			step_size = Vector3(depth, 0.11 + float(index) * 0.11, 1.8)
		_create_decor_box(step_position, step_size, _warm_stone)

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

func _create_decor_cylinder(position: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = "CylinderDetail"
	instance.position = position
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.86
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	mesh.material = material
	instance.mesh = mesh
	add_child(instance)
	return instance

func _create_decor_sphere(position: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = "Foliage"
	instance.position = position
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = material
	instance.mesh = mesh
	add_child(instance)
	return instance

func _make_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
