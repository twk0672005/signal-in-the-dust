extends RefCounted
const Activities = preload("res://scripts/expedition_activities.gd")
const WEB_PREFIX := "signal-in-the-dust:expedition:v2:"
const CLEARED := "__EXPEDITION_CLEARED__"
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
	if OS.has_feature("web"):
		var raw: Variant=_web_get(path)
		if raw==CLEARED: return {}
		var current:=_parse_web(raw)
		if not current.is_empty(): return current
		var backup: Variant=_web_get(path+".bak")
		current=_parse_web(backup)
		if not current.is_empty(): return current
		# Only an untouched browser slot may migrate the older asynchronous userfs save.
		if raw==null and backup==null:
			current=_read(path)
			if current.is_empty(): current=_read(path+".bak")
			if not current.is_empty(): _write_web(path,current)
			return current
		return {}
	var current := _read(path)
	return current if not current.is_empty() else _read(path+".bak")

static func write(path: String, data: Dictionary) -> bool:
	if not valid(data): return false
	if OS.has_feature("web"): return _write_web(path,data)
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

static func exists(path: String) -> bool:
	if OS.has_feature("web"):
		var raw: Variant=_web_get(path)
		if raw==CLEARED: return false
		if raw!=null or _web_get(path+".bak")!=null: return true
	return FileAccess.file_exists(path) or FileAccess.file_exists(path+".bak")

static func clear(path: String) -> bool:
	if OS.has_feature("web"):
		# A synchronous tombstone prevents an old userfs copy reappearing after immediate reload.
		if not _web_set(path,CLEARED): return false
		_web_remove(path+".bak")
		_web_remove(path+".tmp")
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path+suffix):
			var error:=DirAccess.remove_absolute(path+suffix)
			if error!=OK and not OS.has_feature("web"): return false
	return true

# Small expedition records use synchronous, origin-scoped Web Storage. FileAccess
# userfs is asynchronous on Web and can lag a pause immediately followed by reload.
static func _web_get(path: String) -> Variant:
	return JavaScriptBridge.eval("(()=>{try{return localStorage.getItem("+JSON.stringify(WEB_PREFIX+path)+")}catch(e){return null}})()",true)

static func _web_set(path: String, value: String) -> bool:
	return JavaScriptBridge.eval("(()=>{try{localStorage.setItem("+JSON.stringify(WEB_PREFIX+path)+","+JSON.stringify(value)+");return 1}catch(e){return 0}})()",true)==1

static func _web_remove(path: String) -> void:
	JavaScriptBridge.eval("(()=>{try{localStorage.removeItem("+JSON.stringify(WEB_PREFIX+path)+")}catch(e){}})()",true)

static func _parse_web(raw: Variant) -> Dictionary:
	if not raw is String or raw.to_utf8_buffer().size()>MAX_BYTES: return {}
	var parser:=JSON.new()
	if parser.parse(raw)!=OK or not valid(parser.data): return {}
	return migrate(parser.data)

static func _write_web(path: String, data: Dictionary) -> bool:
	if not valid(data): return false
	var serialized:=JSON.stringify(data)
	if serialized.to_utf8_buffer().size()>MAX_BYTES: return false
	if not _web_set(path+".tmp",serialized) or _parse_web(_web_get(path+".tmp")).is_empty(): return false
	var previous: Variant=_web_get(path)
	if not _parse_web(previous).is_empty():
		if not _web_set(path+".bak",previous): return false
	# setItem replaces one key atomically; a failed replacement preserves its prior value.
	if not _web_set(path,serialized): return false
	var written: bool=_web_get(path)==serialized
	_web_remove(path+".tmp")
	return written
