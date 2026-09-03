class_name ShortPosition
extends RefCounted

var entry_price: float
var shares: int
var current_price: float

func _init(opening_price: float, share_count: int) -> void:
	entry_price = opening_price
	current_price = opening_price
	shares = maxi(share_count, 0)

func update_current_price(price: float) -> void:
	current_price = price

func unrealized_pnl() -> float:
	return (entry_price - current_price) * float(shares)
