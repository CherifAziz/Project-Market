class_name WeaponData
extends Resource

@export_group("Identity")
@export var display_name: String = "Automatic weapon"

@export_group("Ballistics")
@export_range(1.0, 1000.0, 1.0) var damage: float = 24.0
@export_range(60.0, 1500.0, 1.0) var rounds_per_minute: float = 720.0
@export_range(1.0, 100.0, 0.5) var range: float = 45.0
@export_range(0.0, 8.0, 0.01) var spread_degrees: float = 0.35

@export_group("Feedback")
@export var tracer_color: Color = Color("65f6ff")
@export var muzzle_color: Color = Color("baffff")
@export_range(0.005, 0.2, 0.005) var tracer_width: float = 0.035
@export_range(0.01, 0.3, 0.005) var tracer_duration: float = 0.075
@export_range(0.0, 1.0, 0.01) var camera_shake: float = 0.12

func shot_interval() -> float:
	return 60.0 / maxf(rounds_per_minute, 1.0)

