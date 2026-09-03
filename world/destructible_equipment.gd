class_name DestructibleEquipment
extends StaticBody3D

signal destroyed(equipment_id: String, equipment: DestructibleEquipment)
signal state_changed(equipment: DestructibleEquipment)
signal attacked(equipment_id: String, equipment: DestructibleEquipment, hit_position: Vector3)

enum EquipmentType {
	FILTRATION,
	PRODUCTION,
	COLD_STORAGE,
	TRANSFORMER,
	SWITCHGEAR,
	GENERATOR,
}

enum OperationalState {
	NOMINAL,
	DAMAGED,
	OFFLINE,
}

@export var equipment_id := "equipment"
@export var display_name := "CRITICAL EQUIPMENT"
@export var owner_company_id := "company"
@export var owner_ticker := "COMP"
@export var equipment_type: EquipmentType = EquipmentType.FILTRATION
@export var max_health := 96.0
@export_range(0.1, 0.9, 0.05) var damaged_health_ratio := 0.55
@export var accent_color := Color("60806d")

var health := 0.0
var operational_state: OperationalState = OperationalState.NOMINAL
var _destroyed := false
var _attack_reported := false
var _offline_since_msec := -1
var _visual: Node3D
var _collision_shape: CollisionShape3D
var _animated_part: Node3D
var _damage_details: Node3D
var _damage_smoke: GPUParticles3D
var _warning_material: StandardMaterial3D
var _flash_tween: Tween
var _destruction_tween: Tween
var _flash_materials: Array[Dictionary] = []

func _ready() -> void:
	add_to_group("company_equipment")
	add_to_group("%s_equipment" % owner_company_id)
	collision_layer = 2
	collision_mask = 0
	health = max_health
	_build_visual()
	_prepare_flash_materials()

func _process(delta: float) -> void:
	if not _destroyed and _animated_part:
		match equipment_type:
			EquipmentType.FILTRATION:
				_animated_part.rotation.y += delta * 0.42
			EquipmentType.PRODUCTION:
				_animated_part.rotation.x += delta * 1.3
			EquipmentType.COLD_STORAGE:
				_animated_part.rotation.z -= delta * 1.8
			EquipmentType.TRANSFORMER:
				_animated_part.rotation.z += delta * 0.7
			EquipmentType.GENERATOR:
				_animated_part.rotation.x += delta * 2.2
	if operational_state == OperationalState.DAMAGED and _warning_material:
		var pulse := 0.45 + maxf(sin(Time.get_ticks_msec() * 0.009), 0.0) * 0.75
		_warning_material.emission_energy_multiplier = pulse

func take_damage(amount: float, hit_position: Vector3, _hit_normal: Vector3, _shot_direction: Vector3) -> void:
	if _destroyed:
		return
	if amount > 0.0 and not _attack_reported:
		_attack_reported = true
		attacked.emit(equipment_id, self, hit_position)
	health = maxf(health - amount, 0.0)
	if health > 0.0 and operational_state == OperationalState.NOMINAL and get_health_ratio() <= damaged_health_ratio:
		_enter_damaged_state()
	_flash()

	var effects := get_tree().get_first_node_in_group("effects")
	if effects:
		effects.spawn_damage_number(hit_position, amount, health <= 0.0)

	if health <= 0.0:
		_die()

func is_destroyed() -> bool:
	return _destroyed

func get_health_ratio() -> float:
	return clampf(health / maxf(max_health, 0.001), 0.0, 1.0)

func get_status_text() -> String:
	match operational_state:
		OperationalState.DAMAGED:
			return "DAMAGED"
		OperationalState.OFFLINE:
			return "OFFLINE"
		_:
			return "NOMINAL"

func get_context_color() -> Color:
	match operational_state:
		OperationalState.DAMAGED:
			return Color("d39a63")
		OperationalState.OFFLINE:
			return Color("c77c60")
		_:
			return accent_color.lightened(0.2)

func get_context_world_position() -> Vector3:
	return global_position + Vector3.UP * (_collision_size_for_type().y + 0.45)

func is_context_relevant() -> bool:
	return operational_state != OperationalState.OFFLINE or Time.get_ticks_msec() - _offline_since_msec < 650

func _enter_damaged_state() -> void:
	operational_state = OperationalState.DAMAGED
	_damage_details.visible = true
	_damage_smoke.emitting = true
	for entry in _flash_materials:
		var material: StandardMaterial3D = entry["material"]
		var damaged_color: Color = (entry["albedo"] as Color).darkened(0.16)
		entry["target_albedo"] = damaged_color
		material.albedo_color = damaged_color
	_warning_material.albedo_color = Color("d39458")
	_warning_material.emission = Color("d39458")
	_warning_material.emission_energy_multiplier = 0.7
	state_changed.emit(self)
	var audio := get_tree().get_first_node_in_group("audio_service")
	if audio and audio.has_method("play_world"):
		audio.play_world(&"machine_damaged", global_position + Vector3.UP * 0.8, 0.035)

