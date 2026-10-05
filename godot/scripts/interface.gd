extends CanvasLayer
const Brand = preload("res://scripts/brand.gd")
const ShowcaseMinimap = preload("res://scripts/showcase_minimap.gd")
const ShowcaseWhispers = preload("res://scripts/showcase_whispers.gd")
## Bilingual expedition HUD. Every gameplay mutation is delegated through signals.
signal continue_requested
signal start_requested
signal resume_requested
signal reset_requested
signal interact_requested
signal locale_changed(value: String)
signal settings_changed(config: Dictionary)
signal menu_requested

const PAPER := Color("f1ede1")
const MUTED := Color("c0cbc1")
const AMBER := Color("e4c995")
const SIGNAL := Color("a9d9c8")
const FONT_PATH := "res://assets/fonts/SignalSansTC.otf"
const COPY := {
	"journal_empty": ["Your observations will appear here.","沿途的觀察會留在這裡。"],
	"observed_veyra": ["Veyra turns toward you. Its mineral plates brighten as it settles.","Veyra 轉向你，平靜下來時，礦質甲片漸漸亮起。"],
	"observed_aeral": ["Aeral turns toward you. Its membranes glow, then settle.","霧翼群轉向你，薄膜泛起微光，再慢慢平復。"],
	"observed_root_choir": ["Light travels across the Morrow shells, then fades into the ground.","微光沿著孢殼移動，再慢慢滲入地面。"],
	"landmark_world_tree": ["World tree","世界樹"],
	"observed_world_tree": ["A slow glow climbs the living branches. The tree continues its quiet rhythm.","微光沿活枝緩緩上行，世界樹維持著自己的節奏。"],
	"landmark_aurora_shelf": ["Frost crystals","霜晶群"],
	"observed_aurora_shelf": ["Ice-blue veins brighten within the ridgeline.","冰藍色的紋路在晶脊裡漸漸亮起。"],
	"landmark_ember_rift": ["Thermal minerals","熱泉礦簇"],
	"observed_ember_rift": ["Warm minerals glow between the cooling rocks.","暖色礦物在逐漸冷卻的岩層間發光。"],
	"landmark_veil_marsh": ["Wetland membranes","濕地膜葉"],
	"observed_veil_marsh": ["Moisture beads along the luminous tissue.","水珠沿發光的薄膜凝聚。"],
	"landmark_pale_decay": ["Spore reef","孢子礁"],
	"observed_pale_decay": ["Faint light traces life through the decaying shells.","微光在衰變的孢殼間勾勒出生命。"],
	"landmark_aurora_echo": ["Singing crystal grove","鳴晶林"],
	"observed_aurora_echo": ["The crystals open slightly and sound a soft, uneven chord.","冰晶微微展開，發出輕柔而不規則的和音。"],
	"landmark_ember_vent": ["Outer thermal vent","外圍熱泉"],
	"observed_ember_vent": ["Mineral light shimmers through the rising plume.","礦物微光在升起的噴流中閃動。"],
	"landmark_marsh_crossing": ["Membrane grove","膜葉林"],
	"observed_marsh_crossing": ["The membranes catch the damp air and sway.","膜葉迎著濕潤的氣流輕輕擺動。"],
	"landmark_spore_pulse": ["Distant shell reef","遠方孢殼礁"],
	"observed_spore_pulse": ["A pale pulse passes between the shell ridges.","一道淡光在孢殼的脊線間掠過。"],
	"landmark_aurora_lode": ["Exposed crystal lode","裸露晶脈"],
	"observed_aurora_lode": ["Fine mineral threads light the fractured stone.","細小的礦物紋路照亮碎裂岩面。"],
	"landmark_aurora_ridge": ["Ridge overlook","高原觀景點"],
	"observed_aurora_ridge": ["The ridgeline opens onto the thermal basin beyond.","越過脊線，可以看見遠方的熱泉盆地。"],
	"landmark_ember_lake": ["Mineral lake shore","礦湖岸線"],
	"observed_ember_lake": ["Warm deposits glow beside the sheltered shore.","暖色沉積物在避風的岸邊泛光。"],
	"landmark_ember_cairn": ["Basalt spires","玄武岩柱"],
	"observed_ember_cairn": ["Layered rock holds the heat of the basin.","層疊的岩石保留著盆地的熱量。"],
	"landmark_marsh_reed": ["Mist reeds","霧中蘆膜"],
	"observed_marsh_reed": ["Thin tissue gathers droplets from the mist.","薄膜從霧中收集細小水滴。"],
	"landmark_marsh_pool": ["Living pool","活水窪"],
	"observed_marsh_pool": ["Light stirs beneath the quiet water.","平靜水面之下，微光緩緩流動。"],
	"landmark_pale_bone": ["Ancient shell bed","古老孢殼床"],
	"observed_pale_bone": ["New growth glows among the old shells.","新的生命在古老孢殼間泛起微光。"],
	"landmark_pale_sink": ["Spore hollow","孢子窪地"],
	"observed_pale_sink": ["The hollow shelters a slow rhythm of growth and decay.","窪地包容著生長與衰變的緩慢節奏。"],
	"save_clear_failed": ["The saved expedition could not be cleared. Your previous checkpoint is still available; try again when browser storage is writable.", "未能清除已儲存的探勘。舊進度仍然保留，請在瀏覽器可寫入儲存空間後再試。"],
	"save_write_failed": ["Progress could not be saved. You can keep playing.", "未能儲存進度。你仍可繼續遊玩。"],
	"aurora_shelf": ["Aurora Shelf", "極光高原"],
	"ember_rift": ["Ember Rift", "熱泉裂谷"],
	"veil_marsh": ["Veil Marsh", "濃霧沼澤"],
	"pale_decay": ["Pale Decay", "孢子衰變"],
	"species_veyra": ["Veyra Lithovore", "Veyra 礦脈生物"],
	"species_aeral": ["Aeral Veil", "Aeral 霧翼群"],
	"species_root_choir": ["Morrow Shell · Root Choir", "Morrow 孢殼群 · 根脈合唱"],
	"crawl_hint": ["CRAWL", "慢行"],
	"save_invalid": ["Saved progress could not be read. You can start a new expedition.", "無法讀取上次進度，可開始新探勘。"],
	"speed_label": ["SPEED", "車速"],
	"view_label": ["VIEW", "視角"],
	"first_person_label": ["FP", "第一身"],
	"third_person_label": ["TP", "第三身"],
	"controls": ["WASD / arrows   Drive     C (hold)   Crawl\nSHIFT   Boost     SPACE   Brake     S   Brake / reverse\nRight-drag   Look     V   Camera     E   Observe\nJ   Journal     ESC   Pause", "WASD / 方向鍵   駕駛     按住 C   慢行\nSHIFT   加速     空白鍵   煞車     S   煞車／倒車\n按住右鍵拖曳   環顧     V   視角     E   觀察\nJ   日誌     ESC   暫停"],
	"volume": ["Sound", "音量"],
	"motion": ["Reduced motion", "減少動態效果"],
	"quality": ["Lighter graphics", "輕量畫面"],
	"whispers": ["Ambient observations", "沿途觀察提示"],
	"headphones": ["Headphones recommended", "建議佩戴耳機"],
	"rover": ["ROVER 07  /  SYSTEMS NOMINAL", "探勘車 07  /  系統正常"],
	"transmit": ["E · Observe", "E · 觀察"],
	"journal_back": ["ESC · CONTINUE WANDERING", "ESC · 繼續漫遊"],
	"departure": ["A NEW BEGINNING  /  07", "新的起點  /  07"],
	"confirm_reset": ["Return to the beginning?", "返回旅程起點？"],
	"confirm": ["Yes, restart", "確定重新開始"],
	"cancel": ["Return to game", "返回遊戲"],
	"pause_hint": ["ESC  Pause · J  Journal", "ESC  暫停 · J  日誌"],
	"author_contact": ["Suggestions or collaboration · Contact the author", "有建議／合作，歡迎聯絡作者"],
	"desktop_detail": ["Desktop offers richer visual detail. Low detail keeps mobile play lighter.", "電腦版可呈現更豐富的畫面細節；手機可選低畫質。"],
	"settings_title": ["Expedition settings", "探索設定"],
	"open_settings": ["Settings", "設定"],
	"back_to_pause": ["Back", "返回暫停選單"],
}

