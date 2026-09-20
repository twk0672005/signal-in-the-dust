extends RefCounted
const REGIONS: Array[String] = ["aurora_shelf", "ember_rift", "veil_marsh", "pale_decay"]
var completed: Dictionary = {"aurora_shelf":false,"ember_rift":false,"veil_marsh":false,"pale_decay":false}
var stillness: float = 0.0
func tick(region: String, speed: float, observed: Dictionary, delta: float) -> void:
	if region == "aurora_shelf" and absf(speed) < 1.5: stillness += maxf(delta,0.0)
	else: stillness = 0.0
	if stillness >= 3.0: completed["aurora_shelf"] = true
	if region == "ember_rift" and bool(observed.get("veyra",false)): completed["ember_rift"] = true
	if region == "veil_marsh" and bool(observed.get("aeral",false)): completed["veil_marsh"] = true
	if region == "pale_decay" and bool(observed.get("root_choir",false)): completed["pale_decay"] = true
func count() -> int:
	var total: int = 0
	for value in completed.values(): total += 1 if value else 0
	return total
func snapshot() -> Dictionary:
	return {"version":1,"completed":completed.duplicate(true),"stillness":stillness}
func restore(data: Variant) -> bool:
	if not data is Dictionary or int(data.get("version",0)) != 1: return false
	var incoming: Variant = data.get("completed")
	if not incoming is Dictionary: return false
	for index in REGIONS.size():
		var key: String = REGIONS[index]
		if not incoming.has(key) or not incoming[key] is bool: return false
		completed[key] = incoming[key]
	var value: Variant = data.get("stillness",0.0)
	if not (value is float or value is int) or not is_finite(float(value)) or float(value)<0.0 or float(value)>10.0: return false
	stillness = float(value)
	return true
func reset() -> void:
	for index in REGIONS.size(): completed[REGIONS[index]] = false
	stillness = 0.0