func _die() -> void:
	_destroyed = true
	operational_state = OperationalState.OFFLINE
	_offline_since_msec = Time.get_ticks_msec()
	_collision_shape.set_deferred("disabled", true)
	_damage_details.visible = true
	_damage_smoke.emitting = false
	_warning_material.albedo_color = Color("3b3e3b")
	_warning_material.emission = Color.BLACK
	_warning_material.emission_energy_multiplier = 0.0
	state_changed.emit(self)
	destroyed.emit(equipment_id, self)

	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	for entry in _flash_materials:
		var material: StandardMaterial3D = entry["material"]
		var original: Color = entry["albedo"]
		material.albedo_color = original.darkened(0.42)
		material.emission = Color.BLACK
		material.emission_energy_multiplier = 0.0

	var audio := get_tree().get_first_node_in_group("audio_service")
	if audio and audio.has_method("play_world"):
		audio.play_world(&"machine_destroyed", global_position + Vector3.UP * 0.7, 0.03)

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
		EquipmentType.TRANSFORMER:
			_build_transformer(body_material, light_material, dark_material, accent_material, rubber_material)
		EquipmentType.SWITCHGEAR:
			_build_switchgear(body_material, light_material, dark_material, accent_material)
		EquipmentType.GENERATOR:
			_build_generator(body_material, light_material, dark_material, accent_material, rubber_material)

	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = _collision_size_for_type()
	_collision_shape.shape = shape
	_collision_shape.position = Vector3.UP * shape.size.y * 0.5
	add_child(_collision_shape)

	_build_damage_details()

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

func _build_transformer(body: Material, light: Material, dark: Material, accent: Material, rubber: Material) -> void:
	_add_box("Base", Vector3(0, 0.12, 0), Vector3(1.72, 0.24, 1.25), dark)
	_add_box("TransformerCore", Vector3(0, 0.9, 0), Vector3(1.26, 1.34, 0.94), body)
	_add_box("FrontPlate", Vector3(0, 0.92, 0.495), Vector3(0.86, 0.72, 0.055), light)
	_add_box("CopperBand", Vector3(0, 1.33, 0.512), Vector3(0.92, 0.12, 0.05), accent)
	for side in [-1.0, 1.0]:
		for z_value in [-0.34, -0.17, 0.0, 0.17, 0.34]:
			_add_box("RadiatorFin", Vector3(float(side) * 0.72, 0.87, float(z_value)), Vector3(0.18, 0.95, 0.055), dark)
	for x_value in [-0.38, 0.0, 0.38]:
		_add_cylinder("Bushing", Vector3(float(x_value), 1.78, 0), 0.09, 0.55, rubber)
		_add_torus("BushingRing", Vector3(float(x_value), 1.67, 0), 0.08, 0.13, accent)
	_animated_part = Node3D.new()
	_animated_part.name = "CoolingFan"
	_animated_part.position = Vector3(0, 0.88, 0.54)
	_visual.add_child(_animated_part)
	for angle in [0.0, 90.0]:
		_add_box("FanBlade", Vector3.ZERO, Vector3(0.08, 0.54, 0.04), dark, Vector3(0, 0, float(angle)), _animated_part)
	_add_cylinder("FanHub", Vector3(0, 0, 0.03), 0.09, 0.09, accent, Vector3(90, 0, 0), _animated_part)

func _build_switchgear(body: Material, light: Material, dark: Material, accent: Material) -> void:
	_add_box("Base", Vector3(0, 0.11, 0), Vector3(1.68, 0.22, 1.08), dark)
	_add_box("Cabinet", Vector3(0, 1.0, 0), Vector3(1.55, 1.74, 0.96), body)
	for x_value in [-0.5, 0.0, 0.5]:
		_add_box("BreakerDoor", Vector3(float(x_value), 1.02, 0.505), Vector3(0.44, 1.46, 0.055), light)
		_add_box("BreakerSlot", Vector3(float(x_value), 1.12, 0.545), Vector3(0.22, 0.09, 0.035), dark)
		_add_box("Indicator", Vector3(float(x_value), 1.5, 0.55), Vector3(0.1, 0.1, 0.04), accent)
	_add_box("BusHousing", Vector3(0, 1.82, 0), Vector3(1.62, 0.18, 1.0), dark)
	_add_box("SafetyStripe", Vector3(0, 0.47, 0.55), Vector3(1.34, 0.1, 0.045), accent)