var _config: Dictionary = {"locale": "en", "volume": 0.65, "reduced_motion": false, "low_quality": false, "whispers": true}
var _mobile := false
var _state := "menu"
var _saved_available := false
var _save_invalid := false
var _clear_failed := false
var _write_failed := false
var _saved_contact_completed := false
var _root: Control
var _hud: Control
var _overlay: Control
var _distance_label: Label
var _navigation_label: Label
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
var _journal_context: Dictionary = {"entries": {}, "tracked": ""}
var _reticle: Label
var _interaction: Button
var _interaction_kind := ""
var _interaction_context: Dictionary = {}
var _feedback_panel: PanelContainer
var _message: Label
var _message_key := ""
var _distance := 0.0
var _elapsed := 0.0
var _can_interact := false
var _minimap: Control
var _map_road := PackedVector2Array()
var _map_context: Dictionary = {}
var _region_label: Label
var _guidance = ShowcaseWhispers.new()
var _whisper_chime: AudioStreamPlayer

func _ready() -> void:
	_mobile = OS.has_feature("web") and bool(JavaScriptBridge.eval("window.__EXPEDITION_TOUCH__ === true",true))
	if _mobile: _config.low_quality = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_config.locale = "zh_TW" if OS.get_locale_language().begins_with("zh") else "en"
	var saved := ConfigFile.new()
	if saved.load("user://expedition.cfg") == OK:
		_config.locale = "zh_TW" if saved.get_value("settings", "locale", _config.locale) == "zh_TW" else "en"
		_config.volume = clampf(float(saved.get_value("settings", "volume", 0.65)), 0.0, 1.0)
		_config.reduced_motion = bool(saved.get_value("settings", "reduced_motion", false))
		_config.low_quality = bool(saved.get_value("settings", "low_quality", _mobile))
		_config.whispers = bool(saved.get_value("settings", "whispers", true))
	_whisper_chime = AudioStreamPlayer.new()
	_whisper_chime.stream = load("res://assets/audio/whisper.wav")
	_whisper_chime.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_whisper_chime)
	DisplayServer.window_set_title(Brand.text("title", str(_config.locale)))
	_build()
	get_viewport().size_changed.connect(_build)

