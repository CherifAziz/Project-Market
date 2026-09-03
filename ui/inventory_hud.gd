class_name InventoryHUD
extends CanvasLayer

@onready var summary_label: Label = %CargoSummary
@onready var value_label: Label = %CargoValue
@onready var details: PanelContainer = %InventoryDetails
@onready var rows: VBoxContainer = %CargoRows
@onready var load_label: Label = %LoadEffect
@onready var notice: Label = %CargoNotice
@onready var context: PanelContainer = %LootContext
@onready var loot_name: Label = %LootName
@onready var loot_data: Label = %LootData
@onready var loot_action: Label = %LootAction

var _inventory: RunInventory
var _interactor: LootInteractor
var _player: PlayerController
var _market_open := false
var _notice_left := 0.0

func bind(inventory: RunInventory, interactor: LootInteractor, player: PlayerController) -> void:
	_inventory = inventory
	_interactor = interactor
	_player = player
	_inventory.changed.connect(_refresh)
	_refresh()

func toggle_details() -> void:
	if not _market_open:
		details.visible = not details.visible

func set_market_open(open: bool) -> void:
	_market_open = open
	if open:
		details.visible = false
		context.visible = false

func show_notice(message: String) -> void:
	notice.text = message
	_notice_left = 2.2

func _refresh() -> void:
	summary_label.text = "CARGO  %d / %d SLOTS   ·   %.1f kg" % [_inventory.get_used_slots(), _inventory.capacity, _inventory.get_weight()]
	value_label.text = "%s AT RISK   //   TAB CONTENTS" % MoneyFormat.cash(_inventory.get_value())
	load_label.text = "MOVE −%d%%  //  DASH UNCHANGED" % int(round((1.0 - _player.get_carry_speed_multiplier()) * 100.0))
	for child in rows.get_children():
		child.free()
	var items := _inventory.get_items()
	if items.is_empty():
		_add_row("EMPTY\nFind tagged assets inside VITA / ARC.", false)
	for index in range(items.size()):
		var item: Dictionary = items[index]
		var selected := index == _inventory.selected_index
		_add_row("%s [%d] %s\n%s   ·   %.1f kg   ·   %d SLOT%s\n%s" % ["›" if selected else " ", index + 1, item["name"], MoneyFormat.cash(item["value"]), item["weight_kg"], item["slots"], "S" if int(item["slots"]) > 1 else "", item["category"]], selected)

func _add_row(text: String, selected: bool) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("ddd2b9") if selected else Color("939d91"))
	rows.add_child(label)

func _process(delta: float) -> void:
	_notice_left = maxf(_notice_left - delta, 0.0)
	notice.visible = _notice_left > 0.0 and not _market_open
	if _interactor == null:
		return
	var pickup := _interactor.focused_pickup
	context.visible = pickup != null and pickup.available and not _market_open and _player.is_alive()
	if not context.visible:
		return
	var definition := pickup.definition
	loot_name.text = definition.display_name
	loot_data.text = "%s   ·   %.1f kg   ·   %d SLOT%s\n%s" % [MoneyFormat.cash(definition.value), definition.weight_kg, definition.slots, "S" if definition.slots > 1 else "", definition.category]
	if _inventory.can_collect(definition):
		loot_action.text = "E  TAKE  //  EXTRACT TO SELL"
	elif _inventory.can_collect(definition, _inventory.selected_index):
		loot_action.text = "E  REPLACE [%d] %s\n1–3 SELECT  ·  TAB CONTENTS" % [_inventory.selected_index + 1, _inventory.get_selected_item()["name"]]
	else:
		loot_action.text = "BAG FULL  //  NEED %d FREE SLOTS\nTAB CONTENTS  ·  1–3 SELECT  ·  G DROP" % definition.slots
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var screen := camera.unproject_position(pickup.get_context_position())
		var viewport := get_viewport().get_visible_rect().size
		context.position = Vector2(clampf(screen.x - context.size.x * 0.5, 12, viewport.x - context.size.x - 12), clampf(screen.y - context.size.y - 18, 100, viewport.y - context.size.y - 180))
