extends RefCounted
var vent_observed:=false
var route:="warm"
var locked:=false
func observe(pulse: float) -> bool:
	if locked or vent_observed or not is_finite(pulse) or pulse<0.75 or pulse>1.0: return false
	vent_observed=true
	return true
func toggle_route() -> bool:
	if locked or not vent_observed: return false
	route="cool" if route=="warm" else "warm"
	return true
func lock_route() -> bool:
	if locked: return false
	locked=true
	return true
func reset() -> void:
	vent_observed=false;route="warm";locked=false
func snapshot() -> Dictionary:
	return {"version":1,"vent_observed":vent_observed,"route":route,"locked":locked}
static func normalized(data: Variant) -> Dictionary:
	if not data is Dictionary: return {}
	var version: Variant=data.get("version")
	if not (version is int or version is float) or not is_finite(float(version)) or float(version)!=1.0: return {}
	if not data.get("vent_observed") is bool or not data.get("locked") is bool: return {}
	if data.get("route") not in ["warm","cool"]: return {}
	if data.route=="cool" and not data.vent_observed: return {}
	return {"version":1,"vent_observed":data.vent_observed,"route":str(data.route),"locked":data.locked}
func restore(data: Variant) -> bool:
	var incoming:=normalized(data)
	if incoming.is_empty(): return false
	vent_observed=incoming.vent_observed;route=incoming.route;locked=incoming.locked
	return true
