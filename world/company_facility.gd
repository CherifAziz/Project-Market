class_name CompanyFacility
extends Node3D

signal equipment_destroyed(company_id: String, equipment_id: String, destroyed_count: int, total_count: int)
signal equipment_attacked(company_id: String, equipment_id: String, world_position: Vector3)

enum FacilityType {
	MEDICAL,
	ENERGY,
}

const EQUIPMENT_SCENE := preload("res://world/destructible_equipment.tscn")
const LOOT_SCENE := preload("res://world/loot_pickup.tscn")

@export var company: CompanyDefinition
@export var facility_type: FacilityType = FacilityType.MEDICAL

var destroyed_count := 0
var _equipment: Array[DestructibleEquipment] = []

func _ready() -> void:
	add_to_group("company_facility")
	if company == null:
		push_error("CompanyFacility requires a CompanyDefinition resource.")
		return
	add_to_group("%s_facility" % company.company_id)
	if facility_type == FacilityType.ENERGY:
		_build_energy_shell()
	else:
		_build_medical_shell()
	_spawn_equipment()
	_spawn_loot()

func _spawn_loot() -> void:
	# Clear silhouettes in the guarded service aisle, not hidden behind machines.
	var specs: Array[Dictionary]
	if facility_type == FacilityType.ENERGY:
		specs = [
			{"data": "arc_module", "at": Vector3(-1.85, 0.08, 1.5)},
			{"data": "copper_spool", "at": Vector3(0.0, 0.08, 1.5)},
			{"data": "power_component", "at": Vector3(1.95, 0.08, 1.5)},
		]
	else:
		specs = [
			{"data": "vita_prototype", "at": Vector3(-0.5, 0.08, 1.7)},
			{"data": "lab_analyzer", "at": Vector3(1.55, 0.08, 1.7)},
			{"data": "sample_case", "at": Vector3(3.65, 0.08, 1.7)},
		]
	for spec in specs:
		var pickup := LOOT_SCENE.instantiate() as LootPickup
		pickup.loot_id = "%s:%s" % [company.company_id, spec["data"]]
		pickup.definition = load("res://data/loot/%s.tres" % spec["data"]) as LootDefinition
		pickup.position = spec["at"]
		add_child(pickup)

func get_equipment() -> Array[DestructibleEquipment]:
	return _equipment.duplicate()

func _spawn_equipment() -> void:
	for spec_value in _equipment_specs():
		var spec: Dictionary = spec_value
		var equipment := EQUIPMENT_SCENE.instantiate() as DestructibleEquipment
		equipment.equipment_id = spec["id"]
		equipment.display_name = spec["name"]
		equipment.owner_company_id = company.company_id
		equipment.owner_ticker = company.ticker
		equipment.equipment_type = spec["type"]
		equipment.accent_color = company.accent_color
		equipment.position = spec["position"]
		add_child(equipment)
		_equipment.append(equipment)
		equipment.attacked.connect(_on_equipment_attacked)
		equipment.destroyed.connect(_on_equipment_destroyed)

func get_security_spawn_specs() -> Array[Dictionary]:
	if facility_type == FacilityType.ENERGY:
		return [
			{"position": Vector3(-2.3, 0.0, 2.35), "patrol_axis": Vector3(1.15, 0.0, 0.25)},
			{"position": Vector3(2.35, 0.0, 2.25), "patrol_axis": Vector3(-0.2, 0.0, 1.15)},
		]
	return [
		{"position": Vector3(-2.0, 0.0, 2.25), "patrol_axis": Vector3(1.25, 0.0, 0.15)},
		{"position": Vector3(3.85, 0.0, 2.2), "patrol_axis": Vector3(-0.25, 0.0, 1.1)},
	]

