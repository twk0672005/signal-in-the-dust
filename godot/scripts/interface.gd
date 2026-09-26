extends CanvasLayer
const ShowcaseMinimap = preload("res://scripts/showcase_minimap.gd")
const ShowcaseWhispers = preload("res://scripts/showcase_whispers.gd")
## Bilingual expedition HUD. Every gameplay mutation is delegated through signals.
signal continue_saved_requested
signal start_requested
signal resume_requested
signal reset_requested
signal interact_requested
signal encounter_selected(region: String)
signal locale_changed(value: String)
signal settings_changed(config: Dictionary)
signal menu_requested
signal explore_requested

const PAPER := Color("eee8dc")
const MUTED := Color("b1aa9c")
const AMBER := Color("d5a56d")
const SIGNAL := Color("83c8c5")
const FONT_PATH := "res://assets/fonts/SignalSansTC.otf"
const COPY := {
	"study_title": ["WETLAND · BEFORE / AFTER", "濕地 · 反應對照"],
	"study_prepare": ["Activate the sampler at the reed field station.", "先在膜葉場記點啟動採樣器。"],
	"study_alarm": ["Approach Aeral with throttle, then brake and press E to record its alarm.", "加速接近 Aeral，煞車後按 E 記錄受驚反應。"],
	"study_quiet": ["Stay quiet until the flock settles. Press E to record recovery.", "保持安靜，待群體平復後按 E 記錄恢復反應。"],
	"study_return": ["Both responses recorded. Validate at the wetland basin field station.", "兩種反應已記錄，前往濕地盆地場記點驗證。"],
	"study_complete": ["The wetland canopy opens around the living pool.", "濕地植被在活水窪四周展開。"],
	"study_startled": ["Alarm response recorded. Let the flock recover naturally.", "已記錄受驚反應，讓群體自然恢復。"],
	"study_recovered": ["Recovery recorded. Return to the basin sampler.", "已記錄恢復反應，返回盆地採樣器。"],
	"site_study_aeral": ["Aeral reaction study", "Aeral 反應對照"],
	"thermal_title": ["MINERAL TRAILS", "礦脈路線"],
	"thermal_hint": ["Accompany Veyra to warmth, or study the eastern vent for a cool route.", "陪 Veyra 前往暖床，或研究東側熱泉，探索冷礦脈路線。"],
	"thermal_watch": ["Watch the plume. E reads the bright eruption.", "觀察噴流，亮起時按 E 讀取。"],
	"thermal_read": ["Cool minerals found. E switches the route before escort starts.", "發現冷礦脈，護送開始前可按 E 切換路線。"],
	"thermal_warm": ["Warm shelter selected. Accompany Veyra when ready.", "已選暖床路線，準備好便回去陪伴 Veyra。"],
	"thermal_cool": ["Cool mineral trail selected. Return to Veyra.", "已選冷礦脈路線，回到 Veyra 身邊。"],
	"thermal_locked": ["The herd follows your chosen route until arrival.", "群體會沿你選定的路線前往棲地。"],
	"thermal_distance": ["Eastern vent · %d m", "東側熱泉 · %d 米"],
	"thermal_observe_action": ["E · READ VENT ERUPTION", "E · 讀取熱泉噴發"],
	"thermal_route_action": ["E · SWITCH MINERAL TRAIL", "E · 切換礦脈路線"],
	"escort_idle_cool": ["E · Accompany Veyra along the cool mineral trail.", "E · 陪 Veyra 沿冷礦脈前進。"],
	"escort_complete_cool": ["The cool basin glows. The herd gathers at the mineral bed.", "冷礦盆地亮起，群體聚集在新礦床。"],
	"save_clear_failed": ["The saved expedition could not be cleared. Your previous checkpoint is still available; try again when browser storage is writable.", "未能清除已儲存的探勘。舊進度仍然保留，請在瀏覽器可寫入儲存空間後再試。"],
	"save_write_failed": ["Progress could not be saved. You can keep playing; Continue may use an older checkpoint.", "未能儲存進度。仍可繼續遊玩，但續玩可能回到較早的進度。"],
	"root_title": ["ROOT CHOIR · %d / 3 CONNECTED", "根脈合唱 · 已接通 %d / 3"],
	"root_hint": ["Follow the living conduit. E turns a junction toward the next shell.", "沿活根前進，E 轉動節點，導向下一座殼礁。"],
	"root_changed": ["Trace the lit root. Dark downstream roots need another direction.", "追蹤發光根脈，下游熄暗時需要調整方向。"],
	"root_ready": ["All junctions carry the signal. Reach the root crown and press E.", "所有節點已接通，前往根冠並按 E 發送。"],
	"root_complete": ["The root crown unfolds. Morrow answer across the basin.", "根冠展開，孢殼生物隔著盆地回應。"],
	"root_port": ["Junction %d · Direction %d / 3", "節點 %d · 方向 %d / 3"],
	"root_distance": ["Next junction / crown · %d m", "下一節點／根冠 · %d 米"],
	"root_turn": ["E · TURN ROOT JUNCTION", "E · 轉動根脈節點"],
	"root_pulse": ["E · AWAKEN ROOT CROWN", "E · 喚醒根冠"],
	"passage_title": ["AERAL · VEIL PASSAGE · %d / 5", "霧翼群 · 膜葉穿行 · %d / 5"],
	"passage_idle": ["Find the first lit membrane. Stop and press E.", "前往第一組發光膜葉，停車後按 E。"],
	"passage_crossing": ["Pass the lit opening below 5.5 m/s. Follow its glow.", "以低於 5.5 米／秒穿過發光入口，沿光前進。"],
	"passage_scattered": ["The flock scattered. Back away 8 m, then return quietly.", "霧翼群受驚散開，退到 8 米外再慢速返回。"],
	"passage_gate": ["The membrane opens. Follow the next glow.", "膜葉展開，前往下一處光芒。"],
	"passage_complete": ["The passage blooms. Aeral descend into the shelter.", "膜葉通道綻放，霧翼群降回庇護處。"],
	"passage_distance": ["Next opening · %d m", "下一入口 · %d 米"],
	"passage_action": ["E · ENTER VEIL PASSAGE", "E · 開始膜葉穿行"],
	"escort_title": ["VEYRA · QUIET CROSSING", "礦脈生物 · 安靜穿越"],
	"escort_idle": ["E · Accompany Veyra to the warm shelter.", "E · 陪伴 Veyra 前往溫暖庇護處。"],
	"escort_travelling": ["Keep 4–24 m away and drive below 8 m/s.", "保持 4–24 米距離，車速低於 8 米／秒。"],
	"escort_alarmed": ["Too loud or too close. Stop and give it space.", "太吵或太近了，停車並留出空間。"],
	"escort_waiting": ["Veyra is waiting. Return within 24 m.", "Veyra 正在等你，回到牠的 24 米範圍內。"],
	"escort_complete": ["Veyra reached shelter. The mineral bed warms.", "Veyra 抵達庇護處，礦床亮起暖光。"],
	"escort_distance": ["Companion distance · %d m", "同行距離 · %d 米"],
	"escort_action": ["E · ACCOMPANY VEYRA", "E · 陪伴 VEYRA"],
	"resonance_title": ["CRYSTAL RESONANCE · %d / 3", "冰晶共鳴 · %d / 3"],
	"resonance_idle": ["E · Hear the crystals. Reply with 1 / 2 / 3.", "E · 聆聽冰晶，以 1／2／3 回應。"],
	"resonance_listening": ["Listen and watch the numbered crystals.", "留意音高及冰晶上的數字順序。"],
	"resonance_answer": ["Your reply · 1 / 2 / 3 · %d / %d", "輪到你回應 · 1／2／3 · %d / %d"],
	"resonance_solved": ["The grove unfolds. Your rhythm is remembered.", "晶簇展開，記住了你的節奏。"],
	"resonance_retry": ["Different rhythm. Listen again; E replays.", "節奏不同，再聆聽一次；E 可重播。"],
	"resonance_band": ["Tone %d", "音階 %d"],
	"resonance_action": ["E · LISTEN / REPLAY", "E · 聆聽／重播"],
	"resonance_leave": ["Leaving the grove restarts this challenge.", "離開晶簇會重新開始這項挑戰。"],
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
	"site_encounter_aurora_shelf": ["Crystal resonance", "冰晶共鳴"],
	"site_encounter_ember_rift": ["Veyra escort", "護送 Veyra"],
	"site_encounter_veil_marsh": ["Veil passage", "膜葉穿行"],
	"site_encounter_pale_decay": ["Root routing", "根脈導流"],
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
	"controls": ["WASD / arrows   Drive     SHIFT   Boost     SPACE   Brake\nRight-drag   Look     V   Camera     E   Observe / transmit\nJ   Journal     ESC   Pause", "WASD / 方向鍵   駕駛     SHIFT   加速     空白鍵   煞車\n按住滑鼠右鍵拖曳   環顧     V   視角     E   觀察／發送\nJ   日誌     ESC   暫停"],
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
	"journal": ["Expedition journal", "探勘日誌"],
	"journal_title": ["4 ECOLOGICAL ENCOUNTERS", "4 項生態邂逅"],
	"journal_brief": ["Optional encounters are separate from regional surveys. Track one when you want to seek it out.", "生態邂逅屬於區域測繪之外的支線，想前往時可選擇追蹤。"],
	"journal_unknown": ["UNKNOWN", "未知"],
	"journal_available": ["AVAILABLE", "可探索"],
	"journal_complete": ["COMPLETE", "已完成"],
	"journal_track": ["TRACK", "追蹤"],
	"journal_tracking": ["TRACKING", "追蹤中"],
	"journal_track_surveys": ["CLEAR GUIDE MARKER", "清除引導標記"],
	"journal_back": ["ESC · BACK TO EXPEDITION", "ESC · 返回探勘"],
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
	"pause_hint": ["ESC  Pause · J  Journal", "ESC  暫停 · J  日誌"],
	"muted": ["Muted", "靜音"],
	"keep_exploring": ["Keep exploring", "繼續探索"],
	"author_contact": ["Suggestions or collaboration · Contact the author", "有建議／合作，歡迎聯絡作者"],
	"desktop_detail": ["Desktop offers richer visual detail. Low detail keeps mobile play lighter.", "電腦版可呈現更豐富的畫面細節；手機可選低畫質。"],
	"whispers": ["Explorer whispers", "探索悄悄話"],
	"settings_title": ["Expedition settings", "探索設定"],
	"open_settings": ["Settings", "設定"],
	"back_to_pause": ["Back", "返回暫停選單"],
	"whisper_aurora_shelf": ["Take your time. Hold W to drive; the pale ridge opens ahead.", "慢慢來。按住 W 前進，沿著眼前的淺色岩脊探索。"],
	"whisper_ember_rift": ["Warmth gathers in these cracks. Quiet movement brings life closer.", "暖意聚在岩縫之間。安靜靠近，你會看見更多生命。"],
	"whisper_veil_marsh": ["Look above the water. The membranes are catching the light.", "看看水面上方，薄膜正接住遠處的微光。"],
	"whisper_pale_decay": ["Even fallen roots shelter life. Watch the folds near the ground.", "倒下的根仍庇護著生命，留意貼地的細褶。"],
	"whisper_disturbed": ["A little more space. Stop and let them settle.", "留多一點空間，停低讓牠們安定下來。"],
	"whisper_aeral": ["An Aeral is close. Slow down and watch its wings.", "附近有 Aeral。慢下來，看看牠的翼。"],
	"whisper_veyra": ["Veyra are feeding nearby. Give their heavy feet room.", "Veyra 正在附近覓食，給牠們的步伐留點空間。"],
	"whisper_morrow": ["A shell is opening. Something quiet is happening below it.", "殼正在展開，下面有細小而安靜的變化。"],
}

