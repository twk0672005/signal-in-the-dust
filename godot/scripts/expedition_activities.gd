extends RefCounted
const StudyRules = preload("res://scripts/wetland_study.gd")
const ThermalRules = preload("res://scripts/thermal_route.gd")
const RootRules = preload("res://scripts/root_network.gd")
const PassageRules = preload("res://scripts/quiet_passage.gd")
const EscortRules = preload("res://scripts/quiet_escort.gd")
## Pure survey rules. Positions and observed state are supplied by the game.
const REGIONS: Array[String] = ["aurora_shelf","ember_rift","veil_marsh","pale_decay"]
const OPTIONAL: Array[String] = ["aurora_echo","ember_vent","marsh_crossing","spore_pulse"]
const FIELD: Array[String] = ["aurora_lode","aurora_ridge","ember_lake","ember_cairn","marsh_reed","marsh_pool","pale_bone","pale_sink"]
const SITES := {
 "aurora_shelf":{"region":"aurora_shelf","z":80.0,"offset":10.0,"kind":"","tier":"required"},
 "ember_rift":{"region":"ember_rift","z":-108.0,"offset":12.0,"kind":"veyra","tier":"required"},
 "veil_marsh":{"region":"veil_marsh","z":-310.0,"offset":-11.0,"kind":"aeral","tier":"required"},
 "pale_decay":{"region":"pale_decay","z":-492.0,"offset":12.0,"kind":"root_choir","tier":"required"},
 "aurora_echo":{"region":"aurora_shelf","z":55.0,"offset":-62.0,"kind":"","tier":"optional"},
 "ember_vent":{"region":"ember_rift","z":-135.0,"offset":54.0,"kind":"veyra","tier":"optional"},
 "marsh_crossing":{"region":"veil_marsh","z":-285.0,"offset":-58.0,"kind":"aeral","tier":"optional"},
 "spore_pulse":{"region":"pale_decay","z":-540.0,"offset":62.0,"kind":"root_choir","tier":"optional"},
 "aurora_lode":{"region":"aurora_shelf","z":105.0,"offset":-18.0,"kind":"","tier":"field"},
 "aurora_ridge":{"region":"aurora_shelf","z":25.0,"offset":10.0,"kind":"","tier":"field"},
 "ember_lake":{"region":"ember_rift","z":-58.0,"offset":-10.0,"kind":"","tier":"field"},
 "ember_cairn":{"region":"ember_rift","z":-152.0,"offset":10.0,"kind":"","tier":"field"},
 "marsh_reed":{"region":"veil_marsh","z":-228.0,"offset":10.0,"kind":"","tier":"field"},
 "marsh_pool":{"region":"veil_marsh","z":-342.0,"offset":-10.0,"kind":"","tier":"field"},
 "pale_bone":{"region":"pale_decay","z":-430.0,"offset":-10.0,"kind":"","tier":"field"},
 "pale_sink":{"region":"pale_decay","z":-470.0,"offset":10.0,"kind":"","tier":"field"}
}
var wetland_study: RefCounted=StudyRules.new()
var thermal_state: Dictionary = {}
var discovered: Dictionary = {}
var tracked_encounter := ""
var root_network_state: Dictionary = {}
var passage_state: Dictionary = {}
var passage_complete := false
var escort_state: Dictionary = {}
var escort_complete := false
var resonance_complete := false
var completed: Dictionary = {}
var optional: Dictionary = {}
var field: Dictionary = {}
var stillness: float = 0.0
var current_region := "aurora_shelf"
func _init() -> void: reset()
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
 if not data is Dictionary or not _number(data.get("version"),1,11): return {}
 if float(data.version)!=floorf(float(data.version)): return {}
 var version: int=int(data.version)
 var done: Variant=data.get("completed_regions") if version>=3 else data.get("completed")
 var extras: Variant=data.get("optional_observations") if version>=3 else data.get("optional",{})
 if version < 3 and not data.has("optional"):
  extras={}
  for id in OPTIONAL: extras[id]=false
 var notes: Variant=data.get("field_notes",{})
 if not _flags(done,REGIONS) or not _flags(extras,OPTIONAL): return {}
 if version>=4:
  if not _flags(notes,FIELD): return {}
 else:
  var migrated: Dictionary={}
  for id in FIELD: migrated[id]=false
  notes=migrated
 var study: Dictionary={}
 if version>=11:
  study=StudyRules.normalized(data.get("wetland_study"))
  if study.is_empty(): return {}
  if notes.marsh_reed and not study.prepared: return {}
  if notes.marsh_pool and not study.recovered: return {}
 else:
  study={"version":1,"prepared":bool(notes.marsh_reed or notes.marsh_pool),"startled":bool(notes.marsh_pool),"recovered":bool(notes.marsh_pool)}
 var discovery: Variant=data.get("discovered_regions",{}) if version>=9 else {}
 var tracked: Variant=data.get("tracked_encounter", "") if version>=9 else ""
 if not tracked is String or (tracked!="" and tracked not in REGIONS): return {}
 if version>=9:
  if not _flags(discovery,REGIONS): return {}
  if tracked!="" and not discovery[tracked]: return {}
 else:
  for id in REGIONS: discovery[id]=bool(done.get(id,false)) or data.get("current_region", "aurora_shelf")==id
 var network: Variant=data.get("root_network_state",{}) if version>=8 else {}
 if not network is Dictionary: return {}
 if not network.is_empty():
  network=RootRules.normalized(network)
  if network.is_empty(): return {}
 var passage_done: Variant=data.get("passage_complete") if version>=7 else false
 if not passage_done is bool: return {}
 var passage: Variant=data.get("passage_state",{}) if version>=7 else {}
 if not passage is Dictionary: return {}
 if not passage.is_empty():
  passage=PassageRules.normalized(passage)
  if passage.is_empty() or passage.complete!=passage_done: return {}
 elif passage_done: return {}
 var escort: Variant=data.get("escort_complete") if version>=6 else false
 if not escort is bool: return {}
 var progress: Variant=data.get("escort_state",{}) if version>=6 else {}
 if not progress is Dictionary: return {}
 if not progress.is_empty():
  progress=EscortRules.normalized(progress)
  if progress.is_empty() or progress.complete!=escort: return {}
 var escort_active: bool=escort or (not progress.is_empty() and progress.phase!="idle")
 var thermal: Variant=data.get("thermal_state",{}) if version>=10 else {}
 if not thermal is Dictionary: return {}
 if thermal.is_empty(): thermal={"version":1,"vent_observed":false,"route":"warm","locked":escort_active}
 else:
  thermal=ThermalRules.normalized(thermal)
  if thermal.is_empty() or thermal.locked!=escort_active: return {}
 var resonance: Variant=data.get("resonance_complete") if version>=5 else false
 if not resonance is bool: return {}
 var quiet: Variant=data.get("quiet_seconds") if version>=3 else data.get("stillness",0.0)
 if not _number(quiet,0,1e9): return {}
 var region: Variant=data.get("current_region","aurora_shelf")
 if not region is String or region not in REGIONS: return {}
 return {"version":11,"wetland_study":study,"thermal_state":thermal.duplicate(true),"discovered_regions":discovery.duplicate(true),"tracked_encounter":tracked,"root_network_state":network.duplicate(true),"passage_state":passage.duplicate(true),"passage_complete":passage_done,"escort_state":progress.duplicate(true),"escort_complete":escort,"resonance_complete":resonance,"completed_regions":done.duplicate(true),"optional_observations":extras.duplicate(true),"field_notes":notes.duplicate(true),"current_region":region,"quiet_seconds":minf(float(quiet),3.0) if version>=3 else 0.0}
