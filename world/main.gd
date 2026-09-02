extends Node3D

@onready var world_environment: WorldEnvironment = $WorldEnvironment

func _ready() -> void:
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_setup_environment()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN else Input.MOUSE_MODE_HIDDEN

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _setup_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("6f8fa1")
	sky_material.sky_horizon_color = Color("efcba5")
	sky_material.ground_bottom_color = Color("6d665c")
	sky_material.ground_horizon_color = Color("d9b993")
	sky_material.sun_angle_max = 18.0
	sky_material.sun_curve = 0.09
	var sky := Sky.new()
	sky.sky_material = sky_material

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.background_energy_multiplier = 0.72
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = Color("c4d0d0")
	environment.ambient_light_energy = 0.68
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.95
	environment.glow_enabled = true
	environment.glow_intensity = 0.28
	environment.glow_bloom = 0.015
	environment.ssao_enabled = true
	environment.ssao_radius = 1.8
	environment.ssao_intensity = 1.15
	environment.volumetric_fog_enabled = false
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.0
	environment.adjustment_contrast = 1.03
	environment.adjustment_saturation = 0.9
	world_environment.environment = environment