var _config: Dictionary = {"locale": "en", "volume": 0.65, "reduced_motion": false, "low_quality": false, "whispers": true}
var _mobile := false
var _state := "menu"
var _saved_available := false
var _save_invalid := false
var _clear_failed := false
var _write_failed := false
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
var _resonance_context: Dictionary = {}
var _wetland_context: Dictionary = {}
var _thermal_context: Dictionary = {}
var _root_network_context: Dictionary = {}
var _passage_context: Dictionary = {}
var _escort_context: Dictionary = {}
var _journal_context: Dictionary = {"entries": {}, "tracked": ""}
var _reticle: Label
var _interaction: Button
var _message: Label
var _contact_bar: ProgressBar
var _message_key := ""
var _distance := 0.0
var _elapsed := 0.0
var _progress := 0.0
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
	_build()

func _exit_tree() -> void:
	if is_instance_valid(_whisper_chime):
		_whisper_chime.stop()
		_whisper_chime.stream = null

func _text(key: String) -> String:
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
	top.offset_left = 16 if _mobile else 36
	top.offset_top = 12 if _mobile else 28
	top.offset_right = -16 if _mobile else -36
	_hud.add_child(top)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(left)
	_region_label = _label("", 13, SIGNAL)
	left.add_child(_region_label)
	_distance_label = _label("", 25)
	left.add_child(_distance_label)
	_distance_label.visible = false
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
	_activity_label.custom_minimum_size.x=310 if _mobile else 340
	_activity_label.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	_activity_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_activity_label)
	_activity_label.visible = false
	var right := VBoxContainer.new()
	top.add_child(right)
	if _mobile:
		var touch_space := Control.new()
		touch_space.custom_minimum_size.y = 42
		right.add_child(touch_space)
	_minimap = ShowcaseMinimap.new()
	_minimap.name = "ExplorerMinimap"
	_minimap.custom_minimum_size = Vector2(118, 118) if _mobile else Vector2(168, 168)
	_minimap.set_road(_map_road)
	right.add_child(_minimap)
	var hint := _label(_text("pause_hint"), 12, MUTED)
	hint.visible = not _mobile
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(hint)
	_view_label = _label("", 12, AMBER)
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
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.offset_left = -320
	bottom.offset_right = 320
	bottom.offset_top = -125 if _mobile else -132
	bottom.offset_bottom = -76 if _mobile else -40
	bottom.add_theme_constant_override("separation", 8)
	_hud.add_child(bottom)
	_message = _label(_guidance.message, 14 if _mobile else 17)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.visible = not _guidance.key.is_empty()
	bottom.add_child(_message)
	_ecology_label = _label("", 12, MUTED)
	_ecology_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_ecology_label)
	_ecology_label.visible = false
	_interaction = _button("transmit", func() -> void: interact_requested.emit())
	_interaction.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_interaction.custom_minimum_size.x = 260
	_interaction.visible = not _mobile
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
	panel.offset_left = 20 if _mobile else 64
	panel.offset_right = 490 if _mobile else 534
	if _mobile and _state == "settings":
		panel.offset_right = minf(780.0, get_viewport().get_visible_rect().size.x - 20.0)
	var desired_panel_height := 720.0 if _state in ["menu", "settings"] else (640.0 if _state == "journal" else 560.0)
	var panel_height := minf(desired_panel_height, maxf(320.0, get_viewport().get_visible_rect().size.y - 48.0))
	panel.offset_top = -panel_height * 0.5
	panel.offset_bottom = panel_height * 0.5
	panel.add_theme_stylebox_override("panel", _style(Color(0.055, 0.063, 0.064, 0.88), Color(0.55, 0.48, 0.36, 0.30), 20 if _mobile else 26))
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
		column.add_child(_label(_text("edition"), 12, AMBER))
	if _clear_failed or _write_failed:
		var warning:=_label(_text("save_clear_failed" if _clear_failed else "save_write_failed"),13,AMBER)
		warning.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		column.add_child(warning)
	var primary: Button
	if _state == "menu":
		column.add_child(_label(_text("title"), 26 if _mobile else 38))
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
		var brief := _label(_text("journal_brief"), 13, MUTED)
		brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(brief)
		_build_journal_entries(column)
		var surveys := _button("journal_track_surveys", _select_journal_encounter.bind(""))
		surveys.name = "JournalTrackSurveys"
		column.add_child(surveys)
		primary = _button("resume", func() -> void: resume_requested.emit())
		column.add_child(primary)
		column.add_child(_label(_text("journal_back"), 12, MUTED))
	elif _state == "confirm_new":
		column.add_child(_label(_text("confirm_reset"),25))
		column.add_child(_label(_text("reset_detail"),14,MUTED))
		primary = _button("cancel", _cancel_new)
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
		primary = _button("keep_exploring", func() -> void: explore_requested.emit())
		column.add_child(primary)
		column.add_child(_label("%02d:%02d" % [int(_elapsed) / 60, int(_elapsed) % 60], 12, MUTED))
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
	for pair in [["reduced_motion", "motion"], ["low_quality", "quality"], ["whispers", "whispers"]]:
		var check := CheckButton.new()
		check.text = _text(pair[1])
		check.add_theme_font_size_override("font_size", 14)
		check.button_pressed = bool(_config[pair[0]])
		check.toggled.connect(_toggle_setting.bind(pair[0]))
		options.add_child(check)

