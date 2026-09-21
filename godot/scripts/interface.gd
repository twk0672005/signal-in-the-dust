extends CanvasLayer
## Bilingual expedition HUD. Every gameplay mutation is delegated through signals.
signal continue_saved_requested
signal start_requested
signal resume_requested
signal reset_requested
signal interact_requested
signal locale_changed(value: String)
signal settings_changed(config: Dictionary)

const PAPER := Color("eee8dc")
const MUTED := Color("b1aa9c")
const AMBER := Color("d5a56d")
const SIGNAL := Color("83c8c5")
const FONT_PATH := "res://assets/fonts/SignalSansTC.otf"
const COPY := {
	"site_aurora_lode": ["Field note · crystal seam", "場記 · 冰晶礦脈"],
	"site_aurora_ridge": ["Field note · wind ridge", "場記 · 風蝕脊"],
	"site_ember_lake": ["Field note · thermal basin", "場記 · 熱泉盆地"],
	"site_ember_cairn": ["Field note · mineral stack", "場記 · 礦石堆"],
	"site_marsh_reed": ["Field note · membrane reeds", "場記 · 膜葉叢"],
	"site_marsh_pool": ["Field note · still pool", "場記 · 靜水窪"],
	"site_pale_bone": ["Field note · shell remains", "場記 · 孢殼遺骸"],
	"site_pale_sink": ["Field note · root hollow", "場記 · 根脈窪地"],
	"field_count": ["FIELD %d/8", "場記 %d/8"],
	"survey_count": ["SURVEYS %d/4  ·  ECHOES %d/4", "測繪 %d/4  ·  回波 %d/4"],
	"survey_quiet": ["Hold still: %.1f / 3.0 s", "停車聆聽：%.1f / 3.0 秒"],
	"survey_recorded": ["Survey recorded. The echo spire is answering.", "測繪已記錄，回波石柱正在回應。"],
	"survey_guidance": ["Follow the survey distance. Observe life with E; stop beside an echo spire to record.", "循測繪距離前進。E 觀察生命；在回波石柱旁停車記錄。"],
	"survey_all": ["All surveys and field notes recorded. Approach the signal for first contact.", "四區測繪及場記已完成，前往訊號源進行接觸。"],
	"field_guidance": ["Main surveys complete. Finish the eight field notes before first contact.", "主線測繪完成，完成八個場記後才可進行初次接觸。"],
	"survey_region_done": ["Region recorded · continue exploring", "此區已記錄，可繼續探索"],
	"survey_action": ["E  RECORD THIS SITE", "E  記錄此地"],
	"observe_action": ["E  OBSERVE LIFE", "E  觀察生命"],
	"aurora_shelf": ["Aurora Shelf", "極光高原"],
	"ember_rift": ["Ember Rift", "熱泉裂谷"],
	"veil_marsh": ["Veil Marsh", "濃霧沼澤"],
	"pale_decay": ["Pale Decay", "孢子衰變"],
	"site_aurora_shelf": ["Crystal sound survey · stop for 3 s", "冰晶聲紋測繪 · 停車三秒"],
	"site_ember_rift": ["Thermal reading · observe Veyra first", "熱梯度測繪 · 先觀察礦脈群體"],
	"site_veil_marsh": ["Wetland reading · observe Aeral first", "濕地測繪 · 先觀察霧膜群"],
	"site_pale_decay": ["Shell pulse · observe Morrow first", "孢殼脈衝 · 先觀察孢殼群"],
	"site_aurora_echo": ["Optional · ridge echo", "支線 · 高原回波"],
	"site_ember_vent": ["Optional · outer thermal vent", "支線 · 外圍熱泉"],
	"site_marsh_crossing": ["Optional · membrane grove", "支線 · 膜葉林"],
	"site_spore_pulse": ["Optional · distant shell reef", "支線 · 遠方孢殼礁"],
	"ecology_near": ["Life nearby", "附近有生命"],
	"ecology_disturbed": ["Life disturbed · slow down", "生物受驚 · 請減速"],
	"continue_saved": ["Continue last expedition", "繼續上次探勘"],
	"new_run": ["New expedition", "開始新探勘"],
	"save_invalid": ["Saved progress could not be read. You can start a new expedition.", "無法讀取上次進度，可開始新探勘。"],
	"speed_label": ["SPEED", "車速"],
	"view_label": ["VIEW", "視角"],
	"first_person_label": ["FP", "第一身"],
	"third_person_label": ["TP", "第三身"],
	"title": ["SIGNAL\nIN THE DUST", "塵境回聲"],
	"edition": ["FIELD EXPEDITION  /  07", "地表探勘  /  07"],
	"intro": ["Something beneath the storm is listening.\nFollow its signal. Let it hear you.", "風暴之下，有什麼正在聆聽。\n循著訊號前進，讓它聽見你。"],
	"duration": ["Explore the four regions. Stop and listen.", "探索四大地區，停車聆聽生命。"],
	"begin": ["Begin expedition", "開始探勘"],
	"controls": ["WASD / arrows   Drive     SPACE   Brake\nRight-drag   Look     V   Camera     E   Observe / transmit     ESC   Pause", "WASD / 方向鍵   駕駛     空白鍵   煞車\n按住滑鼠右鍵拖曳   環顧     V   視角     E   觀察／發送     ESC   暫停"],
	"volume": ["Sound", "音量"],
	"motion": ["Reduced motion", "減少動態效果"],
	"quality": ["Low graphics", "低畫質"],
	"headphones": ["Headphones recommended", "建議佩戴耳機"],
	"goal": ["APPROACH THE SIGNAL", "接近訊號源"],
	"distance": ["SIGNAL DISTANCE", "訊號距離"],
	"storm": ["STORM FRONT  /  APPROACHING", "風暴前緣  /  逐漸逼近"],
	"rover": ["ROVER 07  /  SYSTEMS NOMINAL", "探勘車 07  /  系統正常"],
	"transmit": ["E   TRANSMIT A PULSE", "E   發送脈衝"],
	"contact": ["LISTEN", "聆聽"],
	"contact_sub": ["The landscape is answering.", "大地正在回應。"],
	"arrival": ["SURFACE ARRIVAL", "抵達地表"],
	"arrival_sub": ["A signal. Too regular to be the wind.", "一段訊號。規律得不像風聲。"],
	"ending": ["It heard you.", "它聽見了。"],
	"ending_sub": ["You sent a pulse into the silence.\nAn entire landscape answered.", "你向寂靜發送了一道脈衝。\n整片大地作出了回應。"],
	"recorded": ["FIRST CONTACT  /  RECORDED", "初次接觸  /  已記錄"],
	"replay": ["Explore again", "再次探索"],
	"paused": ["Expedition paused", "探勘已暫停"],
	"resume": ["Continue expedition", "繼續探勘"],
	"restart": ["Restart expedition", "重新開始探勘"],
	"confirm_reset": ["Return to the beginning?", "返回旅程起點？"],
	"reset_detail": ["Your current expedition will restart.\nYour language and settings will be kept.", "目前的探勘進度將會重置。\n語言與設定會保留。"],
	"confirm": ["Yes, restart", "確定重新開始"],
	"cancel": ["Keep exploring", "繼續探索"],
	"near": ["Stop beside the structure. Send a pulse.", "在構造體旁停車，發送一道脈衝。"],
	"blocked": ["The ground is too steep. Find another path.", "坡面過於陡峭，請尋找另一條路。"],
	"signal_found": ["Signal acquired. Follow the pale glow.", "已鎖定訊號，沿著微光前進。"],
	"transmitting": ["Pulse sent. Waiting for a response…", "脈衝已發送，等待回應……"],
	"response": ["This is not an echo.", "這並非回音。"],
	"ecology_observed": ["The organism changes its rhythm.", "生物改變了節奏。"],
	"pause_hint": ["ESC  Pause", "ESC  暫停"],
	"muted": ["Muted", "靜音"],
}