func _exit_tree() -> void:
	if is_instance_valid(_whisper_chime):
		_whisper_chime.stop()
		_whisper_chime.stream = null

func _text(key: String) -> String:
	var branded := Brand.text(key, str(_config.locale))
	if not branded.is_empty(): return branded
	if not COPY.has(key):
		return ""
	return COPY[key][1 if _config.locale == "zh_TW" else 0]

func get_settings() -> Dictionary:
	return _config.duplicate()

func current_state() -> String:
	return _state

func apply_startup_settings(overrides: Dictionary) -> void:
	# The web bridge validates these explicit overrides. Unchanged preferences stay saved.
	if overrides.is_empty(): return
	for key in overrides:
		if _config.has(key): _config[key] = overrides[key]
	_save_settings()
	locale_changed.emit(str(_config.locale))
	_build()

func _cancel_new() -> void:
	show_state("menu")
	menu_requested.emit()

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
	theme.set_icon("checked", "CheckButton", load("res://assets/ui/toggle-on.svg"))
	theme.set_icon("unchecked", "CheckButton", load("res://assets/ui/toggle-off.svg"))
	theme.set_color("font_color", "Label", PAPER)
	for type_name in ["Button", "CheckButton"]:
		theme.set_color("font_color", type_name, PAPER)
		theme.set_color("font_hover_color", type_name, Color.WHITE)
		theme.set_color("font_focus_color", type_name, Color.WHITE)
	theme.set_stylebox("normal", "Button", _style(Color("1b302d"), Color("688477")))
	theme.set_stylebox("hover", "Button", _style(Color("30473d"), AMBER))
	theme.set_stylebox("pressed", "Button", _style(Color("5d6145"), AMBER))
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
	if _mobile:
		var scale := maxf(1.0, get_viewport().get_visible_rect().size.y / maxf(1.0, DisplayServer.window_get_size().y))
		_overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		_overlay.size = get_viewport().get_visible_rect().size / scale
		_overlay.scale = Vector2.ONE * scale
	_build_overlay()
	_render_activity_context()
	update_readout(_distance, _elapsed, 0.0, _can_interact, _speed_mps, _max_speed_mps, _view_mode, _ecology_readout)
	_render_interaction_context()

func _label(text: String, size: int = 14, color: Color = PAPER) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.add_theme_color_override("font_outline_color", Color(0.035,0.055,0.055,0.9))
	result.add_theme_constant_override("outline_size", 2)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func _button(key: String, action: Callable) -> Button:
	var result := Button.new()
	result.text = _text(key)
	result.custom_minimum_size.y = 48
	result.focus_mode = Control.FOCUS_ALL
	result.pressed.connect(action)
	return result

