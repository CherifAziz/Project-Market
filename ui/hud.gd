extends CanvasLayer

@onready var target_label: Label = %TargetLabel
@onready var sector_label: Label = %SectorLabel
@onready var dash_bar: ProgressBar = %DashBar
@onready var dash_label: Label = %DashLabel

var _player: PlayerController
var _initial_target_count := 0

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as PlayerController
	_initial_target_count = get_tree().get_nodes_in_group("targets").size()

func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as PlayerController
	if _player:
		var dash_ratio := _player.get_dash_ready_ratio()
		dash_bar.value = dash_ratio * 100.0
		dash_label.text = "DASH  READY" if dash_ratio >= 0.999 else "DASH  %02d" % int(dash_ratio * 100.0)

	var remaining := get_tree().get_nodes_in_group("targets").size()
	target_label.text = "%02d" % remaining
	if _initial_target_count > 0 and remaining == 0:
		sector_label.text = "SECTOR LIQUIDATED  //  R TO RESET"
		sector_label.modulate = Color("75fbff")
	else:
		sector_label.text = "HOSTILE ASSETS"