var _config: Dictionary = {"locale": "en", "volume": 0.65, "reduced_motion": false, "low_quality": false}
var _state := "menu"
var _saved_available := false
var _save_invalid := false
var _root: Control
var _hud: Control
var _overlay: Control
var _distance_label: Label
var _speed_label: Label
var _speed_mps: float = 0.0
var _max_speed_mps: float = 8.0
var _view_mode: String = "first_person"
var _ecology_readout: Dictionary = {}
var _speed_bar: ProgressBar
var _view_label: Label
var _ecology_label: Label
var _activity_label: Label
var _activity_context: Dictionary = {}
var _reticle: Label
var _interaction: Button
var _message: Label
var _contact_bar: ProgressBar
var _message_key := ""
var _distance := 0.0
var _elapsed := 0.0
var _progress := 0.0
var _can_interact := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_config.locale = "zh_TW" if OS.get_locale_language().begins_with("zh") else "en"
	var saved := ConfigFile.new()
	if saved.load("user://expedition.cfg") == OK:
		_config.locale = "zh_TW" if saved.get_value("settings", "locale", _config.locale) == "zh_TW" else "en"
		_config.volume = clampf(float(saved.get_value("settings", "volume", 0.65)), 0.0, 1.0)
		_config.reduced_motion = bool(saved.get_value("settings", "reduced_motion", false))
		_config.low_quality = bool(saved.get_value("settings", "low_quality", false))
	_build()