func _build_hud() -> void:
	# Match physical touch sizes when the 900px canvas stretches into a short screen.
	var scale := maxf(1.0, get_viewport().get_visible_rect().size.y / maxf(1.0, DisplayServer.window_get_size().y)) if _mobile else 1.0
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 14 * scale if _mobile else 36
	top.offset_top = 10 * scale if _mobile else 32
	top.offset_right = -14 * scale if _mobile else -36
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(top)
	var panel := PanelContainer.new()
	panel.name = "CurrentHabitat"
	panel.visible = _state != "contact"
	panel.custom_minimum_size.x = 200 * scale if _mobile else 230
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var route_style := _style(Color(0.035, 0.09, 0.08, 0.76), Color(0.66, 0.85, 0.78, 0.42), roundi(14 * scale))
	route_style.set_border_width_all(0)
	route_style.border_width_left = 2
	panel.add_theme_stylebox_override("panel", route_style)
	top.add_child(panel)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_theme_constant_override("separation", roundi(6 * scale))
	panel.add_child(left)
	_region_label = _label("", roundi(13 * scale) if _mobile else 16, PAPER)
	left.add_child(_region_label)
	_distance_label = _label("", roundi(17 * scale) if _mobile else 22)
	_distance_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_distance_label)
	_navigation_label = _label("", roundi(13 * scale) if _mobile else 16, AMBER)
	_navigation_label.name = "RouteDirection"
	left.add_child(_navigation_label)
	_activity_label = _label("", roundi(13 * scale) if _mobile else 15, PAPER)
	_activity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_activity_label)
	var instruments := left
	if not _mobile or _state == "contact":
		var glass := PanelContainer.new()
		glass.name = "RoverInstrumentGlass"
		glass.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		if _mobile:
			glass.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
			glass.offset_left = 14 * scale
			glass.offset_right = 242 * scale
			glass.offset_top = 10 * scale
			glass.offset_bottom = 72 * scale
		else:
			glass.offset_left = 22
			glass.offset_right = 313
			glass.offset_top = -106
			glass.offset_bottom = -21
		glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glass.add_theme_stylebox_override("panel",_style(Color(0.035,0.09,0.09,0.78),Color(0.45,0.61,0.56,0.3),12))
		_hud.add_child(glass)
		instruments = VBoxContainer.new()
		instruments.name = "RoverInstruments"
		instruments.mouse_filter = Control.MOUSE_FILTER_IGNORE
		instruments.add_theme_constant_override("separation", 8)
		glass.add_child(instruments)
		if not _mobile: instruments.add_child(_label(_text("rover"), 10, SIGNAL))
	_speed_label = _label("", roundi(12 * scale) if _mobile else 19, PAPER)
	_speed_label.name = "Speedometer"
	instruments.add_child(_speed_label)
	_speed_bar = ProgressBar.new()
	_speed_bar.custom_minimum_size = Vector2(190 * scale, 2 * scale)
	_speed_bar.max_value = 1.0
	_speed_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_speed_bar.show_percentage = false
	_speed_bar.add_theme_stylebox_override("background", _style(Color("252b2b"), Color.TRANSPARENT, 0))
	_speed_bar.add_theme_stylebox_override("fill", _style(AMBER, Color.TRANSPARENT, 0))
	instruments.add_child(_speed_bar)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var right := VBoxContainer.new()
	top.add_child(right)
	if _mobile:
		var touch_space := Control.new()
		touch_space.custom_minimum_size.y = 60 * scale
		right.add_child(touch_space)
	_minimap = ShowcaseMinimap.new()
	_minimap.name = "ExplorerMinimap"
	_minimap.custom_minimum_size = Vector2(86, 86) * scale if _mobile else Vector2(136, 136)
	_minimap.set_road(_map_road)
	right.add_child(_minimap)
	var hint := _label(_text("pause_hint"), 13, PAPER)
	hint.visible = not _mobile
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(hint)
	_view_label = _label("", roundi(11 * scale) if _mobile else 13, PAPER)
	_view_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_view_label)
	if not _map_context.is_empty():
		_minimap.set_navigation(_map_context.position, _map_context.heading, _map_context.target, _map_context.has_target)
	_reticle = _label("·", 24, Color(0.93, 0.91, 0.86, 0.35))
	_reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_reticle.offset_left = -12
	_reticle.offset_right = 12
	_reticle.offset_top = -18
	_reticle.offset_bottom = 18
	_reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_reticle)
	_feedback_panel = PanelContainer.new()
	_feedback_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	var half_width := minf(235 * scale, get_viewport().get_visible_rect().size.x * 0.5 - 24 * scale) if _mobile else minf(330.0, get_viewport().get_visible_rect().size.x * 0.29)
	_feedback_panel.offset_left = -half_width
	_feedback_panel.offset_right = half_width
	_feedback_panel.offset_top = -121 * scale if _mobile else -60
	_feedback_panel.offset_bottom = -88 * scale if _mobile else -31
	_feedback_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_feedback_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var feedback_style := _style(Color(0.035, 0.09, 0.08, 0.78), Color(0.66, 0.85, 0.78, 0.35), roundi(10 * scale))
	feedback_style.set_border_width_all(0)
	feedback_style.border_width_top = 1
	_feedback_panel.add_theme_stylebox_override("panel", feedback_style)
	_hud.add_child(_feedback_panel)
	var bottom := VBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", roundi(5 * scale))
	_feedback_panel.add_child(bottom)
	_message = _label(_guidance.message, roundi(13 * scale) if _mobile else 16)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.visible = not _guidance.key.is_empty()
	bottom.add_child(_message)
	_ecology_label = _label("", roundi(13 * scale) if _mobile else 16, AMBER)
	_ecology_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ecology_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(_ecology_label)
	_ecology_label.visible = false
	_interaction = _button("transmit", func() -> void: interact_requested.emit())
	_interaction.name = "InteractionAction"
	_interaction.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_interaction.custom_minimum_size.x = 260
	_interaction.add_theme_font_size_override("font_size", 16)
	_interaction.visible = not _mobile
	_interaction.add_theme_color_override("font_color", SIGNAL)
	bottom.add_child(_interaction)

