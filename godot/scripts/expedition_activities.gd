extends RefCounted
## Pure survey rules. Positions and observed state are supplied by the game.
const REGIONS = ["aurora_shelf","ember_rift","veil_marsh","pale_decay"]
const OPTIONAL = ["aurora_echo","ember_vent","marsh_crossing","spore_pulse"]
const SITES = {
	"aurora_shelf":{"region":"aurora_shelf","z":80.0,"offset":10.0,"kind":"","optional":false},
	"ember_rift":{"region":"ember_rift","z":-108.0,"offset":12.0,"kind":"veyra","optional":false},
	"veil_marsh":{"region":"veil_marsh","z":-310.0,"offset":-11.0,"kind":"aeral","optional":false},
	"pale_decay":{"region":"pale_decay","z":-492.0,"offset":12.0,"kind":"root_choir","optional":false},
	"aurora_echo":{"region":"aurora_shelf","z":55.0,"offset":-62.0,"kind":"","optional":true},
	"ember_vent":{"region":"ember_rift","z":-135.0,"offset":54.0,"kind":"veyra","optional":true},
	"marsh_crossing":{"region":"veil_marsh","z":-285.0,"offset":-58.0,"kind":"aeral","optional":true},
	"spore_pulse":{"region":"pale_decay","z":-540.0,"offset":62.0,"kind":"root_choir","optional":true}
}
var completed: Dictionary = {}
var optional: Dictionary = {}
var stillness := 0.0
var current_region := "aurora_shelf"
func _init() -> void:
	reset()
static func point(id: String) -> Vector2:
	if not SITES.has(id): return Vector2.INF
	var z: float = SITES[id].z
	return Vector2(18.0*sin((150.0-z)*0.012)+4.0*sin((150.0-z)*0.033)+float(SITES[id].offset),z)
static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=low and float(value)<=high
static func _flags(value: Variant, keys: Array) -> bool:
	if not value is Dictionary or value.size()!=keys.size(): return false
	for key in keys:
		if not value.has(key) or not value[key] is bool: return false
	return true
static func normalized(data: Variant) -> Dictionary:
	if not data is Dictionary or not _number(data.get("version"),1,3): return {}
	var version: float = float(data.version)
	if version != floorf(version): return {}
	var done: Variant = data.get("completed_regions") if version==3 else data.get("completed")
	var extras: Variant = data.get("optional_observations") if version==3 else data.get("optional",{"aurora_echo":false,"ember_vent":false,"marsh_crossing":false,"spore_pulse":false})
	if not _flags(done,REGIONS) or not _flags(extras,OPTIONAL): return {}
	var quiet: Variant = data.get("quiet_seconds") if version==3 else data.get("stillness",0.0)
	if not _number(quiet,0,1e9): return {}
	var region: Variant = data.get("current_region","aurora_shelf")
	if not region is String or region not in REGIONS: return {}
	return {"version":3,"completed_regions":done.duplicate(true),"optional_observations":extras.duplicate(true),"current_region":region,"quiet_seconds":minf(float(quiet),3.0) if version==3 else 0.0}
func done(id: String) -> bool:
	return bool(completed.get(id,optional.get(id,false)))
func ready(id: String, observed: Dictionary) -> bool:
	if not SITES.has(id): return false
	var kind: String = SITES[id].kind
	return kind.is_empty() or observed.get(kind,false)==true
func near(id: String, position: Vector3) -> bool:
	return SITES.has(id) and Vector2(position.x,position.z).distance_to(point(id)) <= 7.0
func tick(region: String, speed: float, observed: Dictionary, delta: float, position: Vector3 = Vector3.INF) -> Array[String]:
	var events: Array[String] = []
	if region not in REGIONS or not is_finite(speed) or not is_finite(delta) or delta<0: return events
	current_region=region
	if region=="aurora_shelf" and absf(speed)<1.5 and near("aurora_shelf",position):
		stillness=minf(3.0,stillness+delta)
	else: stillness=0.0
	if stillness>=3.0 and not completed.aurora_shelf:
		completed.aurora_shelf=true
		events.append("aurora_shelf")
	return events
func can_record(id: String, region: String, position: Vector3, speed: float, observed: Dictionary) -> bool:
	return id!="aurora_shelf" and SITES.has(id) and region==SITES[id].region and not done(id) and is_finite(speed) and absf(speed)<1.5 and near(id,position) and ready(id,observed)
func record(id: String, region: String, position: Vector3, speed: float, observed: Dictionary) -> bool:
	if not can_record(id,region,position,speed,observed): return false
	if SITES[id].optional: optional[id]=true
	else: completed[id]=true
	return true
func target(region: String) -> String:
	if region not in REGIONS: return ""
	if not completed[region]: return region
	var id: String=OPTIONAL[REGIONS.find(region)]
	return id if not optional[id] else ""
func count() -> int:
	var result:=0
	for value in completed.values(): result+=int(value)
	return result
func optional_count() -> int:
	var result:=0
	for value in optional.values(): result+=int(value)
	return result
func snapshot() -> Dictionary:
	return {"version":3,"completed_regions":completed.duplicate(true),"optional_observations":optional.duplicate(true),"current_region":current_region,"quiet_seconds":stillness}
func restore(data: Variant) -> bool:
	var incoming:=normalized(data)
	if incoming.is_empty(): return false
	completed=incoming.completed_regions
	optional=incoming.optional_observations
	current_region=incoming.current_region
	stillness=incoming.quiet_seconds
	return true
func reset() -> void:
	for region in REGIONS: completed[region]=false
	for id in OPTIONAL: optional[id]=false
	current_region="aurora_shelf"
	stillness=0.0