func _equipment_specs() -> Array[Dictionary]:
	if facility_type == FacilityType.ENERGY:
		return [
			{
				"id": "transformer_bank",
				"name": "TRANSFORMER BANK",
				"type": DestructibleEquipment.EquipmentType.TRANSFORMER,
				"position": Vector3(-1.85, 0.0, 0.25),
			},
			{
				"id": "switchgear_unit",
				"name": "GRID SWITCHGEAR",
				"type": DestructibleEquipment.EquipmentType.SWITCHGEAR,
				"position": Vector3(0.0, 0.0, 0.15),
			},
			{
				"id": "generator_set",
				"name": "GENERATOR SET",
				"type": DestructibleEquipment.EquipmentType.GENERATOR,
				"position": Vector3(1.95, 0.0, 0.25),
			},
		]
	return [
		{
			"id": "filtration_unit",
			"name": "FILTRATION UNIT",
			"type": DestructibleEquipment.EquipmentType.FILTRATION,
			"position": Vector3(-0.5, 0.0, 0.4),
		},
		{
			"id": "production_unit",
			"name": "FILLING / PRODUCTION",
			"type": DestructibleEquipment.EquipmentType.PRODUCTION,
			"position": Vector3(1.55, 0.0, 0.15),
		},
		{
			"id": "cold_storage_unit",
			"name": "COLD STORAGE UNIT",
			"type": DestructibleEquipment.EquipmentType.COLD_STORAGE,
			"position": Vector3(3.65, 0.0, 0.35),
		},
	]

func _on_equipment_destroyed(equipment_id: String, _equipment_node: DestructibleEquipment) -> void:
	destroyed_count += 1
	equipment_destroyed.emit(company.company_id, equipment_id, destroyed_count, _equipment.size())

func _on_equipment_attacked(equipment_id: String, _equipment_node: DestructibleEquipment, hit_position: Vector3) -> void:
	equipment_attacked.emit(company.company_id, equipment_id, hit_position)

func _build_medical_shell() -> void:
	var stone := _make_material(Color("b7ad9c"), 0.0, 0.82)
	var light_stone := _make_material(Color("d4cab9"), 0.0, 0.76)
	var dark_metal := _make_material(Color("3b4545"), 0.28, 0.52)
	var accent := _make_material(company.accent_color, 0.05, 0.68)
	var bay_marking := _make_material(company.accent_color.darkened(0.08), 0.0, 0.88)
	var pallet := _make_material(Color("896c4e"), 0.0, 0.88)

	_add_box("LogisticsCourt", Vector3(1.0, 0.035, 0.72), Vector3(7.2, 0.07, 3.15), light_stone)
	_add_box("LoadingDock", Vector3(1.0, 0.17, -0.82), Vector3(6.4, 0.28, 0.78), stone)
	_add_box("DockEdge", Vector3(1.0, 0.34, -0.42), Vector3(6.4, 0.1, 0.08), accent)
	for bay_x in [-0.5, 1.55, 3.65]:
		_add_box("EquipmentBaySide", Vector3(float(bay_x) - 0.88, 0.078, 0.32), Vector3(0.035, 0.016, 1.5), bay_marking)
		_add_box("EquipmentBaySide", Vector3(float(bay_x) + 0.88, 0.078, 0.32), Vector3(0.035, 0.016, 1.5), bay_marking)
		_add_box("EquipmentBayFront", Vector3(float(bay_x), 0.078, 1.06), Vector3(1.76, 0.016, 0.035), bay_marking)

	_add_solid("WestBarrier", Vector3(-2.55, 0.28, 0.82), Vector3(0.18, 0.56, 2.85), stone)
	_add_solid("EastBarrier", Vector3(4.55, 0.28, 0.82), Vector3(0.18, 0.56, 2.85), stone)
	for z_value in [-0.05, 0.75, 1.55]:
		_add_box("BarrierBand", Vector3(-2.64, 0.36, float(z_value)), Vector3(0.05, 0.13, 0.42), accent)
		_add_box("BarrierBand", Vector3(4.64, 0.36, float(z_value)), Vector3(0.05, 0.13, 0.42), accent)

	_add_box("FacadeSign", Vector3(0.0, 2.28, -1.14), Vector3(4.55, 0.78, 0.09), light_stone)
	_add_box("LogoVertical", Vector3(-1.82, 2.28, -1.085), Vector3(0.13, 0.45, 0.055), accent)
	_add_box("LogoHorizontal", Vector3(-1.82, 2.28, -1.08), Vector3(0.45, 0.13, 0.06), accent)
	_add_facility_label("VITASign", "VITA MEDICAL", Vector3(0.42, 2.27, -1.075), company.accent_color.darkened(0.25))

	for crate_spec in [
		{"position": Vector3(3.92, 0.26, -0.52), "size": Vector3(0.62, 0.52, 0.62)},
		{"position": Vector3(3.92, 0.72, -0.52), "size": Vector3(0.54, 0.38, 0.54)},
		{"position": Vector3(-2.0, 0.22, -0.58), "size": Vector3(0.78, 0.44, 0.55)},
	]:
		_add_box("SupplyCrate", crate_spec["position"], crate_spec["size"], pallet)
	_add_box("Pallet", Vector3(-2.0, 0.055, -0.58), Vector3(0.92, 0.11, 0.68), dark_metal)