func _text(key: String) -> String:
	if not COPY.has(key):
		return ""
	return COPY[key][1 if _config.locale == "zh_TW" else 0]

func get_settings() -> Dictionary:
	return _config.duplicate()

func _save_settings() -> void:
	var saved := ConfigFile.new()
	for key in _config:
		saved.set_value("settings", key, _config[key])
	saved.save("user://expedition.cfg")
	settings_changed.emit(get_settings())

func _style(background: Color, border: Color, inset: int = 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(1)
	box.set_content_margin_all(inset)
	box.corner_radius_top_left = 2
	box.corner_radius_top_right = 2
	box.corner_radius_bottom_left = 2
	box.corner_radius_bottom_right = 2
	return box

func _build() -> void:
	if is_instance_valid(_root):
		_root.queue_free()
	_root = Control.new()
	_root.name = "ExpeditionInterface"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var theme := Theme.new()
	if ResourceLoader.exists(FONT_PATH):
		theme.default_font = load(FONT_PATH)
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", PAPER)
	for type_name in ["Button", "CheckButton"]:
		theme.set_color("font_color", type_name, PAPER)
		theme.set_color("font_hover_color", type_name, Color.WHITE)
		theme.set_color("font_focus_color", type_name, Color.WHITE)
	theme.set_stylebox("normal", "Button", _style(Color("232523"), Color("686052")))
	theme.set_stylebox("hover", "Button", _style(Color("3d382f"), AMBER))
	theme.set_stylebox("pressed", "Button", _style(Color("65513a"), AMBER))
	theme.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), PAPER, 3))
	theme.set_stylebox("focus", "CheckButton", _style(Color(0, 0, 0, 0), PAPER, 3))
	_root.theme = theme
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hud)
	_build_hud()
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_overlay)
	_build_overlay()
	_render_activity_context()
	update_readout(_distance, _elapsed, _progress, _can_interact, _speed_mps, _max_speed_mps, _view_mode, _ecology_readout)

func _label(text: String, size: int = 14, color: Color = PAPER) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func _button(key: String, action: Callable) -> Button:
	var result := Button.new()
	result.text = _text(key)
	result.custom_minimum_size.y = 42
	result.focus_mode = Control.FOCUS_ALL
	result.pressed.connect(action)
	return result

