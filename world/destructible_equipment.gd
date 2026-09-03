class_name DestructibleEquipment
extends StaticBody3D

signal destroyed(equipment_id: String, equipment: DestructibleEquipment)

enum EquipmentType {
	FILTRATION,
	PRODUCTION,
	COLD_STORAGE,
}

@export var equipment_id := "equipment"
@export var display_name := "CRITICAL EQUIPMENT"
@export var owner_company_id := "company"
@export var equipment_type: EquipmentType = EquipmentType.FILTRATION
@export var max_health := 96.0
@export var accent_color := Color("60806d")

var health := 0.0
var _destroyed := false
var _visual: Node3D
var _collision_shape: CollisionShape3D
var _hp_fill: MeshInstance3D
var _status_label: Label3D
var _animated_part: Node3D
var _flash_tween: Tween
var _destruction_tween: Tween
var _flash_materials: Array[Dictionary] = []

func _ready() -> void:
	add_to_group("vita_equipment")
	collision_layer = 2
	collision_mask = 0
	health = max_health
	_build_visual()
	_prepare_flash_materials()
	_update_health_bar()

func _process(delta: float) -> void:
	if _destroyed or _animated_part == null:
		return
	match equipment_type:
		EquipmentType.FILTRATION:
			_animated_part.rotation.y += delta * 0.42
		EquipmentType.PRODUCTION:
			_animated_part.rotation.x += delta * 1.3
		EquipmentType.COLD_STORAGE:
			_animated_part.rotation.z -= delta * 1.8

func take_damage(amount: float, hit_position: Vector3, _hit_normal: Vector3, _shot_direction: Vector3) -> void:
	if _destroyed:
		return
	health = maxf(health - amount, 0.0)
	_flash()
	_update_health_bar()

	var effects := get_tree().get_first_node_in_group("effects")
	if effects:
		effects.spawn_damage_number(hit_position, amount, health <= 0.0)

	if health <= 0.0:
		_die()

func is_destroyed() -> bool:
	return _destroyed

