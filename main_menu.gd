extends Node2D
## قائمة بداية اللعبة. PLAY يفتح مشهد المقدمة (Intro)، SETTINGS بتفتح بانل فيه
## تحكم في مستوى الصوت، EXIT بيقفل اللعبة. تتحكم بالماوس (هوفر/كليك) أو
## بالكيبورد (فوق/تحت لتنقل الاختيار، Space لتفعيله، جوه البانل شمال/يمين
## للصوت وEsc للرجوع) - نفس مفاتيح اللعبة بالظبط.

const UI_PATH: String = "res://ui/horror/FreeHorrorUi.png"
const FONT_PATH: String = "res://fonts/Unutterable-Regular.ttf"
const BG_IMAGE_PATH: String = "res://ui/menu_background.jpg"
const INTRO_SCENE_PATH: String = "res://intro_cutscene.tscn"

const BTN_SIZE: Vector2 = Vector2(52, 15)
const BTN_SCALE: float = 4.0
const DOOR_REGION: Rect2 = Rect2(136, 2, 96, 62)

const REGIONS: Dictionary = {
	"play":     {"red": Rect2(6, 138, 52, 15), "grey": Rect2(70, 138, 52, 15)},
	"settings": {"red": Rect2(6, 170, 52, 15), "grey": Rect2(70, 170, 52, 15)},
	"exit":     {"red": Rect2(6, 202, 52, 15), "grey": Rect2(70, 202, 52, 15)},
}
const ORDER: Array[String] = ["play", "settings", "exit"]

const VOLUME_STEP: float = 0.1

var _layer: CanvasLayer
var _ui_tex: Texture2D
var _game_font: Font
var _buttons: Array[TextureButton] = []
var _selected_index: int = 0
var _hint_label: Label

# --- بانل الإعدادات ---
var _settings_panel: Control
var _settings_open: bool = false
var _volume_pct: float = 1.0
var _volume_bar_bg: ColorRect
var _volume_bar_fill: ColorRect
var _volume_label: Label


func _ready() -> void:
	if ResourceLoader.exists(UI_PATH):
		_ui_tex = load(UI_PATH)
	else:
		print("مش لاقي FreeHorrorUi.png في: ", UI_PATH)

	if ResourceLoader.exists(FONT_PATH):
		_game_font = load(FONT_PATH)

	_layer = CanvasLayer.new()
	add_child(_layer)

	_build_background()
	_build_title()
	_build_buttons()
	_build_settings_panel()
	_select_button(0)


func _make_atlas(region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = _ui_tex
	atlas.region = region
	return atlas


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.045, 0.035, 0.04)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(bg)

	if ResourceLoader.exists(BG_IMAGE_PATH):
		var bg_image := TextureRect.new()
		bg_image.texture = load(BG_IMAGE_PATH)
		bg_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg_image.set_anchors_preset(Control.PRESET_FULL_RECT)
		_layer.add_child(bg_image)
	elif _ui_tex:
		## احتياطي: لو الصورة مش موجودة، ارجع لباب FreeHorrorUi المرسوم بالكود
		var door := TextureRect.new()
		door.texture = _make_atlas(DOOR_REGION)
		door.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		door.stretch_mode = TextureRect.STRETCH_SCALE
		door.modulate = Color(1, 1, 1, 0.22)
		door.mouse_filter = Control.MOUSE_FILTER_IGNORE
		door.set_anchors_preset(Control.PRESET_CENTER)
		var w: float = DOOR_REGION.size.x * 3.2
		var h: float = DOOR_REGION.size.y * 3.2
		door.offset_left = -w / 2.0
		door.offset_right = w / 2.0
		door.offset_top = -h / 2.0 - 10.0
		door.offset_bottom = h / 2.0 - 10.0
		_layer.add_child(door)

	## تعتيم خفيف فوق أي خلفية، عشان العنوان والأزرار يفضلوا واضحين
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(dim)


func _build_title() -> void:
	var title := Label.new()
	title.text = "Addiction"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -240
	title.offset_right = 240
	title.offset_top = 60
	title.offset_bottom = 120
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(0.85, 0.15, 0.15))
	if _game_font:
		title.add_theme_font_override("font", _game_font)
	_layer.add_child(title)

	_hint_label = Label.new()
	_hint_label.text = "↑ ↓ then Space - or click"
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_label.offset_top = -46
	_hint_label.offset_bottom = -18
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	if _game_font:
		_hint_label.add_theme_font_override("font", _game_font)
	_layer.add_child(_hint_label)


func _build_buttons() -> void:
	var w: float = BTN_SIZE.x * BTN_SCALE
	var h: float = BTN_SIZE.y * BTN_SCALE
	var spacing: float = h + 18.0

	for i in range(ORDER.size()):
		var key: String = ORDER[i]
		var btn := TextureButton.new()
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_SCALE
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		btn.set_anchors_preset(Control.PRESET_CENTER)
		var y_offset: float = (i - 1) * spacing
		btn.offset_left = -w / 2.0
		btn.offset_right = w / 2.0
		btn.offset_top = y_offset - h / 2.0
		btn.offset_bottom = y_offset + h / 2.0
		if _ui_tex:
			btn.texture_normal = _make_atlas(REGIONS[key]["grey"])
			btn.texture_hover = _make_atlas(REGIONS[key]["red"])
			btn.texture_pressed = _make_atlas(REGIONS[key]["red"])
		btn.mouse_entered.connect(_select_button.bind(i))
		btn.pressed.connect(_activate.bind(key))
		_layer.add_child(btn)
		_buttons.append(btn)