func _build_energy_shell() -> void:
	var concrete := _make_material(Color("aaa292"), 0.0, 0.86)
	var pale := _make_material(Color("cbc0ab"), 0.0, 0.8)
	var steel := _make_material(Color("354247"), 0.34, 0.54)
	var insulated := _make_material(Color("273136"), 0.08, 0.78)
	var accent := _make_material(company.accent_color, 0.12, 0.64)
	var marking := _make_material(company.accent_color.darkened(0.16), 0.0, 0.9)

	# A compact municipal substation: readable from the camera without becoming neon-heavy.
	_add_box("SubstationPad", Vector3(0.0, 0.035, 0.45), Vector3(6.6, 0.07, 3.2), pale)
	_add_box("CableTrench", Vector3(0.0, 0.075, 1.13), Vector3(5.85, 0.025, 0.12), insulated)
	for bay_x in [-1.85, 0.0, 1.95]:
		_add_box("GridBay", Vector3(float(bay_x), 0.078, 0.95), Vector3(1.55, 0.02, 0.045), marking)
		_add_box("GridFeed", Vector3(float(bay_x), 0.079, 1.35), Vector3(0.045, 0.02, 0.75), marking)

	_add_solid("WestBollard", Vector3(-3.18, 0.34, 0.65), Vector3(0.2, 0.68, 2.7), concrete)
	_add_solid("EastBollard", Vector3(3.18, 0.34, 0.65), Vector3(0.2, 0.68, 2.7), concrete)
	for x_value in [-2.78, 2.78]:
		_add_box("Gantries", Vector3(float(x_value), 1.25, -0.92), Vector3(0.12, 2.35, 0.12), steel)
	_add_box("GantryBeam", Vector3(0.0, 2.38, -0.92), Vector3(5.7, 0.12, 0.12), steel)
	for x_value in [-1.85, 0.0, 1.95]:
		_add_cylinder("Insulator", Vector3(float(x_value), 2.03, -0.9), 0.09, 0.55, insulated)
		_add_cylinder("BusBar", Vector3(float(x_value), 2.35, -0.9), 0.045, 1.45, accent, Vector3(0, 0, 90))

	_add_box("ARCSignBacking", Vector3(0.0, 1.58, -1.08), Vector3(3.7, 0.67, 0.1), concrete)
	_add_box("ARCMark", Vector3(-1.48, 1.58, -1.018), Vector3(0.16, 0.42, 0.055), accent)
	_add_facility_label("ARCSign", "ARC ENERGY", Vector3(0.25, 1.57, -1.015), company.accent_color.darkened(0.25))

func _add_facility_label(node_name: String, text: String, position: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.position = position
	label.font_size = 72
	label.pixel_size = 0.0062
	label.modulate = color
	label.outline_modulate = Color(0.92, 0.89, 0.82, 0.5)
	label.outline_size = 2
	add_child(label)

func _add_solid(node_name: String, position: Vector3, size: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	body.add_child(_mesh_box("Mesh", Vector3.ZERO, size, material))
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body

func _add_box(node_name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var instance := _mesh_box(node_name, position, size, material)
	add_child(instance)
	return instance

func _mesh_box(node_name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	return instance

func _add_cylinder(node_name: String, position: Vector3, radius: float, height: float, material: Material, rotation_degrees_value := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	instance.rotation_degrees = rotation_degrees_value
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.92
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
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
