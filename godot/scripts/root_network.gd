extends RefCounted

const VERSION: int = 1
const SOLUTION: Array[int] = [1, 2, 1]

var ports: Array[int] = [0, 0, 0]
var complete: bool = false


func turn(index: int) -> bool:
	if complete or index < 0 or index >= ports.size():
		return false
	ports[index] = (ports[index] + 1) % 3
	return true


func powered_count() -> int:
	return _powered_for(ports)


func pulse() -> bool:
	if complete or powered_count() != SOLUTION.size():
		return false
	complete = true
	return true


func reset() -> void:
	ports = [0, 0, 0]
	complete = false


func snapshot() -> Dictionary:
	return {
		"version": VERSION,
		"ports": ports.duplicate(),
		"powered": powered_count(),
		"complete": complete,
	}


static func normalized(data: Variant) -> Dictionary:
	if not data is Dictionary:
		return {}
	var raw_version: Variant = data.get("version")
	if not _strict_integer(raw_version) or float(raw_version) != float(VERSION):
		return {}
	var raw_ports: Variant = data.get("ports")
	if not raw_ports is Array or raw_ports.size() != SOLUTION.size():
		return {}
	var clean_ports: Array[int] = []
	for value in raw_ports:
		if not _strict_integer(value) or float(value) < 0.0 or float(value) > 2.0:
			return {}
		clean_ports.append(int(value))
	var computed_powered := _powered_for(clean_ports)
	var raw_powered: Variant = data.get("powered")
	if not _strict_integer(raw_powered) or float(raw_powered) != float(computed_powered):
		return {}
	var raw_complete: Variant = data.get("complete")
	if not raw_complete is bool:
		return {}
	if bool(raw_complete) and computed_powered != SOLUTION.size():
		return {}
	return {
		"version": VERSION,
		"ports": clean_ports.duplicate(),
		"powered": computed_powered,
		"complete": bool(raw_complete),
	}


func restore(data: Variant) -> bool:
	var incoming := normalized(data)
	if incoming.is_empty():
		return false
	var restored_ports: Array[int] = []
	for value in incoming.ports:
		restored_ports.append(int(value))
	ports = restored_ports
	complete = incoming.complete
	return true


static func _powered_for(candidate: Array[int]) -> int:
	var powered := 0
	for index in SOLUTION.size():
		if candidate[index] != SOLUTION[index]:
			break
		powered += 1
	return powered


static func _strict_integer(value: Variant) -> bool:
	if value is bool or (not value is int and not value is float):
		return false
	var numeric := float(value)
	return is_finite(numeric) and numeric == floorf(numeric)