func _build_journal_entries(parent: VBoxContainer) -> void:
	var entries: Dictionary = _journal_context.get("entries", {})
	var tracked := str(_journal_context.get("tracked", ""))
	for region in ["aurora_shelf", "ember_rift", "veil_marsh", "pale_decay"]:
		var entry: Dictionary = entries.get(region, {})
		var discovered := bool(entry.get("discovered", false))
		var complete := bool(entry.get("complete", false))
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", _style(Color(0.10, 0.11, 0.105, 0.78), Color(0.42, 0.39, 0.33, 0.55), 12))
		parent.add_child(row)
		var content := HBoxContainer.new()
		content.add_theme_constant_override("separation", 12)
		row.add_child(content)
		var names := VBoxContainer.new()
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(names)
		names.add_child(_label(_text(region), 15, PAPER if discovered else MUTED))
		names.add_child(_label(_text("site_encounter_" + region) if discovered else "—", 12, MUTED))
		var status_key := "journal_complete" if complete else ("journal_available" if discovered else "journal_unknown")
		var status := _label(_text(status_key), 11, SIGNAL if complete else (AMBER if discovered else MUTED))
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		content.add_child(status)
		if discovered and not complete:
			var track := _button("journal_tracking" if tracked == region else "journal_track", _select_journal_encounter.bind(region))
			track.name = "JournalTrack_" + region
			track.custom_minimum_size = Vector2(104, 38)
			content.add_child(track)

