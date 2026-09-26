extends RefCounted
## One authored contextual cue at a time. This does not generate dialogue or change game state.
var clock := 0.0
var key := ""
var message := ""
var priority := 0
var expires := 0.0
var _cooldowns: Dictionary = {}

func advance(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0: return
	clock += delta
	if clock >= expires: clear()

func clear() -> void:
	key = ""
	message = ""
	priority = 0
	expires = clock

func reset() -> void:
	clear()
	_cooldowns.clear()

func offer(id: String, text: String, importance: int = 30, duration: float = 6.0, cooldown: float = 35.0, refresh: bool = false) -> bool:
	if id.is_empty() or text.is_empty(): return false
	if id == key:
		message = text
		if refresh: expires = clock + duration
		return false
	if float(_cooldowns.get(id, 0.0)) > clock: return false
	if not key.is_empty() and (importance < priority or (importance == priority and not refresh)): return false
	key = id
	message = text
	priority = importance
	expires = clock + duration
	_cooldowns[id] = clock + cooldown
	return true