func _build_overlay() -> void:
	var available := get_viewport().get_visible_rect().size / _overlay.scale
	_hud.visible = _state == "exploring"
	if _state == "exploring":
		return
	var panel := PanelContainer.new()
	panel.name = "JourneyPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	panel.offset_left = 20 if _mobile else 64
	panel.offset_right = minf(550.0, available.x - 20.0) if _mobile else 654
	if _mobile and _state == "settings":
		panel.offset_right = minf(780.0, available.x - 20.0)
	var desired_panel_height := 720.0 if _state in ["menu", "settings"] else (640.0 if _state == "journal" else ((340.0 if _mobile else 480.0) if _state == "confirm_new" else (290.0 if _state == "confirm_reset" else 560.0)))
	var panel_height := minf(desired_panel_height, maxf(220.0, available.y - 32.0))
	panel.offset_top = -panel_height * 0.5
	panel.offset_bottom = panel_height * 0.5
	var sheet_style := _style(Color(0.035, 0.09, 0.08, 0.9), Color(0.66, 0.85, 0.78, 0.4), 20 if _mobile else 30)
	sheet_style.border_width_top = 2
	panel.add_theme_stylebox_override("panel", sheet_style)
	_overlay.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8 if _mobile else 13)
	scroll.add_child(column)
	if not (_mobile and _state == "settings"):
		column.add_child(_label(_text("departure" if _state == "confirm_new" else "edition"), 12, SIGNAL if _state == "confirm_new" else AMBER))
	if _clear_failed or _write_failed:
		var warning:=_label(_text("save_clear_failed" if _clear_failed else "save_write_failed"),13,AMBER)
		warning.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		column.add_child(warning)
	var primary: Button
	if _state == "menu":
		column.add_child(_label(_text("title"), 26 if _mobile else 38))
		var introduction := _label(_text("intro"), 16)
		introduction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(introduction)
		column.add_child(_label(_text("duration"), 12, MUTED))
		if _saved_available:
			var continue_button := _button("continue", func() -> void: continue_requested.emit())
			continue_button.name = "ContinueSaved"
			column.add_child(continue_button)
		primary = _button("begin", func() -> void: start_requested.emit())
		primary.name = "BeginJourney"
		column.add_child(primary)
		if _save_invalid: column.add_child(_label(_text("save_invalid"),12,AMBER))
		column.add_child(_label(("Touch controls · landscape · Crawl for observation" if _config.locale == "en" else "橫向遊玩 · 觸控駕駛 · 慢行觀察") if _mobile else _text("controls"), 12, MUTED))
		_build_settings(column)
		column.add_child(_label(_text("headphones"), 12, MUTED))
	elif _state == "paused":
		column.add_child(_label(_text("paused"), 24 if _mobile else 28))
		var actions: Container = column
		if _mobile:
			var grid := GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 8)
			grid.add_theme_constant_override("v_separation", 8)
			column.add_child(grid)
			actions = grid
		primary = _button("resume", func() -> void: resume_requested.emit())
		actions.add_child(primary)
		actions.add_child(_button("journal", func() -> void: show_state("journal")))
		actions.add_child(_button("open_settings", func() -> void: show_state("settings")))
		actions.add_child(_button("back_home", func() -> void: menu_requested.emit()))
		actions.add_child(_button("restart", func() -> void: show_state("confirm_reset")))
		if _mobile:
			for button in actions.get_children(): button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var author := _label(_text("author_contact"), 12 if _mobile else 15, PAPER)
		author.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(author)
		var email := LinkButton.new()
		email.text = "TWK0672005@gmail.com"
		email.uri = "mailto:TWK0672005@gmail.com"
		email.custom_minimum_size.y = 32 if _mobile else 36
		email.focus_mode = Control.FOCUS_ALL
		column.add_child(email)
		column.add_child(_label(("Touch controls · landscape · Crawl for observation" if _config.locale == "en" else "橫向遊玩 · 觸控駕駛 · 慢行觀察") if _mobile else _text("controls"), 12 if _mobile else 16, PAPER))
	elif _state == "settings":
		column.add_child(_label(_text("settings_title"), 24 if _mobile else 28))
		_build_settings(column)
		primary = _button("back_to_pause", func() -> void: show_state("paused"))
		column.add_child(primary)
	elif _state == "journal":
		column.add_child(_label(_text("journal_title"), 28))
		var brief := _label(_text("journal_brief"), 16, MUTED)
		brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(brief)
		_build_journal_entries(column)
		primary = _button("resume", func() -> void: resume_requested.emit())
		column.add_child(primary)
		column.add_child(_label(_text("journal_back"), 12, MUTED))
	elif _state == "confirm_new":
		var heading := _label(_text("ready_title"), 26 if _mobile else 36)
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(heading)
		var invitation := _label(_text("ready_detail"), 16, PAPER)
		invitation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if not _mobile: column.add_child(invitation)
		else: invitation.free()
		var notice := _label(_text("fresh_notice"), 13, MUTED)
		notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(notice)
		if _saved_contact_completed:
			var contact_notice := _label(_text("saved_contact_notice"), 13, SIGNAL)
			contact_notice.name = "SavedFirstContactNotice"
			contact_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			column.add_child(contact_notice)
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 10)
		column.add_child(actions)
		var depart := _button("begin", func() -> void: reset_requested.emit())
		depart.name = "BeginJourney"
		depart.custom_minimum_size.y = 50
		depart.add_theme_stylebox_override("normal", _style(PAPER, PAPER))
		depart.add_theme_stylebox_override("hover", _style(Color.WHITE, SIGNAL))
		for state in ["font_color", "font_hover_color", "font_focus_color"]:
			depart.add_theme_color_override(state, Color("152c29"))
		depart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(depart)
		primary = _button("back_home", _cancel_new)
		primary.name = "BackHome"
		primary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(primary)
	elif _state == "confirm_reset":
		column.add_child(_label(_text("confirm_reset"), 25))
		var reset_description := _label(_text("reset_detail"), 14, MUTED)
		reset_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(reset_description)
		primary = _button("cancel", func() -> void: resume_requested.emit())
		column.add_child(primary)
		column.add_child(_button("confirm", func() -> void: reset_requested.emit()))
	if is_instance_valid(primary):
		primary.call_deferred("grab_focus")