func _select_journal_encounter(region: String) -> void:
	encounter_selected.emit(region)

func _change_locale(value: String) -> void:
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

func show_state(state: String) -> void:
	if not state in ["menu", "arrival", "exploring", "contact", "ending", "paused", "settings", "journal", "confirm_reset", "confirm_new"]:
		return
	_state = state
	if state not in ["exploring", "contact"] and is_instance_valid(_whisper_chime): _whisper_chime.stop()
	if is_instance_valid(_root):
		_build()

func set_journal_context(data: Dictionary) -> void:
	_journal_context = data.duplicate(true)

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
	_progress = clampf(contact_progress, 0.0, 1.0)
	_can_interact = can_interact
	if not is_instance_valid(_distance_label):
		return
	_distance_label.text = "%03d m" % roundi(_distance)
	_speed_label.text = "%s  %.1f m/s  ·  %d km/h%s" % [_text("speed_label"), absf(speed_mps), roundi(absf(speed_mps)*3.6), "  R" if speed_mps < -0.05 else ""]
	var boosting: bool = Input.is_action_pressed("drive_boost") and Input.get_axis("drive_reverse", "drive_forward") > 0.1 and not Input.is_action_pressed("brake") and _state == "exploring"
	if boosting: _speed_label.text += "  ·  " + ("BOOST" if _config.locale == "en" else "加速")
	_speed_label.modulate = Color(0.65, 0.93, 1.0) if boosting else Color.WHITE
	_speed_bar.value = clampf(absf(speed_mps) / maxf(max_speed_mps, 0.1), 0.0, 1.0)
	_view_label.text = "%s  %s%s" % [_text("view_label"), _text("first_person_label" if view_mode == "first_person" else "third_person_label"), "" if _mobile else "  [V]"]
	if not ecology_state.is_empty():
		var active := []
		for key in ["veyra", "aeral", "rootChoir"]:
			if ecology_state.get(key, "quiet") != "quiet":
				var value: String=str(ecology_state[key])
				active.append(_text("ecology_"+value) if value in ["near","disturbed"] else value)
		_ecology_label.text = " · ".join(active)
	else: _ecology_label.text = ""
	_interaction.visible = _can_interact and _state == "exploring" and not _mobile
	_reticle.text = "+" if _can_interact else "·"
	_reticle.modulate = SIGNAL if _can_interact else Color(1, 1, 1, 0.35)
	_reticle.visible = _state == "exploring"
	_contact_bar.visible = _state == "contact"
	_contact_bar.value = _progress