func _build_hud() -> void:
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 36
	top.offset_top = 28
	top.offset_right = -36
	_hud.add_child(top)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(left)
	left.add_child(_label(_text("goal"), 14, AMBER))
	_distance_label = _label("", 25)
	left.add_child(_distance_label)
	_speed_label = _label("", 16, PAPER)
	left.add_child(_speed_label)
	_speed_bar = ProgressBar.new()
	_speed_bar.custom_minimum_size = Vector2(210, 4)
	_speed_bar.max_value = 1.0
	_speed_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_speed_bar.show_percentage = false
	_speed_bar.add_theme_stylebox_override("background", _style(Color("252b2b"), Color.TRANSPARENT, 0))
	_speed_bar.add_theme_stylebox_override("fill", _style(AMBER, Color.TRANSPARENT, 0))
	left.add_child(_speed_bar)
	_activity_label = _label("",13,AMBER)
	_activity_label.custom_minimum_size.x=340
	_activity_label.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	_activity_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_activity_label)
	var right := VBoxContainer.new()
	top.add_child(right)
	var storm := _label(_text("storm"), 12)
	storm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(storm)
	var status := _label(_text("rover"), 12, MUTED)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(status)
	var hint := _label(_text("pause_hint"), 12, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(hint)
	_view_label = _label("", 12, AMBER)
	_view_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_view_label)
	_reticle = _label("·", 24, Color(0.93, 0.91, 0.86, 0.35))
	_reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_reticle.offset_left = -12
	_reticle.offset_right = 12
	_reticle.offset_top = -18
	_reticle.offset_bottom = 18
	_reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_reticle)
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.offset_left = -320
	bottom.offset_right = 320
	bottom.offset_top = -132
	bottom.offset_bottom = -40
	bottom.add_theme_constant_override("separation", 8)
	_hud.add_child(bottom)
	_message = _label(_text(_message_key), 14)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_message)
	_ecology_label = _label("", 12, MUTED)
	_ecology_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_ecology_label)
	_interaction = _button("transmit", func() -> void: interact_requested.emit())
	_interaction.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_interaction.custom_minimum_size.x = 260
	_interaction.add_theme_color_override("font_color", SIGNAL)
	bottom.add_child(_interaction)
	_contact_bar = ProgressBar.new()
	_contact_bar.custom_minimum_size = Vector2(220, 3)
	_contact_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_contact_bar.show_percentage = false
	_contact_bar.max_value = 1.0
	_contact_bar.add_theme_stylebox_override("background", _style(Color("282c2b"), Color.TRANSPARENT, 0))
	_contact_bar.add_theme_stylebox_override("fill", _style(SIGNAL, Color.TRANSPARENT, 0))
	bottom.add_child(_contact_bar)