func _build_settings(parent: VBoxContainer) -> void:
	var detail_notice := _label(_text("desktop_detail"), 12 if _mobile else 15, PAPER)
	detail_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(detail_notice)
	var preferences := parent
	var option_parent: Container = parent
	if _mobile and _state == "settings":
		var sections := HBoxContainer.new()
		sections.add_theme_constant_override("separation", 24)
		parent.add_child(sections)
		preferences = VBoxContainer.new()
		preferences.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preferences.add_theme_constant_override("separation", 12)
		sections.add_child(preferences)
		option_parent = sections
	var language := HBoxContainer.new()
	language.add_theme_constant_override("separation", 10)
	preferences.add_child(language)
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
	preferences.add_child(sound_row)
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
	var options := VBoxContainer.new()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_parent.add_child(options)
	for pair in [["reduced_motion", "motion"], ["low_quality", "quality"]]:
		var check := CheckButton.new()
		check.text = _text(pair[1])
		check.add_theme_font_size_override("font_size", 14)
		check.button_pressed = bool(_config[pair[0]])
		check.toggled.connect(_toggle_setting.bind(pair[0]))
		options.add_child(check)

func _build_journal_entries(parent: VBoxContainer) -> void:
	var observed: Dictionary = _journal_context.get("observedEcology", {})
	var landmarks: Dictionary = _journal_context.get("landmarks", {})
	var visited: Dictionary = _journal_context.get("visited", {})
	var entries := 0
	for region in ["aurora_shelf", "ember_rift", "veil_marsh", "pale_decay"]:
		if visited.get(region, false):
			parent.add_child(_label(_text(region), 17, SIGNAL))
			entries += 1
	for species in ["veyra", "aeral", "root_choir"]:
		if not observed.get(species, false): continue
		parent.add_child(_label(_text("species_" + species), 17))
		var detail := _label(_text("observed_" + species), 14, MUTED)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(detail)
		entries += 1
	for id in landmarks:
		if not landmarks[id]: continue
		parent.add_child(_label(_text("landmark_" + id), 17))
		var detail := _label(_text("observed_" + id), 14, MUTED)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(detail)
		entries += 1
	if entries == 0: parent.add_child(_label(_text("journal_empty"), 15, MUTED))

