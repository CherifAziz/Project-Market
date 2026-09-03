class_name MoneyFormat
extends RefCounted

static func short_cash(value: float) -> String:
	return "$%.1fk" % (value / 1000.0) if absf(value) >= 1000.0 else cash(value)

static func cash(value: float) -> String:
	var rounded := int(round(value))
	return ("-$" if rounded < 0 else "$") + _thousands(absi(rounded))

static func pnl(value: float) -> String:
	return ("+" if value >= 0.5 else "") + cash(value)

static func _thousands(value: int) -> String:
	var digits := str(value)
	var result := ""
	while digits.length() > 3:
		result = "," + digits.right(3) + result
		digits = digits.left(digits.length() - 3)
	return digits + result
