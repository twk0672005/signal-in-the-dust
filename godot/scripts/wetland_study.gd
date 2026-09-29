extends RefCounted
var prepared:=false
var startled:=false
var recovered:=false
func prepare() -> bool:
	if prepared: return false
	prepared=true
	return true
func observe(kind: String, alert: float) -> String:
	if not prepared or recovered or kind!="aeral" or not is_finite(alert) or alert<0.0 or alert>1.0: return ""
	if not startled and alert>=0.65:
		startled=true
		return "startled"
	# Calm observation is a valid study result; disturbing wildlife is optional.
	if alert<=0.1:
		recovered=true
		return "recovered" if startled else "quiet"
	return ""
func reset() -> void:
	prepared=false;startled=false;recovered=false
func snapshot() -> Dictionary:
	return {"version":2,"prepared":prepared,"startled":startled,"recovered":recovered}
static func normalized(data: Variant) -> Dictionary:
	if not data is Dictionary: return {}
	var version: Variant=data.get("version")
	if not (version is int or version is float) or not is_finite(float(version)) or float(version) not in [1.0,2.0]: return {}
	for key in ["prepared","startled","recovered"]:
		if not data.get(key) is bool: return {}
	if data.startled and not data.prepared: return {}
	if data.recovered and (not data.prepared or (float(version)==1.0 and not data.startled)): return {}
	return {"version":2,"prepared":data.prepared,"startled":data.startled,"recovered":data.recovered}
func restore(data: Variant) -> bool:
	var incoming:=normalized(data)
	if incoming.is_empty(): return false
	prepared=incoming.prepared;startled=incoming.startled;recovered=incoming.recovered
	return true
