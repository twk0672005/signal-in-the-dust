extends Node
## Original offline-rendered PCM samples; no runtime procedural generator.
var _players: Dictionary = {}
var _volume := 0.65
var _drive := 0.0
var _signal := 0.0
var _paused := false
var _reveal := false

func _exit_tree() -> void:
	for player: AudioStreamPlayer in _players.values():
		player.stop()
	_players.clear()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in ["wind", "rolling", "servo", "pulse", "transmit", "response"]:
		var player := AudioStreamPlayer.new()
		player.name = key.capitalize()
		player.stream = load("res://assets/audio/" + key + ".wav")
		player.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
		player.volume_db = -80.0
		if key in ["wind", "rolling", "servo", "pulse"]:
			var sample := player.stream as AudioStreamWAV
			sample.loop_mode = AudioStreamWAV.LOOP_FORWARD
			sample.loop_begin = 0
			sample.loop_end = int(sample.get_length() * sample.mix_rate)
		add_child(player)
		_players[key] = player
		if key in ["wind", "rolling", "servo", "pulse"]:
			player.play()

func _process(delta: float) -> void:
	var duck := 0.16 if _paused else 1.0
	var gains := {"wind": 0.29 if _reveal else 0.42, "rolling": _drive * 0.33, "servo": _drive * 0.13, "pulse": _signal * (0.13 if _reveal else 0.32), "transmit": 0.58, "response": 0.68}
	for key in _players:
		var player: AudioStreamPlayer = _players[key]
		var target: float = float(gains[key]) * _volume * duck
		# Smooth linear amplitude prevents slider and speed changes from clicking.
		player.volume_linear = lerpf(player.volume_linear, target, 1.0 - exp(-delta * 3.5))

func set_mix(volume: float) -> void:
	_volume = clampf(volume, 0.0, 1.0)
	if _volume == 0.0:
		for player: AudioStreamPlayer in _players.values():
			player.volume_linear = 0.0

func set_drive(speed: float) -> void:
	_drive = clampf(absf(speed) / 24.0, 0.0, 1.0)

func set_signal(distance: float) -> void:
	_signal = pow(clampf(1.0 - distance / 240.0, 0.0, 1.0), 1.7)

func play_transmit() -> void:
	if _players.has("transmit"):
		_players.transmit.play()

func play_reveal() -> void:
	_reveal = true
	if _players.has("response"):
		_players.response.play()

func set_paused(value: bool) -> void:
	_paused = value
	# Ambience ducks; time-critical response retains its position while paused.
	for key in ["transmit", "response"]:
		if _players.has(key):
			_players[key].stream_paused = value

func reset() -> void:
	_drive = 0.0
	_signal = 0.0
	_reveal = false
	_paused = false
	for key in _players:
		var player: AudioStreamPlayer = _players[key]
		player.stream_paused = false
		player.stop()
		if key in ["wind", "rolling", "servo", "pulse"]:
			player.play()


