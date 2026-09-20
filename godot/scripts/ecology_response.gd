extends RefCounted
## Local deterministic stimulus response; no random decisions or runtime services.
var alert := 0.0
var recovery := 0.0
var pulse := 0.0

func step(distance: float, speed: float, delta: float) -> void:
	if delta <= 0.0: return
	if distance < 24.0 and absf(speed) > 5.5:
		recovery = 4.0
		alert = move_toward(alert, 1.0, delta * 1.8)
	else:
		recovery = maxf(0.0, recovery - delta)
		if recovery == 0.0: alert = move_toward(alert, 0.0, delta * 0.35)
	pulse = maxf(0.0, pulse - delta)

func observe() -> void:
	pulse = 2.4

func pulse_amount() -> float:
	return sin(clampf(pulse / 2.4, 0.0, 1.0) * PI)

func reset() -> void:
	alert = 0.0
	recovery = 0.0
	pulse = 0.0