func _change_locale(value: String) -> void:
	DisplayServer.window_set_title(Brand.text("title", value))
	_config.locale = value
	_save_settings()
	locale_changed.emit(value)
	_build()

func _toggle_setting(value: bool, key: String) -> void:
	_config[key] = value
	if key == "whispers" and not value:
		_guidance.clear()
		_whisper_chime.stop()
		_refresh_whisper()
	_save_settings()

func set_write_failed(value: bool) -> void:
	if _write_failed==value: return
	_write_failed=value
	if is_instance_valid(_root) and _state in ["menu","paused","confirm_reset","confirm_new","ending"]: _build()

func set_clear_failed(value: bool) -> void:
	if _clear_failed==value: return
	_clear_failed=value
	if is_instance_valid(_root): _build()

func set_saved_available(value: bool, failed: bool = false) -> void:
	_saved_available = value
	_save_invalid = failed
	if _state == "menu" and is_instance_valid(_root): _build()

func set_saved_contact_completed(value: bool) -> void:
	_saved_contact_completed = value

func show_state(state: String) -> void:
	if not state in ["menu", "exploring", "paused", "settings", "journal", "confirm_reset", "confirm_new"]:
		return
	_state = state
	if state != "exploring" and is_instance_valid(_whisper_chime): _whisper_chime.stop()
	if is_instance_valid(_root):
		_build()

func set_journal_context(data: Dictionary) -> void:
	var changed := data != _journal_context
	_journal_context = data.duplicate(true)
	if changed and _state == "journal" and is_instance_valid(_root): _build()

func set_map_road(points: PackedVector2Array) -> void:
	_map_road = points
	if is_instance_valid(_minimap): _minimap.set_road(points)

func set_navigation(point: Vector2, heading: float, target: Vector2, has_target: bool) -> void:
	_map_context = {"position": point, "heading": heading, "target": target, "has_target": has_target}
	if is_instance_valid(_minimap): _minimap.set_navigation(point, heading, target, has_target)

func update_readout(distance: float, elapsed: float, contact_progress: float, can_interact: bool, speed_mps: float = 0.0, max_speed_mps: float = 8.0, view_mode: String = "first_person", ecology_state: Dictionary = {}) -> void:
	_speed_mps = speed_mps
	_max_speed_mps = max_speed_mps
	_view_mode = view_mode
	_ecology_readout = ecology_state.duplicate()
	_distance = maxf(distance, 0.0)
	_elapsed = maxf(elapsed, 0.0)
	_can_interact = can_interact
	if not is_instance_valid(_distance_label):
		return
	_speed_label.text = "%s  %.1f m/s  ·  %d km/h%s" % [_text("speed_label"), absf(speed_mps), roundi(absf(speed_mps)*3.6), "  R" if speed_mps < -0.05 else ""]
	var crawling := Input.is_action_pressed("drive_crawl") or (Input.get_action_strength("drive_forward") > 0.0 and Input.get_action_strength("drive_forward") < 0.9)
	var boosting: bool = Input.is_action_pressed("drive_boost") and Input.get_axis("drive_reverse", "drive_forward") > 0.9 and not crawling and not Input.is_action_pressed("brake") and _state == "exploring"
	if boosting: _speed_label.text += "  ·  " + ("BOOST" if _config.locale == "en" else "加速")
	elif crawling and not Input.is_action_pressed("brake"): _speed_label.text += "  ·  " + _text("crawl_hint")
	_speed_label.modulate = Color(0.65, 0.93, 1.0) if boosting else Color.WHITE
	_speed_bar.value = clampf(absf(speed_mps) / maxf(max_speed_mps, 0.1), 0.0, 1.0)
	_view_label.text = "%s  %s%s" % [_text("view_label"), _text("first_person_label" if view_mode == "first_person" else "third_person_label"), "" if _mobile else "  [V]"]
	_interaction.visible = _can_interact and _state == "exploring" and not _mobile
	_reticle.text = "+" if _can_interact else "·"
	_reticle.modulate = SIGNAL if _can_interact else Color(1, 1, 1, 0.35)
	_reticle.visible = _state == "exploring"
	_render_interaction_context()

