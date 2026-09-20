extends RefCounted
const Activities = preload("res://scripts/expedition_activities.gd")
const MAX_BYTES := 65536
const KINDS := ["veyra", "aeral", "root_choir"]

static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

static func valid(data: Variant) -> bool:
	if not data is Dictionary: return false
	if not _number(data.get("version"),1,2): return false
	if float(data.version) != floorf(float(data.version)): return false
	var version := int(data.version)
	if version not in [1,2] or data.get("phase") != "exploring": return false
	var point: Variant = data.get("position")
	if not point is Dictionary: return false
	if not _number(point.get("x"),-94,94) or not _number(point.get("z"),-670,180) or not _number(point.get("y"),-128,256): return false
	if not _number(data.get("heading"),-100000,100000): return false
	if not _number(data.get("elapsed"),0,1e8) or not _number(data.get("distance"),0,1e9): return false
	if not _number(data.get("transmitCount"),0,100000): return false
	var observations: Variant = data.get("observedEcology")
	if not observations is Dictionary: return false
	for key in observations:
		if key not in KINDS or not observations[key] is bool: return false
	if data.get("view","first_person") not in ["first_person","third_person"]: return false
	if version == 2 and Activities.normalized(data.get("activities")).is_empty(): return false
	return true

static func migrate(data: Dictionary) -> Dictionary:
	if not valid(data): return {}
	var result:=data.duplicate(true)
	result["activities"]=Activities.new().snapshot() if int(data.version)==1 else Activities.normalized(data.activities)
	result["version"]=2
	return result

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return {}
	if file.get_length() > MAX_BYTES: file.close(); return {}
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK or not valid(parser.data): return {}
	return migrate(parser.data)

static func read(path: String) -> Dictionary:
	var current := _read(path)
	return current if not current.is_empty() else _read(path+".bak")

static func write(path: String, data: Dictionary) -> bool:
	if not valid(data): return false
	var tmp := path+".tmp"
	var file := FileAccess.open(tmp,FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data)); file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or _read(tmp).is_empty(): return false
	# Preserve a valid previous generation; corrupt primary must never replace good backup.
	if not _read(path).is_empty():
		if DirAccess.copy_absolute(path,path+".bak") != OK: return false
	return DirAccess.rename_absolute(tmp,path) == OK

static func clear(path: String) -> void:
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
