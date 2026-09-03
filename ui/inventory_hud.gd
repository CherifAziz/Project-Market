class_name InventoryHUD
extends CanvasLayer

var _inventory: RunInventory
var _interactor: LootInteractor
var _player: PlayerController
var _market_open := false
var _cargo: HBoxContainer
var _context: Label
var _slots: Array[LootSlot] = []
var _flight: LootSlot
var _flight_tween: Tween
const HOME := Vector2(34, 65)

func _ready() -> void:
	_cargo = HBoxContainer.new()
	_cargo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cargo.add_theme_constant_override("separation", 8)
	add_child(_cargo)
	for index in range(3):
		var slot := LootSlot.new()
		_cargo.add_child(slot)
		_slots.append(slot)
	_context = Label.new()
	_context.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_context.add_theme_font_size_override("font_size", 21)
	_context.add_theme_color_override("font_color", Color("f2e8cd"))
	_context.add_theme_color_override("font_shadow_color", Color("18211b"))
	_context.add_theme_constant_override("shadow_offset_x", 2)
	_context.add_theme_constant_override("shadow_offset_y", 2)
	_context.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_context)
	_flight = LootSlot.new()
	_flight.visible = false
	add_child(_flight)

func bind(inventory: RunInventory, interactor: LootInteractor, player: PlayerController) -> void:
	_inventory = inventory
	_interactor = interactor
	_player = player
	_inventory.changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	var items := _inventory.get_items()
	for index in range(3):
		_slots[index].set_item(items[index] if index < items.size() else {})

func set_market_open(open: bool) -> void:
	_market_open = open

func animate_pickup(pickup: LootPickup, slot: int) -> void:
	_slots[slot].pulse()
	if _flight_tween != null and _flight_tween.is_valid():
		_flight_tween.kill()
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	_flight.set_item(pickup.definition.manifest_entry(pickup.loot_id))
	_flight.position = camera.unproject_position(pickup.get_context_position()) - Vector2(38, 41)
	_flight.modulate = Color.WHITE
	_flight.scale = Vector2.ONE * 0.75
	_flight.visible = true
	_flight_tween = create_tween().set_parallel(true)
	var destination := _slots[slot].global_position if _slots[slot].key_number > 0 else HOME + Vector2(slot * 84, 0)
	_flight_tween.tween_property(_flight, "position", destination, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_flight_tween.tween_property(_flight, "modulate:a", 0.0, 0.24)
	_flight_tween.chain().tween_callback(_flight.hide)

func _process(_delta: float) -> void:
	if _interactor == null:
		return
	var pickup := _interactor.focused_pickup
	var focused := pickup != null and pickup.available and not _market_open and _player.is_alive()
	var swapping := focused and _interactor.is_full()
	_cargo.visible = not _market_open
	_context.visible = focused
	_cargo.position = HOME
	for index in range(3):
		_slots[index].key_number = index + 1 if swapping else 0
		_slots[index].queue_redraw()
	if not focused:
		return
	var camera := get_viewport().get_camera_3d()
	var viewport := get_viewport().get_visible_rect().size
	var screen := camera.unproject_position(pickup.get_context_position())
	var width := 244.0 if swapping else 130.0
	var at := Vector2(clampf(screen.x - width * 0.5, 20, viewport.x - width - 20), clampf(screen.y - (150 if swapping else 38), 160, viewport.y - 260))
	_context.text = MoneyFormat.short_cash(pickup.definition.value) + ("  ↓" if swapping else "   [E]")
	_context.position = at
	_context.size = Vector2(width, 30)
	if swapping:
		_cargo.position = at + Vector2(0, 48)