func done(id: String) -> bool:
 return bool(completed.get(id,optional.get(id,field.get(id,false))))
func ready(id: String, observed: Dictionary) -> bool:
 if not SITES.has(id): return false
 if id=="marsh_pool" and not wetland_study.recovered: return false
 var kind: String=SITES[id].kind
 return kind.is_empty() or observed.get(kind,false)==true
func near(id: String, position: Vector3) -> bool:
 return SITES.has(id) and Vector2(position.x,position.z).distance_to(point(id))<=7.0
func tick(region: String, speed: float, observed: Dictionary, delta: float, position: Vector3=Vector3.INF) -> Array[String]:
 var events: Array[String]=[]
 if region not in REGIONS or not is_finite(speed) or not is_finite(delta) or delta<0: return events
 current_region=region
 discovered[region]=true
 if region=="aurora_shelf" and absf(speed)<1.5 and near("aurora_shelf",position): stillness=minf(3.0,stillness+delta)
 else: stillness=0.0
 if stillness>=3.0 and not completed["aurora_shelf"]: completed["aurora_shelf"]=true;events.append("aurora_shelf")
 return events
func can_record(id: String, region: String, position: Vector3, speed: float, observed: Dictionary) -> bool:
 return id!="aurora_shelf" and SITES.has(id) and region==SITES[id].region and not done(id) and is_finite(speed) and absf(speed)<1.5 and near(id,position) and ready(id,observed)
