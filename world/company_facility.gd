class_name CompanyFacility
extends Node3D

signal equipment_destroyed(equipment_id: String, destroyed_count: int, total_count: int)

const EQUIPMENT_SCENE := preload("res://world/destructible_equipment.tscn")

@export var company: CompanyDefinition

var destroyed_count := 0
var _equipment: Array[DestructibleEquipment] = []

func _ready() -> void:
	add_to_group("company_facility")
	_build_facility_shell()
	_spawn_equipment()

func get_equipment() -> Array[DestructibleEquipment]:
	return _equipment.duplicate()

func _spawn_equipment() -> void:
	var accent := company.accent_color if company else Color("60806d")
	var company_id := company.company_id if company else "vita_medical"
	var specs := [
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

	for spec_value in specs:
		var spec: Dictionary = spec_value
		var equipment := EQUIPMENT_SCENE.instantiate() as DestructibleEquipment
		equipment.equipment_id = spec["id"]
		equipment.display_name = spec["name"]
		equipment.owner_company_id = company_id
		equipment.equipment_type = spec["type"]
		equipment.accent_color = accent
		equipment.position = spec["position"]
		add_child(equipment)
		_equipment.append(equipment)
		equipment.destroyed.connect(_on_equipment_destroyed)

func _on_equipment_destroyed(equipment_id: String, _equipment_node: DestructibleEquipment) -> void:
	destroyed_count += 1
	equipment_destroyed.emit(equipment_id, destroyed_count, _equipment.size())

func _build_facility_shell() -> void:
	var stone := _make_material(Color("b7ad9c"), 0.0, 0.82)
	var light_stone := _make_material(Color("d4cab9"), 0.0, 0.76)
	var dark_metal := _make_material(Color("3b4545"), 0.28, 0.52)
	var accent_color := company.accent_color if company else Color("60806d")
	var accent := _make_material(accent_color, 0.05, 0.68)
	var bay_marking := _make_material(accent_color.darkened(0.08), 0.0, 0.88)
	var pallet := _make_material(Color("896c4e"), 0.0, 0.88)

	# A compact loading court sits in front of an existing north-side building.
	_add_box("LogisticsCourt", Vector3(1.0, 0.035, 0.72), Vector3(7.2, 0.07, 3.15), light_stone)
	_add_box("LoadingDock", Vector3(1.0, 0.17, -0.82), Vector3(6.4, 0.28, 0.78), stone)
	_add_box("DockEdge", Vector3(1.0, 0.34, -0.42), Vector3(6.4, 0.1, 0.08), accent)
	for bay_x in [-0.5, 1.55, 3.65]:
		_add_box("EquipmentBaySide", Vector3(float(bay_x) - 0.88, 0.078, 0.32), Vector3(0.035, 0.016, 1.5), bay_marking)
		_add_box("EquipmentBaySide", Vector3(float(bay_x) + 0.88, 0.078, 0.32), Vector3(0.035, 0.016, 1.5), bay_marking)
		_add_box("EquipmentBayFront", Vector3(float(bay_x), 0.078, 1.06), Vector3(1.76, 0.016, 0.035), bay_marking)

	# The low walls frame the facility without hiding its three critical machines.
	_add_solid("WestBarrier", Vector3(-2.55, 0.28, 0.82), Vector3(0.18, 0.56, 2.85), stone)
	_add_solid("EastBarrier", Vector3(4.55, 0.28, 0.82), Vector3(0.18, 0.56, 2.85), stone)
	for z_value in [-0.05, 0.75, 1.55]:
		_add_box("BarrierBand", Vector3(-2.64, 0.36, float(z_value)), Vector3(0.05, 0.13, 0.42), accent)
		_add_box("BarrierBand", Vector3(4.64, 0.36, float(z_value)), Vector3(0.05, 0.13, 0.42), accent)

	# Matte facade branding: visible, restrained, and deliberately non-emissive.
	_add_box("FacadeSign", Vector3(0.0, 2.28, -1.14), Vector3(4.55, 0.78, 0.09), light_stone)
	_add_box("LogoVertical", Vector3(-1.82, 2.28, -1.085), Vector3(0.13, 0.45, 0.055), accent)
	_add_box("LogoHorizontal", Vector3(-1.82, 2.28, -1.08), Vector3(0.45, 0.13, 0.06), accent)
	var sign_label := Label3D.new()
	sign_label.name = "VITASign"
	sign_label.text = "VITA MEDICAL"
	sign_label.position = Vector3(0.42, 2.27, -1.075)
	sign_label.font_size = 72
	sign_label.pixel_size = 0.0062
	sign_label.modulate = accent_color.darkened(0.25)
	sign_label.outline_modulate = Color(0.92, 0.89, 0.82, 0.5)
	sign_label.outline_size = 2
	add_child(sign_label)

	# A few logistics props make the yard read as a working miniature facility.
	for crate_spec in [
		{"position": Vector3(3.92, 0.26, -0.52), "size": Vector3(0.62, 0.52, 0.62)},
		{"position": Vector3(3.92, 0.72, -0.52), "size": Vector3(0.54, 0.38, 0.54)},
		{"position": Vector3(-2.0, 0.22, -0.58), "size": Vector3(0.78, 0.44, 0.55)},
	]:
		_add_box("SupplyCrate", crate_spec["position"], crate_spec["size"], pallet)
	_add_box("Pallet", Vector3(-2.0, 0.055, -0.58), Vector3(0.92, 0.11, 0.68), dark_metal)

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

func _make_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
