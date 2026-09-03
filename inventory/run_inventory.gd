class_name RunInventory
extends Node

signal changed

@export_range(1, 3, 1) var capacity := 3

var _items: Array[Dictionary] = []
var _finished := false

func _ready() -> void:
	add_to_group("run_inventory")

func get_items() -> Array[Dictionary]:
	return _items.duplicate(true)

func get_used_slots() -> int:
	return _items.size()

func get_value() -> float:
	var value := 0.0
	for item in _items:
		value += float(item["value"])
	return snappedf(value, 0.01)

func contains(loot_id: String) -> bool:
	return _items.any(func(item: Dictionary) -> bool: return item["id"] == loot_id)

func can_collect(definition: LootDefinition, replace_index := -1) -> bool:
	if _finished or definition == null or not definition.is_valid():
		return false
	if replace_index >= 0:
		return replace_index < _items.size()
	return _items.size() < capacity

func collect(loot_id: String, definition: LootDefinition, replace_index := -1) -> Dictionary:
	# A failed exchange leaves both entries untouched; world changes follow acceptance.
	if loot_id.is_empty() or contains(loot_id) or not can_collect(definition, replace_index):
		return {"accepted": false, "dropped": {}}
	var dropped: Dictionary = {}
	if replace_index >= 0:
		dropped = _items[replace_index]
		_items[replace_index] = definition.manifest_entry(loot_id)
	else:
		_items.append(definition.manifest_entry(loot_id))
	changed.emit()
	return {"accepted": true, "dropped": dropped.duplicate(true)}

func finish_run() -> void:
	_finished = true
	_items.clear()
	changed.emit()