func record(id: String, region: String, position: Vector3, speed: float, observed: Dictionary) -> bool:
 if not can_record(id,region,position,speed,observed): return false
 if id=="marsh_reed": wetland_study.prepare()
 var tier: String=SITES[id].tier
 if tier=="optional": optional[id]=true
 elif tier=="field": field[id]=true
 else: completed[id]=true
 return true
func target(region: String) -> String:
 if region not in REGIONS: return ""
 # Mandatory objectives take priority, including unfinished regions behind the rover.
 var start: int=REGIONS.find(region)
 for step in REGIONS.size():
  var candidate: String=REGIONS[(start+step)%REGIONS.size()]
  if not completed[candidate]: return candidate
  for id in FIELD:
   if SITES[id].region==candidate and not field[id]: return id
 var optional_id: String=OPTIONAL[start]
 return optional_id if not optional[optional_id] else ""
func count() -> int:
 var result:=0
 for value in completed.values(): result+=int(value)
 return result
func optional_count() -> int:
 var result:=0
 for value in optional.values(): result+=int(value)
 return result
func field_count() -> int:
 var result:=0
 for value in field.values(): result+=int(value)
 return result
func snapshot() -> Dictionary:
 return {"version":11,"wetland_study":wetland_study.snapshot(),"thermal_state":thermal_state.duplicate(true),"discovered_regions":discovered.duplicate(true),"tracked_encounter":tracked_encounter,"root_network_state":root_network_state.duplicate(true),"passage_state":passage_state.duplicate(true),"passage_complete":passage_complete,"escort_state":escort_state.duplicate(true),"escort_complete":escort_complete,"resonance_complete":resonance_complete,"completed_regions":completed.duplicate(true),"optional_observations":optional.duplicate(true),"field_notes":field.duplicate(true),"current_region":current_region,"quiet_seconds":stillness}
func restore(data: Variant) -> bool:
 var incoming:=normalized(data)
 if incoming.is_empty(): return false
 wetland_study.restore(incoming.wetland_study)
 thermal_state=incoming.thermal_state
 discovered=incoming.discovered_regions
 tracked_encounter=incoming.tracked_encounter
 root_network_state=incoming.root_network_state
 passage_state=incoming.passage_state
 passage_complete=incoming.passage_complete
 escort_state=incoming.escort_state
 escort_complete=incoming.escort_complete
 resonance_complete=incoming.resonance_complete
 completed=incoming.completed_regions;optional=incoming.optional_observations;field=incoming.field_notes;current_region=incoming.current_region;stillness=incoming.quiet_seconds
 return true
func reset() -> void:
 wetland_study.reset()
 thermal_state={"version":1,"vent_observed":false,"route":"warm","locked":false}
 tracked_encounter=""
 for id in REGIONS: discovered[id]=false
 root_network_state.clear()
 passage_state.clear()
 passage_complete=false
 escort_state.clear()
 escort_complete=false
 resonance_complete=false
 for id in REGIONS: completed[id]=false
 for id in OPTIONAL: optional[id]=false
 for id in FIELD: field[id]=false
 current_region="aurora_shelf";stillness=0.0
