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
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("02040d")
	environment.background_energy_multiplier = 0.35
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("17244b")
	environment.ambient_light_energy = 0.72
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.22
	environment.glow_enabled = true
	environment.glow_intensity = 1.15
	environment.glow_bloom = 0.18
	environment.ssao_enabled = true
	environment.ssao_radius = 2.4
	environment.ssao_intensity = 2.0
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.012
	environment.volumetric_fog_length = 48.0
	environment.volumetric_fog_ambient_inject = 0.7
	world_environment.environment = environment