func _die() -> void:
	_destroyed = true
	_collision_shape.set_deferred("disabled", true)
	_status_label.text = display_name + "  /  OFFLINE"
	_status_label.modulate = Color("c98265")
	destroyed.emit(equipment_id, self)

	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	for entry in _flash_materials:
		var material: StandardMaterial3D = entry["material"]
		var original: Color = entry["albedo"]
		material.albedo_color = original.darkened(0.42)
		material.emission = Color.BLACK
		material.emission_energy_multiplier = 0.0

	var effects := get_tree().get_first_node_in_group("effects")
	if effects:
		effects.spawn_equipment_destruction(global_position, accent_color, equipment_type + 1)
		effects.hitstop(0.045, 0.12)

	_destruction_tween = create_tween().set_parallel(true)
	_destruction_tween.tween_property(_visual, "position:y", -0.18, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_destruction_tween.tween_property(_visual, "rotation:z", deg_to_rad(-4.5 if equipment_type % 2 == 0 else 4.5), 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_destruction_tween.tween_property(_visual, "scale:y", 0.76, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var body_material := _make_material(Color("aaa89f"), 0.08, 0.72)
	var light_material := _make_material(Color("d1c8b6"), 0.02, 0.76)
	var dark_material := _make_material(Color("3d4848"), 0.32, 0.5)
	var accent_material := _make_material(accent_color, 0.08, 0.6)
	var rubber_material := _make_material(Color("292f30"), 0.05, 0.86)

	match equipment_type:
		EquipmentType.FILTRATION:
			_build_filtration(body_material, light_material, dark_material, accent_material)
		EquipmentType.PRODUCTION:
			_build_production(body_material, light_material, dark_material, accent_material, rubber_material)
		EquipmentType.COLD_STORAGE:
			_build_cold_storage(body_material, light_material, dark_material, accent_material)

	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = _collision_size_for_type()
	_collision_shape.shape = shape
	_collision_shape.position = Vector3.UP * shape.size.y * 0.5
	add_child(_collision_shape)

	_build_health_display(dark_material, accent_material)

func _build_filtration(body: Material, light: Material, dark: Material, accent: Material) -> void:
	_add_box("Base", Vector3(0, 0.12, 0), Vector3(1.65, 0.24, 1.2), dark)
	_add_box("Skid", Vector3(0, 0.3, 0), Vector3(1.48, 0.18, 1.04), accent)
	for x_value in [-0.38, 0.38]:
		_add_cylinder("FilterTank", Vector3(float(x_value), 0.98, 0), 0.31, 1.38, body)
		_add_torus("TankBand", Vector3(float(x_value), 0.93, 0), 0.29, 0.34, accent)
	_add_cylinder("HeaderPipe", Vector3(0, 1.58, 0), 0.095, 1.08, dark, Vector3(0, 0, 90))
	_add_cylinder("InletPipe", Vector3(-0.73, 0.67, 0.34), 0.08, 0.62, accent, Vector3(90, 0, 0))
	_animated_part = Node3D.new()
	_animated_part.name = "Valve"
	_animated_part.position = Vector3(0, 1.58, 0)
	_visual.add_child(_animated_part)
	_add_torus("ValveWheel", Vector3.ZERO, 0.13, 0.18, accent, Vector3(90, 0, 0), _animated_part)

func _build_production(body: Material, light: Material, dark: Material, accent: Material, rubber: Material) -> void:
	_add_box("Base", Vector3(0, 0.12, 0), Vector3(2.08, 0.24, 1.15), dark)
	_add_box("Housing", Vector3(-0.45, 0.82, 0), Vector3(0.92, 1.28, 1.02), body)
	_add_box("ControlFace", Vector3(-0.45, 0.88, 0.525), Vector3(0.68, 0.7, 0.055), light)
	_add_box("ControlStrip", Vector3(-0.45, 1.17, 0.56), Vector3(0.54, 0.1, 0.04), accent)
	_add_box("Conveyor", Vector3(0.58, 0.47, 0), Vector3(1.18, 0.18, 0.72), rubber)
	for x_value in [0.16, 0.58, 1.0]:
		_add_cylinder("Roller", Vector3(float(x_value), 0.47, 0), 0.075, 0.8, light, Vector3(90, 0, 0))
	_add_box("FillingArch", Vector3(0.55, 1.15, 0), Vector3(0.18, 1.25, 0.92), accent)
	_animated_part = Node3D.new()
	_animated_part.name = "DriveRoller"
	_animated_part.position = Vector3(1.0, 0.47, 0)
	_visual.add_child(_animated_part)
	_add_cylinder("Drive", Vector3.ZERO, 0.105, 0.86, accent, Vector3(90, 0, 0), _animated_part)

func _build_cold_storage(body: Material, light: Material, dark: Material, accent: Material) -> void:
	_add_box("Base", Vector3(0, 0.11, 0), Vector3(1.62, 0.22, 1.18), dark)
	_add_box("Cabinet", Vector3(0, 1.02, 0), Vector3(1.5, 1.78, 1.06), body)
	_add_box("LeftDoor", Vector3(-0.38, 1.0, 0.555), Vector3(0.69, 1.52, 0.06), light)
	_add_box("RightDoor", Vector3(0.38, 1.0, 0.555), Vector3(0.69, 1.52, 0.06), light)
	_add_box("CenterSeal", Vector3(0, 1.0, 0.592), Vector3(0.055, 1.5, 0.045), dark)
	_add_box("StatusBand", Vector3(0, 1.7, 0.59), Vector3(1.22, 0.12, 0.045), accent)
	_add_box("HandleLeft", Vector3(-0.12, 1.02, 0.64), Vector3(0.055, 0.48, 0.055), dark)
	_add_box("HandleRight", Vector3(0.12, 1.02, 0.64), Vector3(0.055, 0.48, 0.055), dark)
	_animated_part = Node3D.new()
	_animated_part.name = "CoolingFan"
	_animated_part.position = Vector3(0, 1.0, -0.565)
	_visual.add_child(_animated_part)
	for angle in [0.0, 90.0]:
		_add_box("FanBlade", Vector3.ZERO, Vector3(0.08, 0.66, 0.045), dark, Vector3(0, 0, float(angle)), _animated_part)
	_add_cylinder("FanHub", Vector3(0, 0, -0.035), 0.11, 0.1, accent, Vector3(90, 0, 0), _animated_part)

func _build_health_display(dark_material: Material, accent_material: Material) -> void:
	_status_label = Label3D.new()
	_status_label.name = "StatusLabel"
	_status_label.text = display_name
	_status_label.position = Vector3(0, 2.3, 0)
	_status_label.font_size = 40
	_status_label.pixel_size = 0.0055
	_status_label.modulate = Color("eee8dc")
	_status_label.outline_modulate = Color(0.08, 0.1, 0.1, 0.9)
	_status_label.outline_size = 9
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status_label.no_depth_test = true
	_visual.add_child(_status_label)

	_add_box("HPBack", Vector3(0, 2.08, 0.04), Vector3(1.12, 0.07, 0.055), dark_material)
	_hp_fill = _add_box("HPFill", Vector3(0, 2.08, 0), Vector3(1.02, 0.035, 0.06), accent_material)

func _update_health_bar() -> void:
	if _hp_fill == null:
		return
	var ratio := clampf(health / max_health, 0.0, 1.0)
	_hp_fill.scale.x = ratio
	_hp_fill.position.x = (ratio - 1.0) * 0.51

func _flash() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween().set_parallel(true)
	for entry in _flash_materials:
		var material: StandardMaterial3D = entry["material"]
		material.albedo_color = Color.WHITE
		material.emission = Color.WHITE
		material.emission_energy_multiplier = 1.8
		_flash_tween.tween_property(material, "albedo_color", entry["albedo"], 0.13)
		_flash_tween.tween_property(material, "emission", entry["emission"], 0.15)
		_flash_tween.tween_property(material, "emission_energy_multiplier", entry["energy"], 0.16)

func _prepare_flash_materials() -> void:
	var seen_materials: Dictionary = {}
	for child in _visual.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var active := mesh_instance.get_active_material(0)
		if active is StandardMaterial3D and not seen_materials.has(active.get_instance_id()):
			var material := active as StandardMaterial3D
			seen_materials[material.get_instance_id()] = true
			_flash_materials.append({
				"material": material,
				"albedo": material.albedo_color,
				"emission": material.emission,
				"energy": material.emission_energy_multiplier,
			})

func _collision_size_for_type() -> Vector3:
	match equipment_type:
		EquipmentType.PRODUCTION:
			return Vector3(2.08, 1.58, 1.15)
		EquipmentType.COLD_STORAGE:
			return Vector3(1.62, 1.95, 1.18)
		_:
			return Vector3(1.65, 1.82, 1.2)

func _add_box(node_name: String, position: Vector3, size: Vector3, material: Material, rotation_degrees_value := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	instance.rotation_degrees = rotation_degrees_value
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	(parent if parent else _visual).add_child(instance)
	return instance

func _add_cylinder(node_name: String, position: Vector3, radius: float, height: float, material: Material, rotation_degrees_value := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	instance.rotation_degrees = rotation_degrees_value
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.96
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 2
	mesh.material = material
	instance.mesh = mesh
	(parent if parent else _visual).add_child(instance)
	return instance

func _add_torus(node_name: String, position: Vector3, inner_radius: float, outer_radius: float, material: Material, rotation_degrees_value := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	instance.rotation_degrees = rotation_degrees_value
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 12
	mesh.ring_segments = 6
	mesh.material = material
	instance.mesh = mesh
	(parent if parent else _visual).add_child(instance)
	return instance

func _make_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	material.emission_enabled = true
	material.emission = Color.BLACK
	material.emission_energy_multiplier = 0.0
	return material