func _build_overlay() -> void:
	_hud.visible = _state in ["exploring", "contact"]
	if _state == "exploring":
		return
	if _state in ["arrival", "contact"]:
		var captions := VBoxContainer.new()
		captions.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		captions.offset_left = -420
		captions.offset_right = 420
		captions.offset_top = -205 if _state == "contact" else -150
		captions.offset_bottom = -80
		_overlay.add_child(captions)
		for key in [_state, _state + "_sub"]:
			var caption := _label(_text(key), 19 if key == _state else 14, SIGNAL if _state == "contact" else PAPER)
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			captions.add_child(caption)
		return
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	panel.offset_left = 64
	panel.offset_right = 534
	panel.offset_top = -290 if _state == "menu" else -235
	panel.offset_bottom = 290 if _state == "menu" else 235
	panel.add_theme_stylebox_override("panel", _style(Color(0.055, 0.063, 0.064, 0.88), Color(0.55, 0.48, 0.36, 0.30), 26))
	_overlay.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 13)
	panel.add_child(column)
	column.add_child(_label(_text("edition"), 12, AMBER))
	var primary: Button
	if _state == "menu":
		column.add_child(_label(_text("title"), 38))
		column.add_child(_label(_text("intro"), 16))
		column.add_child(_label(_text("duration"), 12, MUTED))
		if _saved_available:
			primary = _button("continue_saved", func() -> void: continue_saved_requested.emit())
			primary.name = "ContinueSaved"
			column.add_child(primary)
			column.add_child(_button("new_run", func() -> void: start_requested.emit()))
		else:
			primary = _button("begin", func() -> void: start_requested.emit())
			column.add_child(primary)
		if _save_invalid: column.add_child(_label(_text("save_invalid"),12,AMBER))
		column.add_child(_label(_text("controls"), 12, MUTED))
		_build_settings(column)
		column.add_child(_label(_text("headphones"), 12, MUTED))
	elif _state == "paused":
		column.add_child(_label(_text("paused"), 28))
		primary = _button("resume", func() -> void: resume_requested.emit())
		column.add_child(primary)
		column.add_child(_button("restart", func() -> void: show_state("confirm_reset")))
		_build_settings(column)
		column.add_child(_label(_text("controls"), 12, MUTED))
	elif _state == "confirm_new":
		column.add_child(_label(_text("confirm_reset"),25))
		column.add_child(_label(_text("reset_detail"),14,MUTED))
		primary = _button("cancel", func() -> void: show_state("menu"))
		column.add_child(primary)
		column.add_child(_button("confirm", func() -> void: reset_requested.emit()))
	elif _state == "confirm_reset":
		column.add_child(_label(_text("confirm_reset"), 25))
		column.add_child(_label(_text("reset_detail"), 14, MUTED))
		primary = _button("cancel", func() -> void: resume_requested.emit())
		column.add_child(primary)
		column.add_child(_button("confirm", func() -> void: reset_requested.emit()))
	elif _state == "ending":
		column.add_child(_label(_text("recorded"), 12, SIGNAL))
		column.add_child(_label(_text("ending"), 34))
		column.add_child(_label(_text("ending_sub"), 16))
		primary = _button("replay", func() -> void: reset_requested.emit())
		column.add_child(primary)
		column.add_child(_label("%02d:%02d" % [int(_elapsed) / 60, int(_elapsed) % 60], 12, MUTED))
	if is_instance_valid(primary):
		primary.call_deferred("grab_focus")

func _build_settings(parent: VBoxContainer) -> void:
	var language := HBoxContainer.new()
	language.add_theme_constant_override("separation", 10)
	parent.add_child(language)
	for code in ["en", "zh_TW"]:
		var button := Button.new()
		button.text = "English" if code == "en" else "繁體中文"
		button.custom_minimum_size = Vector2(130, 34)
		button.toggle_mode = true
		button.button_pressed = _config.locale == code
		button.pressed.connect(_change_locale.bind(code))
		language.add_child(button)
	var sound_row := HBoxContainer.new()
	sound_row.add_theme_constant_override("separation", 16)
	parent.add_child(sound_row)
	sound_row.add_child(_label(_text("volume"), 14))
	var volume := HSlider.new()
	volume.name = "Volume"
	volume.custom_minimum_size = Vector2(160, 24)
	volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = float(_config.volume)
	volume.focus_mode = Control.FOCUS_ALL
	volume.tooltip_text = _text("volume")
	sound_row.add_child(volume)
	var value_label := _label("%d%%" % roundi(volume.value * 100.0), 12, MUTED)
	value_label.custom_minimum_size.x = 42
	sound_row.add_child(value_label)
	volume.value_changed.connect(func(value: float) -> void:
		_config.volume = value
		value_label.text = "%d%%" % roundi(value * 100.0)
		_save_settings())
	var options := HBoxContainer.new()
	parent.add_child(options)
	for pair in [["reduced_motion", "motion"], ["low_quality", "quality"]]:
		var check := CheckButton.new()
		check.text = _text(pair[1])
		check.add_theme_font_size_override("font_size", 14)
		check.button_pressed = bool(_config[pair[0]])
		check.toggled.connect(_toggle_setting.bind(pair[0]))
		options.add_child(check)

func _change_locale(value: String) -> void:
	_config.locale = value
	_save_settings()
	locale_changed.emit(value)
	_build()

func _toggle_setting(value: bool, key: String) -> void:
	_config[key] = value
	_save_settings()

func set_saved_available(value: bool, failed: bool = false) -> void:
	_saved_available = value
	_save_invalid = failed
	if _state == "menu" and is_instance_valid(_root): _build()