func set_activity_progress(done: int, optional_done: int, field_done: int, region: String, target: String = "", distance: float = 0.0, quiet: float = 0.0, bearing: float = 0.0) -> void:
	_activity_context={"done":done,"optional":optional_done,"field":field_done,"region":region,"target":target,"distance":distance,"quiet":quiet,"bearing":bearing}
	if is_instance_valid(_region_label): _region_label.text = _region_title(region)
	_render_activity_context()

func _region_title(region: String) -> String:
	var index := ["aurora_shelf", "ember_rift", "veil_marsh", "pale_decay"].find(region)
	return ("%02d  /  " % (index + 1) if index >= 0 else "") + _text(region)

func _render_activity_context() -> void:
	if not is_instance_valid(_activity_label): return
	_region_label.text = _text(str(_activity_context.get("region", "aurora_shelf")))
	_distance_label.visible = false
	_navigation_label.visible = false
	_activity_label.visible = false

func set_interaction_context(data: Dictionary) -> void:
	_interaction_context = data.duplicate()
	_render_interaction_context()

func _render_interaction_context() -> void:
	if not is_instance_valid(_ecology_label): return
	var data := _interaction_context
	var kind := str(data.get("kind", "none"))
	var subject := str(data.get("subject", ""))
	var eligible := bool(data.get("eligible", false)) and _state == "exploring"
	var subject_name := _text(("species_" if kind == "ecology" else "landmark_") + subject)
	var action := ("Observe " if _config.locale == "en" else "觀察") + subject_name
	_interaction.text = ("E · " if not _mobile else "") + action
	_interaction.visible = eligible and not _mobile
	_interaction.disabled = not eligible
	_ecology_label.text = action
	_ecology_label.visible = eligible and _mobile
	_reticle.text = "+" if eligible else "·"
	_reticle.modulate = SIGNAL if eligible else Color(1, 1, 1, 0.35)
	_refresh_feedback_visibility()

func _refresh_feedback_visibility() -> void:
	if is_instance_valid(_feedback_panel):
		_feedback_panel.visible = _message.visible or _ecology_label.visible or _interaction.visible

func set_message(key: String) -> void:
	_message_key = key
	if key in ["survey_guidance", "field_guidance", "survey_all"]: return
	var importance := 100 if key in ["save_write_failed", "save_clear_failed"] else 90
	_offer_whisper(key, _text(key), importance, 7.0, 8.0, true)

func reset_guidance() -> void:
	_interaction_kind = ""
	_interaction_context.clear()
	_guidance.reset()
	_refresh_whisper()

func tick_guidance(delta: float) -> void:
	if _state != "exploring": return
	_guidance.advance(delta)
	_refresh_whisper()

func _offer_whisper(key: String, text: String, importance: int, duration: float, cooldown: float, refresh: bool = false) -> void:
	if not bool(_config.get("whispers", true)) and importance < 80: return
	var is_new: bool = _guidance.offer(key, text, importance, duration, cooldown, refresh)
	if is_new and importance < 50 and _state == "exploring" and float(_config.volume) > 0.0:
		_whisper_chime.volume_db = linear_to_db(float(_config.volume) * 0.08)
		_whisper_chime.play()
	_refresh_whisper()

func _refresh_whisper() -> void:
	if not is_instance_valid(_message): return
	_message.text = _guidance.message
	_message.visible = not _guidance.key.is_empty()
	_message.modulate.a = 1.0 if bool(_config.reduced_motion) else clampf((_guidance.expires - _guidance.clock) / 1.2, 0.0, 1.0)
	_refresh_feedback_visibility()

func set_view_message(view_mode: String) -> void:
	_view_mode = view_mode
	if is_instance_valid(_view_label):
		_view_label.text = "%s  %s%s" % [_text("view_label"), _text("first_person_label" if view_mode == "first_person" else "third_person_label"), "" if _mobile else "  [V]"]