func set_activity_progress(done: int, optional_done: int, field_done: int, region: String, target: String = "", distance: float = 0.0, quiet: float = 0.0, bearing: float = 0.0) -> void:
	_activity_context={"done":done,"optional":optional_done,"field":field_done,"region":region,"target":target,"distance":distance,"quiet":quiet,"bearing":bearing}
	if is_instance_valid(_region_label): _region_label.text = _text(region)
	_render_activity_context()

func _render_activity_context() -> void:
	# Focus on the currently actionable encounter, never concatenate the task inventory.
	if is_instance_valid(_activity_label): _activity_label.text = ""
	if is_instance_valid(_region_label) and not _activity_context.is_empty():
		_region_label.text = _text(str(_activity_context.region))
	if _state != "exploring": return
	var key := ""
	var text := ""
	var importance := 80
	var refresh := true
	if not _resonance_context.is_empty() and _resonance_context.phase in ["listening", "answer"]:
		var r := _resonance_context
		key = "resonance_" + str(r.phase)
		text = _text(key) % [r.matched, r.length] if r.phase == "answer" else _text(key)
		key += ":" + str(r.round_index)
	elif not _escort_context.is_empty() and _escort_context.phase in ["travelling", "alarmed", "waiting"]:
		key = "escort_" + str(_escort_context.phase)
		text = _text(key)
	elif not _passage_context.is_empty() and _passage_context.phase in ["crossing", "scattered"]:
		key = "passage_" + str(_passage_context.phase)
		text = _text(key)
	elif not _root_network_context.is_empty() and not _root_network_context.complete and int(_root_network_context.near) >= 0:
		var r := _root_network_context
		key = "root_port:" + str(r.near)
		text = _text("root_port") % [r.near + 1, r.ports[r.near] + 1]
	elif not _thermal_context.is_empty() and not _thermal_context.locked and _thermal_context.get("near", false):
		key = "thermal_watch" if not _thermal_context.vent_observed else "thermal_" + str(_thermal_context.route)
		text = _text(key)
		importance = 35
		refresh = false
	elif not _wetland_context.is_empty() and _wetland_context.phase in ["alarm", "quiet", "return"]:
		key = "study_" + str(_wetland_context.phase)
		text = _text(key)
		importance = 35
		refresh = false
	if not key.is_empty(): _offer_whisper(key, text, importance, 6.0, 12.0, refresh)