func show_state(state: String) -> void:
	if not state in ["menu", "arrival", "exploring", "contact", "ending", "paused", "confirm_reset", "confirm_new"]:
		return
	_state = state
	if is_instance_valid(_root):
		_build()

func update_readout(distance: float, elapsed: float, contact_progress: float, can_interact: bool, speed_mps: float = 0.0, max_speed_mps: float = 8.0, view_mode: String = "first_person", ecology_state: Dictionary = {}) -> void:
	_speed_mps = speed_mps
	_max_speed_mps = max_speed_mps
	_view_mode = view_mode
	_ecology_readout = ecology_state.duplicate()
	_distance = maxf(distance, 0.0)
	_elapsed = maxf(elapsed, 0.0)
	_progress = clampf(contact_progress, 0.0, 1.0)
	_can_interact = can_interact
	if not is_instance_valid(_distance_label):
		return
	_distance_label.text = "%03d m" % roundi(_distance)
	_speed_label.text = "%s  %.1f m/s  ·  %d km/h%s" % [_text("speed_label"), absf(speed_mps), roundi(absf(speed_mps)*3.6), "  R" if speed_mps < -0.05 else ""]
	_speed_bar.value = clampf(absf(speed_mps) / maxf(max_speed_mps, 0.1), 0.0, 1.0)
	_view_label.text = "%s  %s  [V]" % [_text("view_label"), _text("first_person_label" if view_mode == "first_person" else "third_person_label")]
	if not ecology_state.is_empty():
		var active := []
		for key in ["veyra", "aeral", "rootChoir"]:
			if ecology_state.get(key, "quiet") != "quiet":
				var value: String=str(ecology_state[key])
				active.append(_text("ecology_"+value) if value in ["near","disturbed"] else value)
		_ecology_label.text = " · ".join(active)
	else: _ecology_label.text = ""
	_interaction.visible = _can_interact and _state == "exploring"
	_reticle.text = "+" if _can_interact else "·"
	_reticle.modulate = SIGNAL if _can_interact else Color(1, 1, 1, 0.35)
	_reticle.visible = _state == "exploring"
	_contact_bar.visible = _state == "contact"
	_contact_bar.value = _progress

func set_activity_progress(done: int, optional_done: int, field_done: int, region: String, target: String = "", distance: float = 0.0, quiet: float = 0.0, bearing: float = 0.0) -> void:
	_activity_context={"done":done,"optional":optional_done,"field":field_done,"region":region,"target":target,"distance":distance,"quiet":quiet,"bearing":bearing}
	_render_activity_context()

func _render_activity_context() -> void:
	if not is_instance_valid(_activity_label) or _activity_context.is_empty(): return
	var d:=_activity_context
	var lines: String=(_text("survey_count") % [d.done,d.optional])+"  "+(_text("field_count") % d.get("field",0))
	lines+="\n"+_text(d.region)
	if not str(d.target).is_empty():
		var direction := "^" if absf(d.bearing)<0.25 else (">" if d.bearing>0 else "<")
		lines+="\n"+direction+" "+_text("site_"+str(d.target))+" · %d m" % roundi(d.distance)
		if d.target=="aurora_shelf" and d.distance<=7.0:
			lines+="\n"+(_text("survey_quiet") % snappedf(d.quiet,0.1))
	else: lines+="\n"+_text("survey_region_done")
	_activity_label.text=lines

func set_interaction_kind(kind: String) -> void:
	if not is_instance_valid(_interaction): return
	_interaction.text=_text("survey_action" if kind.begins_with("survey:") else ("observe_action" if kind=="ecology" else "transmit"))


func set_message(key: String) -> void:
	_message_key = key
	if is_instance_valid(_message):
		_message.text = _text(key)

func set_view_message(view_mode: String) -> void:
	_view_mode = view_mode
	if is_instance_valid(_view_label):
		_view_label.text = "%s  %s  [V]" % [_text("view_label"), _text("first_person_label" if view_mode == "first_person" else "third_person_label")]