func _build_generator(body: Material, light: Material, dark: Material, accent: Material, rubber: Material) -> void:
	_add_box("Base", Vector3(0, 0.12, 0), Vector3(2.0, 0.24, 1.2), dark)
	_add_box("GeneratorHousing", Vector3(0, 0.82, 0), Vector3(1.76, 1.16, 1.04), body)
	_add_cylinder("Stator", Vector3(0, 0.9, 0), 0.43, 1.72, light, Vector3(0, 0, 90))
	for x_value in [-0.62, 0.0, 0.62]:
		_add_torus("CopperCoil", Vector3(float(x_value), 0.9, 0), 0.4, 0.47, accent, Vector3(0, 0, 90))
	_add_box("TerminalBox", Vector3(0.5, 1.45, 0), Vector3(0.62, 0.34, 0.62), dark)
	_add_box("TerminalFace", Vector3(0.5, 1.45, 0.335), Vector3(0.42, 0.16, 0.055), accent)
	_animated_part = Node3D.new()
	_animated_part.name = "Rotor"
	_animated_part.position = Vector3(-0.9, 0.9, 0)
	_visual.add_child(_animated_part)
	_add_cylinder("RotorHub", Vector3.ZERO, 0.2, 0.16, rubber, Vector3(0, 0, 90), _animated_part)
	for angle in [0.0, 90.0]:
		_add_box("RotorSpoke", Vector3.ZERO, Vector3(0.08, 0.72, 0.08), accent, Vector3(float(angle), 0, 0), _animated_part)

func _build_damage_details() -> void:
	_damage_details = Node3D.new()
	_damage_details.name = "DamageDetails"
	_damage_details.visible = false
	_visual.add_child(_damage_details)
	var size := _collision_size_for_type()
	var front_z := size.z * 0.5 + 0.035
	var scorch := _make_material(Color("3b3732"), 0.12, 0.9)
	_warning_material = _make_material(Color("d39458"), 0.05, 0.58)
	_warning_material.emission = Color("d39458")
	_add_box("ScorchedPanel", Vector3(size.x * 0.19, minf(size.y * 0.68, 1.25), front_z), Vector3(0.46, 0.34, 0.045), scorch, Vector3(0, 0, -8), _damage_details)
	_add_box("WarningLamp", Vector3(-size.x * 0.28, minf(size.y * 0.77, 1.52), front_z + 0.018), Vector3(0.12, 0.12, 0.06), _warning_material, Vector3.ZERO, _damage_details)

	_damage_smoke = GPUParticles3D.new()
	_damage_smoke.name = "DamageSmoke"
	_damage_smoke.emitting = false
	_damage_smoke.amount = 4
	_damage_smoke.lifetime = 1.35
	_damage_smoke.randomness = 0.85
	_damage_smoke.visibility_aabb = AABB(Vector3(-1, -0.5, -1), Vector3(2, 3, 2))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.12
	process.direction = Vector3.UP
	process.spread = 24.0
	process.initial_velocity_min = 0.16
	process.initial_velocity_max = 0.42
	process.gravity = Vector3(0, 0.3, 0)
	process.scale_min = 0.6
	process.scale_max = 1.1
	process.color = Color(0.24, 0.23, 0.21, 0.38)
	_damage_smoke.process_material = process
	var smoke_mesh := SphereMesh.new()
	smoke_mesh.radius = 0.12
	smoke_mesh.height = 0.24
	smoke_mesh.radial_segments = 6
	smoke_mesh.rings = 3
	var smoke_material := _make_material(Color(0.25, 0.24, 0.22, 0.34), 0.0, 1.0)
	smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mesh.material = smoke_material
	_damage_smoke.draw_pass_1 = smoke_mesh
	_damage_smoke.position = Vector3(size.x * 0.18, size.y * 0.78, 0)
	_damage_details.add_child(_damage_smoke)

func _flash() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween().set_parallel(true)
	for entry in _flash_materials:
		var material: StandardMaterial3D = entry["material"]
		material.albedo_color = Color.WHITE
		material.emission = Color.WHITE
		material.emission_energy_multiplier = 1.8
		_flash_tween.tween_property(material, "albedo_color", entry["target_albedo"], 0.13)
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
				"target_albedo": material.albedo_color,
				"emission": material.emission,
				"energy": material.emission_energy_multiplier,
			})

func _collision_size_for_type() -> Vector3:
	match equipment_type:
		EquipmentType.PRODUCTION:
			return Vector3(2.08, 1.58, 1.15)
		EquipmentType.COLD_STORAGE:
			return Vector3(1.62, 1.95, 1.18)
		EquipmentType.TRANSFORMER:
			return Vector3(1.72, 2.08, 1.25)
		EquipmentType.SWITCHGEAR:
			return Vector3(1.68, 1.95, 1.08)
		EquipmentType.GENERATOR:
			return Vector3(2.0, 1.7, 1.2)
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
