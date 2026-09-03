class_name RunInventory
extends Node

signal changed

@export_range(1, 3, 1) var capacity := 3

var selected_index := 0
var _items: Array[Dictionary] = []
var _finished := false

func _ready() -> void:
	add_to_group("run_inventory")

func get_items() -> Array[Dictionary]:
	return _items.duplicate(true)

func get_selected_item() -> Dictionary:
	return _items[selected_index].duplicate(true) if selected_index < _items.size() else {}

func get_used_slots() -> int:
	var used := 0
	for item in _items:
		used += int(item["slots"])
	return used

func get_weight() -> float:
	var weight := 0.0
	for item in _items:
		weight += float(item["weight_kg"])
	return weight

func get_value() -> float:
	var value := 0.0
	for item in _items:
		value += float(item["value"])
	return snappedf(value, 0.01)

func select_item(index: int) -> void:
	if _finished or index < 0 or index >= _items.size():
		return
	selected_index = index
	changed.emit()

func contains(loot_id: String) -> bool:
	return _items.any(func(item: Dictionary) -> bool: return item["id"] == loot_id)

func can_collect(definition: LootDefinition, replace_index := -1) -> bool:
	if _finished or definition == null or not definition.is_valid():
		return false
	var freed_slots := 0
	if replace_index >= 0:
		if replace_index >= _items.size():
			return false
		freed_slots = int(_items[replace_index]["slots"])
	return get_used_slots() - freed_slots + definition.slots <= capacity

func collect(loot_id: String, definition: LootDefinition, replace_index := -1) -> Dictionary:
	# A failed exchange leaves both entries untouched; world changes follow acceptance.
	if loot_id.is_empty() or contains(loot_id) or not can_collect(definition, replace_index):
		return {"accepted": false, "dropped": {}}
	var dropped: Dictionary = {}
	if replace_index >= 0:
		dropped = _items[replace_index]
		_items.remove_at(replace_index)
	_items.append(definition.manifest_entry(loot_id))
	selected_index = _items.size() - 1
	changed.emit()
	return {"accepted": true, "dropped": dropped.duplicate(true)}

func drop_selected() -> Dictionary:
	if _finished or _items.is_empty():
		return {}
	var dropped := _items[selected_index]
	_items.remove_at(selected_index)
	selected_index = mini(selected_index, maxi(_items.size() - 1, 0))
	changed.emit()
	return dropped.duplicate(true)

func finish_run() -> void:
	_finished = true
	_items.clear()
	selected_index = 0
	changed.emit()