func _select_button(index: int) -> void:
	if _settings_open:
		return
	_selected_index = clamp(index, 0, _buttons.size() - 1)
	if not _ui_tex:
		return
	for i in range(_buttons.size()):
		var key: String = ORDER[i]
		var state: String = "red" if i == _selected_index else "grey"
		_buttons[i].texture_normal = _make_atlas(REGIONS[key][state])


func _unhandled_input(event: InputEvent) -> void:
	if _settings_open:
		if event.is_action_pressed("ui_cancel"):
			_close_settings()
		elif event.is_action_pressed("ui_left"):
			_set_volume(_volume_pct - VOLUME_STEP)
		elif event.is_action_pressed("ui_right"):
			_set_volume(_volume_pct + VOLUME_STEP)
		return

	if event.is_action_pressed("ui_down"):
		_select_button(_selected_index + 1)
	elif event.is_action_pressed("ui_up"):
		_select_button(_selected_index - 1)
	elif event.is_action_pressed("ui_accept"):
		_activate(ORDER[_selected_index])


func _activate(key: String) -> void:
	match key:
		"play":
			get_tree().change_scene_to_file(INTRO_SCENE_PATH)
		"settings":
			_open_settings()
		"exit":
			get_tree().quit()


# ---------------------------------------------------------------------------
# بانل الإعدادات (مستوى الصوت + رجوع)
# ---------------------------------------------------------------------------

func _build_settings_panel() -> void:
	_settings_panel = Control.new()
	_settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_panel.visible = false
	_layer.add_child(_settings_panel)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_close_settings()
	)
	_settings_panel.add_child(dim)

	var box := ColorRect.new()
	box.color = Color(0.08, 0.05, 0.05, 0.97)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -160
	box.offset_right = 160
	box.offset_top = -90
	box.offset_bottom = 90
	_settings_panel.add_child(box)

	var border := ColorRect.new()
	border.color = Color(0.55, 0.12, 0.12, 0.9)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.offset_left = -3
	border.offset_top = -3
	border.offset_right = 3
	border.offset_bottom = 3
	box.add_child(border)
	box.move_child(border, 0)

	var title := Label.new()
	title.text = "SETTINGS"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 14
	title.offset_bottom = 44
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.85, 0.15, 0.15))
	if _game_font:
		title.add_theme_font_override("font", _game_font)
	box.add_child(title)

	_volume_label = Label.new()
	_volume_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_volume_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_volume_label.offset_top = 58
	_volume_label.offset_bottom = 82
	_volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_volume_label.add_theme_font_size_override("font_size", 16)
	_volume_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	if _game_font:
		_volume_label.add_theme_font_override("font", _game_font)
	box.add_child(_volume_label)

	_volume_bar_bg = ColorRect.new()
	_volume_bar_bg.color = Color(0, 0, 0, 0.5)
	_volume_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_volume_bar_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_volume_bar_bg.offset_left = 30
	_volume_bar_bg.offset_right = -30
	_volume_bar_bg.offset_top = 92
	_volume_bar_bg.offset_bottom = 108
	box.add_child(_volume_bar_bg)

	_volume_bar_fill = ColorRect.new()
	_volume_bar_fill.color = Color(0.75, 0.15, 0.15)
	_volume_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_volume_bar_bg.add_child(_volume_bar_fill)

	var hint := Label.new()
	hint.text = "← → volume     Esc back"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -34
	hint.offset_bottom = -12
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	if _game_font:
		hint.add_theme_font_override("font", _game_font)
	box.add_child(hint)

	var back_btn := Button.new()
	back_btn.text = "< Back"
	back_btn.flat = true
	back_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back_btn.offset_left = 10
	back_btn.offset_top = 6
	back_btn.offset_right = 90
	back_btn.offset_bottom = 30
	back_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	back_btn.add_theme_color_override("font_hover_color", Color(1, 0.35, 0.35, 0.95))
	if _game_font:
		back_btn.add_theme_font_override("font", _game_font)
	back_btn.pressed.connect(_close_settings)
	box.add_child(back_btn)

	var idx: int = AudioServer.get_bus_index("Master")
	_volume_pct = clamp(db_to_linear(AudioServer.get_bus_volume_db(idx)), 0.0, 1.0)


func _open_settings() -> void:
	_settings_open = true
	_settings_panel.visible = true
	call_deferred("_update_volume_display")


func _close_settings() -> void:
	_settings_open = false
	_settings_panel.visible = false


func _set_volume(new_pct: float) -> void:
	_volume_pct = clamp(new_pct, 0.0, 1.0)
	_update_volume_display()


func _update_volume_display() -> void:
	var idx: int = AudioServer.get_bus_index("Master")
	if _volume_pct <= 0.0:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(_volume_pct))

	_volume_label.text = "Volume: %d%%" % int(round(_volume_pct * 100.0))
	var target_width: float = _volume_bar_bg.size.x * _volume_pct
	_volume_bar_fill.size = Vector2(target_width, _volume_bar_bg.size.y)