func set_resonance_context(data: Dictionary) -> void:
	_resonance_context=data
	_render_activity_context()

func set_wetland_context(data: Dictionary) -> void:
	_wetland_context=data
	_render_activity_context()

func set_thermal_context(data: Dictionary) -> void:
	_thermal_context=data
	_render_activity_context()

func set_root_network_context(data: Dictionary) -> void:
	_root_network_context=data
	_render_activity_context()

func set_passage_context(data: Dictionary) -> void:
	_passage_context=data
	_render_activity_context()

func set_escort_context(data: Dictionary) -> void:
	_escort_context=data
	_render_activity_context()

func set_interaction_kind(kind: String) -> void:
	if not is_instance_valid(_interaction): return
	_interaction.text=_text("thermal_observe_action" if kind=="thermal_observe" else "thermal_route_action" if kind=="thermal_route" else "root_turn" if kind.begins_with("root_relay:") else "root_pulse" if kind=="root_pulse" else "passage_action" if kind=="passage" else "escort_action" if kind=="escort" else "resonance_action" if kind=="resonance" else "survey_action" if kind.begins_with("survey:") else ("observe_action" if kind=="ecology" else "transmit"))


func set_message(key: String) -> void:
	_message_key = key
	if key in ["survey_guidance", "field_guidance", "survey_all"]: return
	var importance := 100 if key in ["save_write_failed", "save_clear_failed"] else 50
	_offer_whisper(key, _text(key), importance, 7.0, 8.0)

func reset_guidance() -> void:
	_guidance.reset()
	_refresh_whisper()

func tick_guidance(delta: float) -> void:
	if _state not in ["exploring", "contact"]: return
	_guidance.advance(delta)
	_refresh_whisper()

func suggest_guidance(region: String, ecology: Dictionary) -> void:
	if _state != "exploring": return
	if "disturbed" in ecology.values():
		_offer_whisper("whisper_disturbed", _text("whisper_disturbed"), 60, 6.0, 25.0)
	elif ecology.get("aeral", "quiet") == "near":
		_offer_whisper("whisper_aeral", _text("whisper_aeral"), 25, 6.0, 100.0)
	elif ecology.get("veyra", "quiet") == "near":
		_offer_whisper("whisper_veyra", _text("whisper_veyra"), 25, 6.0, 100.0)
	elif ecology.get("rootChoir", "quiet") == "near":
		_offer_whisper("whisper_morrow", _text("whisper_morrow"), 25, 6.0, 100.0)
	_offer_whisper("whisper_" + region, _text("whisper_" + region), 20, 7.0, 240.0)

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

func set_view_message(view_mode: String) -> void:
	_view_mode = view_mode
	if is_instance_valid(_view_label):
		_view_label.text = "%s  %s%s" % [_text("view_label"), _text("first_person_label" if view_mode == "first_person" else "third_person_label"), "" if _mobile else "  [V]"]
