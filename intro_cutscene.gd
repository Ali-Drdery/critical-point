extends CanvasLayer

## ============================================================
## Intro Cutscene - "Critical Point"
## مشهد افتتاحي غير تفاعلي: سرد صوتي (تسجيلك) بيتشغل من البداية، والنصوص
## المكتوبة بتتزامن معاه. طفل بيحلم -> بيقع في الإدمان -> بيحاول يوصل لباب
## الحرية آلاف المرات وكل مرة السلسلة بترجعه -> آخر محاولة (وهو كبير) بيوصل
## لحد الباب وبعدين السلسلة بتسحبه بعنف وهو بيصرخ "Noooo" -> الشاشة تضلم
## كإنها النهاية وبيظهر بالأحمر "Now it's your turn to help him" -> main.tscn.
##
## المشهد بيحصل فعليًا جوه نفس غرفة main: نفس خلفية الكهف (backgrounds/cave)،
## نفس تكستشر الأرضية (floor_fill/floor_strip)، نفس شكل الباب (نفس فريمات
## end_portal_frames)، ونفس أسلوب رسم السلسلة (حلقة واحدة من chains.png بتتكرر
## على طول الخط) اللي بنيناه في main.gd.
##
## التوقيت: أول 12 ثانية (PART1_DURATION) بتغطي السطرين الأولين من الكلام
## (لحد كلمة "addiction"). بعد كده على طول بيبدأ يحاول يوصل للباب - مشي حقيقي
## بأنيميشن run، مش انزلاق - وده بيتزامن مع الـ24 ثانية اللي بعد كده
## (PART2_DURATION) اللي فيها السطر التالت من الكلام. في الآخر - وهو كبر
## وبقى شاب - بيوصل فعلاً للباب وبعدين السلسلة بتسحبه بعنف.
## ============================================================

const NEXT_SCENE_PATH := "res://main.tscn"
const GAME_FONT: Font = preload("res://fonts/Unutterable-Regular.ttf")

# --- سبرايتس الشخصية ---
const CHILD_IDLE_PATH := "res://characters/small/male_hero-idle.png"
const CHILD_RUN_PATH := "res://characters/small/male_hero-run.png"
const HERO_IDLE_PATH := "res://characters/big/Idle.png"
const HERO_RUN_PATH := "res://characters/big/Run.png"
const CHILD_BASE_SCALE: float = 1.6
const HERO_BASE_SCALE: float = 1.1

# --- صورة السلسلة - نفس ملف main.gd ---
const CHAIN_IMAGE_PATH := "res://effects/chains.png"

# --- خلفية الكهف - نفس ملفات main.gd ---
const CAVE_LAYER_COUNT: int = 8
const CAVE_LAYER_PATH_FORMAT := "res://backgrounds/cave/%d.png"

# --- أصول الأرضية - نفس ملفات main.gd بالظبط ---
const FLOOR_FILL_PATH: String = "res://ground/floor_fill.png"
const FLOOR_STRIP_PATH: String = "res://ground/floor_strip.png"
const FLOOR_STRIP_TILE_WIDTH: int = 72
const FLOOR_STRIP_FULL_HEIGHT: int = 32
@export var floor_strip_overlap: float = 6.0

# --- الباب - نفس فريمات main.gd بالظبط (الباب المستطيل المتوهج) ---
const DOOR_FRAMES_DIR: String = "res://doors/end_portal_frames/"
const DOOR_FRAME_COUNT: int = 40
const DOOR_ANIM_FPS: float = 14.0
const DOOR_VISUAL_SCALE: float = 0.4

# --- الشياطين - نفس ملفات night.gd ---
const DEMON_FLYING_PATH := "res://demons/without_outline/FLYING.png"
const DEMON_FRAME_W: int = 79
const DEMON_FRAME_H: int = 69
const DEMON_FRAME_COUNT: int = 4
const DEMON_FPS: float = 8.0

# --- صوتيات ---
const CHAIN_SFX_PATH := "res://audio/sfx/Dragging_Chain_Sound_Effect.mp3"
const VOICE_NARRATION_PATH := "res://audio/voice/narration.ogg"
const VOICE_SCREAM_PATH := "res://audio/voice/noooo.ogg"
const VOICE_NOW_YOUR_TURN_PATH := "res://audio/voice/now_your_turn.ogg"

# --- توقيت السرد: الجزء الأول (لحد "addiction") = 12 ث، الجزء التاني
# (محاولات الهروب) = 24 ث - زي ما التسجيل الصوتي بالظبط ---
const PART1_DURATION: float = 12.0
const PART2_DURATION: float = 24.0

var vw: float
var vh: float
var floor_top_y: float
var anchor_pos: Vector2
var door_pos: Vector2

var skipped := false

var overlay: ColorRect
var chain_visual: ChainVisual
var door_visual: AnimatedSprite2D
var player_root: Node2D
var child_visual: CharAnim
var hero_visual: CharAnim
var demon_field: IntroDemonField

var story_label: Label
var skip_label: Label

var chain_sfx: AudioStreamPlayer
var thud_sfx: AudioStreamPlayer
var voice_narration: AudioStreamPlayer
var voice_scream: AudioStreamPlayer
var voice_now_your_turn: AudioStreamPlayer


func _ready() -> void:
	var rect := get_viewport().get_visible_rect()
	vw = rect.size.x
	vh = rect.size.y
	floor_top_y = vh * 0.82
	# نفس ارتفاع الأرض بالظبط للاتنين - عشان يمشي فعليًا على الأرض مش يطير
	anchor_pos = Vector2(vw * 0.15, floor_top_y - 10.0)
	door_pos = Vector2(vw * 0.82, floor_top_y - 40.0)

	_build_scene()
	_run_cutscene()


func _process(_delta: float) -> void:
	if chain_visual and player_root:
		chain_visual.update_chain(anchor_pos, player_root.position)


func _input(event: InputEvent) -> void:
	if skipped:
		return
	if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
		skipped = true


# ---------------------------------------------------------------------------
# بناء المشهد
# ---------------------------------------------------------------------------

func _build_scene() -> void:
	_build_cave_background()
	_build_floor()
	_build_door()
	_build_chain_and_player()
	_build_demons()
	_build_overlay_and_text()
	_build_audio()


func _build_cave_background() -> void:
	var loaded_count: int = 0
	for i in range(CAVE_LAYER_COUNT):
		var path: String = CAVE_LAYER_PATH_FORMAT % i
		if not ResourceLoader.exists(path):
			continue
		loaded_count += 1
		var tex: Texture2D = load(path)
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = -30 + i
		var tex_size: Vector2 = tex.get_size()
		var cover_scale: float = max(vw / tex_size.x, vh / tex_size.y)
		sprite.scale = Vector2(cover_scale, cover_scale)
		add_child(sprite)

	if loaded_count == 0:
		var fallback := ColorRect.new()
		fallback.color = Color(0.05, 0.05, 0.08)
		fallback.size = Vector2(vw, vh)
		fallback.z_index = -31
		add_child(fallback)
		print("مش لاقي طبقات خلفية الكهف في: ", CAVE_LAYER_PATH_FORMAT)


## نفس منطق main.gd بالظبط (_style_floor + _tile_floor_fill + _tile_floor_strip)
## بس بإحداثيات شاشة الكاتسين (top_left يبدأ من floor_top_y) بدل إحداثيات
## floor_shape بتاعة الأوضة.
func _build_floor() -> void:
	var top_left := Vector2(0.0, floor_top_y)
	var size := Vector2(vw, vh - floor_top_y)

	if not ResourceLoader.exists(FLOOR_FILL_PATH) or not ResourceLoader.exists(FLOOR_STRIP_PATH):
		var fallback := ColorRect.new()
		fallback.color = Color(0.15, 0.12, 0.1)
		fallback.size = size
		fallback.position = top_left
		fallback.z_index = -5
		add_child(fallback)
		print("مش لاقي floor_fill.png أو floor_strip.png - هيتستخدم لون واحد بديل")
		return

	_tile_floor_fill(top_left, size)
	_tile_floor_strip(top_left, vw)


func _tile_floor_fill(top_left: Vector2, size: Vector2) -> void:
	var tex: Texture2D = load(FLOOR_FILL_PATH)
	var tile_size: Vector2 = tex.get_size()
	var cols: int = int(ceil(size.x / tile_size.x))
	var rows: int = int(ceil(size.y / tile_size.y))
	for row in range(rows):
		for col in range(cols):
			var sprite := Sprite2D.new()
			sprite.texture = tex
			sprite.centered = false
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.position = top_left + Vector2(col * tile_size.x, row * tile_size.y)
			sprite.z_index = -5
			add_child(sprite)


func _tile_floor_strip(floor_top_left: Vector2, floor_width: float) -> void:
	var tex: Texture2D = load(FLOOR_STRIP_PATH)
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(0, 0, FLOOR_STRIP_TILE_WIDTH, FLOOR_STRIP_FULL_HEIGHT)

	var cols: int = int(ceil(floor_width / float(FLOOR_STRIP_TILE_WIDTH)))
	for col in range(cols):
		var sprite := Sprite2D.new()
		sprite.texture = atlas
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(
			floor_top_left.x + col * FLOOR_STRIP_TILE_WIDTH,
			floor_top_left.y - FLOOR_STRIP_FULL_HEIGHT + floor_strip_overlap
		)
		sprite.z_index = -4
		add_child(sprite)


## نفس فريمات الباب بتاعة main.gd بالظبط (end_portal_frames) - الباب المستطيل
## المتوهج، مش الدايرة القديمة اللي شكلها قمر.
func _build_door() -> void:
	var frames := _build_door_sprite_frames()
	door_visual = AnimatedSprite2D.new()
	door_visual.sprite_frames = frames
	door_visual.animation = "open"
	var frame_count: int = frames.get_frame_count("open")
	door_visual.frame = max(frame_count - 1, 0)  # واقف على آخر فريم (متوهج بالكامل) طول الكاتسين
	door_visual.position = door_pos
	door_visual.scale = Vector2.ONE * DOOR_VISUAL_SCALE
	door_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	door_visual.modulate.a = 0.85
	door_visual.z_index = -2
	add_child(door_visual)
	_pulse_alpha(door_visual, 0.6, 0.95)


func _build_door_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation("open")
	frames.set_animation_loop("open", false)
	frames.set_animation_speed("open", DOOR_ANIM_FPS)

	var loaded_count: int = 0
	for i in range(DOOR_FRAME_COUNT):
		var path: String = DOOR_FRAMES_DIR + "sprite_%02d.png" % i
		if not ResourceLoader.exists(path):
			continue
		frames.add_frame("open", load(path))
		loaded_count += 1

	if loaded_count == 0:
		print("مش لاقي فريمات الباب في: ", DOOR_FRAMES_DIR)

	return frames


func _build_chain_and_player() -> void:
	chain_visual = ChainVisual.new()
	add_child(chain_visual)
	chain_visual.setup(CHAIN_IMAGE_PATH)

	player_root = Node2D.new()
	player_root.position = anchor_pos
	add_child(player_root)

	child_visual = CharAnim.new()
	child_visual.setup(true, 128, 128)
	child_visual.add_anim("idle", CHILD_IDLE_PATH, 10, 6.0)
	child_visual.add_anim("run", CHILD_RUN_PATH, 10, 13.0)
	child_visual.scale = Vector2.ONE * CHILD_BASE_SCALE * 0.6
	child_visual.play("idle")
	child_visual.face_direction(1)
	player_root.add_child(child_visual)

	hero_visual = CharAnim.new()
	hero_visual.setup(false, 200, 200)
	hero_visual.add_anim("idle", HERO_IDLE_PATH, 4, 5.0)
	hero_visual.add_anim("run", HERO_RUN_PATH, 8, 13.0)
	hero_visual.scale = Vector2.ONE * HERO_BASE_SCALE
	hero_visual.play("idle")
	hero_visual.face_direction(1)
	hero_visual.visible = false
	player_root.add_child(hero_visual)


func _build_demons() -> void:
	demon_field = IntroDemonField.new()
	add_child(demon_field)
	demon_field.setup(Vector2(vw, vh))


func _build_overlay_and_text() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	story_label = Label.new()
	story_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	story_label.add_theme_font_size_override("font_size", 30)
	story_label.add_theme_font_override("font", GAME_FONT)
	story_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	story_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	story_label.add_theme_constant_override("outline_size", 6)
	story_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	story_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	story_label.modulate.a = 0.0
	story_label.position = Vector2(vw * 0.1, vh * 0.68)
	story_label.size = Vector2(vw * 0.8, vh * 0.22)
	add_child(story_label)

	skip_label = Label.new()
	skip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_label.text = "Press any key to skip"
	skip_label.add_theme_font_size_override("font_size", 14)
	skip_label.modulate.a = 0.5
	skip_label.position = Vector2(vw - 220, vh - 34)
	add_child(skip_label)


func _build_audio() -> void:
	chain_sfx = AudioStreamPlayer.new()
	chain_sfx.stream = _load_audio(CHAIN_SFX_PATH)
	add_child(chain_sfx)

	thud_sfx = AudioStreamPlayer.new()
	thud_sfx.stream = _load_audio(CHAIN_SFX_PATH)
	add_child(thud_sfx)

	voice_narration = AudioStreamPlayer.new()
	voice_narration.stream = _load_audio(VOICE_NARRATION_PATH)
	add_child(voice_narration)

	voice_scream = AudioStreamPlayer.new()
	voice_scream.stream = _load_audio(VOICE_SCREAM_PATH)
	add_child(voice_scream)

	voice_now_your_turn = AudioStreamPlayer.new()
	voice_now_your_turn.stream = _load_audio(VOICE_NOW_YOUR_TURN_PATH)
	add_child(voice_now_your_turn)


func _load_audio(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)
	print("مش لاقي صوت: ", path)
	return null


func _play(player: AudioStreamPlayer) -> void:
	if player and player.stream:
		player.play()


func _pulse_alpha(node: CanvasItem, low: float, high: float) -> void:
	var t := create_tween()
	t.set_loops()
	t.tween_property(node, "modulate:a", high, 1.2).set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "modulate:a", low, 1.2).set_trans(Tween.TRANS_SINE)


func _set_demon_proximity(target: float, duration: float) -> void:
	if demon_field == null:
		return
	var tw := create_tween()
	tw.tween_method(demon_field.set_proximity, demon_field.get_proximity(), target, duration)


func _flash_red(peak_alpha: float, in_time: float, out_time: float) -> void:
	var base_color := Color(0, 0, 0, overlay.color.a)
	var red_color := Color(0.6, 0.05, 0.05, peak_alpha)
	var tw := create_tween()
	tw.tween_property(overlay, "color", red_color, in_time)
	tw.tween_property(overlay, "color", base_color, out_time)


# ---------------------------------------------------------------------------
# تسلسل القصة - متزامن مع تسجيل السرد: PART1_DURATION (12 ث لحد "addiction")
# ثم PART2_DURATION (24 ث - محاولات الهروب بتحصل بالتوازي مع النص)
# ---------------------------------------------------------------------------

func _run_cutscene() -> void:
	_play(voice_narration)
	await get_tree().create_timer(0.3).timeout
	if skipped:
		await _end_cutscene()
		return

	var part1_lines: Array[String] = [
		"One day, there was a young boy dreaming of becoming something great.",
		"But unfortunately, he fell into addiction.",
	]
	var part2_line := "From then on, he tried to escape a thousand times and failed every time - but he never gave up. He kept trying to reach the door of freedom, and every time, the addiction pulled him back."

	# --- الجزء الأول: بيتزامن مع أول 12 ثانية من التسجيل (لحد "addiction") ---
	var durations1: Array[float] = _compute_synced_durations(part1_lines, PART1_DURATION)
	for i in range(part1_lines.size()):
		var hold: float = max(durations1[i] - 1.0, 0.3)
		await _show_story_text(part1_lines[i], hold)
		if skipped:
			await _end_cutscene()
			return
		if i == 0:
			_blackout_and_dim()  # بيحصل بالتوازي مع السطر الجاي - مش هياخد وقت زيادة

	# --- الجزء التاني: 24 ثانية - النص فاضل ظاهر وهو بيحاول يوصل للباب مشي فعلي ---
	_set_demon_proximity(0.25, 1.5)
	_show_story_text(part2_line, max(PART2_DURATION - 1.0, 0.3))  # non-blocking، متزامن مع المحاولات
	await _run_escape_attempts(PART2_DURATION)

	if not skipped:
		await _final_attempt()

	await _end_cutscene()


func _compute_synced_durations(lines: Array[String], total_duration: float) -> Array[float]:
	var total_chars: int = 0
	for l in lines:
		total_chars += l.length()
	var durations: Array[float] = []
	for l in lines:
		var ratio: float = float(l.length()) / float(max(total_chars, 1))
		durations.append(total_duration * ratio)
	return durations


func _show_story_text(text: String, hold_time: float, color: Color = Color(1, 1, 1, 1)) -> void:
	story_label.text = text
	story_label.add_theme_color_override("font_color", color)
	var t := create_tween()
	t.tween_property(story_label, "modulate:a", 1.0, 0.5)
	await t.finished

	var waited: float = 0.0
	while waited < hold_time and not skipped:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1

	var t2 := create_tween()
	t2.tween_property(story_label, "modulate:a", 0.0, 0.5)
	await t2.finished


func _blackout_and_dim() -> void:
	overlay.color = Color(0, 0, 0, 1.0)
	await get_tree().create_timer(0.4).timeout
	var t := create_tween()
	t.tween_property(overlay, "color:a", 0.45, 2.5).set_trans(Tween.TRANS_SINE)
	await t.finished


## ٨ محاولات هروب سريعة بتمثل "آلاف المحاولات"، مدتها بتتحسب أوتوماتيك عشان
## مجموعها يساوي total_time بالظبط (متزامنة مع نص الـ24 ثانية). كل محاولة
## بتوصل مسافة أكبر من اللي قبلها، وآخر اتنين بيبدأ يبان عليه إنه بقى شاب
## (hero_visual بسكيل أصغر) تمهيدًا للمحاولة الأخيرة الحاسمة.
func _run_escape_attempts(total_time: float) -> void:
	var reach_steps: Array[float] = [0.22, 0.32, 0.42, 0.52, 0.62, 0.70, 0.76, 0.80]

	var nominal_costs: Array[float] = []
	var nominal_total: float = 0.0
	for reach in reach_steps:
		var approach: float = 0.9 + reach * 1.1
		var cost: float = approach + 0.3 + 0.5  # مشي + رجوع بالسلسلة + وقفة قبل المحاولة الجاية
		nominal_costs.append(cost)
		nominal_total += cost

	var scale_factor: float = total_time / max(nominal_total, 0.01)

	for i in range(reach_steps.size()):
		if skipped:
			return
		var reach: float = reach_steps[i]
		var approach_dur: float = (0.9 + reach * 1.1) * scale_factor
		var return_dur: float = 0.3 * scale_factor
		var pause_dur: float = 0.5 * scale_factor
		var use_hero: bool = i >= reach_steps.size() - 2
		await _quick_attempt(reach, approach_dur, return_dur, pause_dur, use_hero)


## محاولة هروب واحدة - مشي حقيقي أفقي بس (نفس ارتفاع anchor_pos.y طول الوقت،
## عشان يمشي فعليًا على الأرض مش يطير)، بأنيميشن run شغال، وبسرعة ثابتة
## (TRANS_LINEAR) عشان يحس إنه فعلاً بيجري مش بينزلق.
func _quick_attempt(reach_ratio: float, approach_dur: float, return_dur: float, pause_dur: float, use_hero: bool = false) -> void:
	var target_x: float = lerp(anchor_pos.x, door_pos.x, reach_ratio)
	var target := Vector2(target_x, anchor_pos.y)

	var actor: CharAnim = hero_visual if use_hero else child_visual
	var other: CharAnim = child_visual if use_hero else hero_visual
	other.visible = false
	actor.visible = true

	if use_hero:
		actor.scale = Vector2.ONE * HERO_BASE_SCALE * 0.85  # لسه بيكبر، مش بحجمه الكامل
	else:
		var grow: float = lerp(0.6, 1.0, reach_ratio)
		actor.scale = Vector2.ONE * CHILD_BASE_SCALE * grow

	actor.play("run")
	actor.face_direction(1)

	var t := create_tween()
	t.tween_property(player_root, "position", target, approach_dur).set_trans(Tween.TRANS_LINEAR)
	_set_demon_proximity(min(1.0, demon_field.get_proximity() + 0.05), approach_dur)
	await t.finished
	if skipped:
		return

	var snap := create_tween()
	snap.tween_property(player_root, "position", anchor_pos, return_dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_play(chain_sfx)
	await snap.finished
	if skipped:
		return

	actor.play("idle")
	actor.face_direction(-1)
	_flash_red(0.4, 0.08, 0.4)
	_set_demon_proximity(min(1.0, demon_field.get_proximity() + 0.1), 0.4)

	await get_tree().create_timer(pause_dur).timeout


## المحاولة الأخيرة الحاسمة - وهو بقى شاب (hero_visual بحجمه الكامل)، بيمشي
## فعلاً لحد الباب (مش بيقف قبله زي المحاولات التانية)، وبعدين السلسلة بتسحبه
## بعنف وهو بيصرخ "Noooo".
func _final_attempt() -> void:
	voice_narration.stop()  # ضمان إن السرد يبقى واقف نظيف قبل لحظة الصراخ

	child_visual.visible = false
	hero_visual.visible = true
	hero_visual.scale = Vector2.ONE * HERO_BASE_SCALE
	hero_visual.play("run")
	hero_visual.face_direction(1)

	var target := Vector2(door_pos.x - 24.0, anchor_pos.y)  # يوصل فعلاً قدام الباب
	var t := create_tween()
	t.tween_property(player_root, "position", target, 1.6).set_trans(Tween.TRANS_LINEAR)
	_set_demon_proximity(0.85, 1.6)
	await t.finished
	if skipped:
		return

	hero_visual.play("idle")
	hero_visual.face_direction(1)
	await get_tree().create_timer(0.7).timeout
	if skipped:
		return

	hero_visual.play("run")
	var snap := create_tween()
	snap.tween_property(player_root, "position", anchor_pos, 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_play(chain_sfx)
	_set_demon_proximity(1.0, 0.4)
	await snap.finished

	hero_visual.play("idle")
	hero_visual.face_direction(-1)
	_play(thud_sfx)
	_play(voice_scream)
	_flash_red(0.85, 0.05, 0.7)
	await _show_story_text("NOOOOO!", 1.0, Color(0.9, 0.1, 0.1, 1.0))


func _end_cutscene() -> void:
	story_label.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(overlay, "color", Color(0, 0, 0, 1.0), 1.2)
	await t.finished
	_set_demon_proximity(0.0, 0.1)

	_play(voice_now_your_turn)  # مش هيعمل حاجة لو لسه مسجلتهاش - آمن
	await _show_story_text("Now it's your turn to help him.", 2.6, Color(0.9, 0.15, 0.15, 1.0))

	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file(NEXT_SCENE_PATH)


# ---------------------------------------------------------------------------
# ChainVisual: نفس أسلوب رسم main.gd's ChainPullVisual بالظبط - حلقة واحدة
# من chains.png (LINK_SRC) بتتكرر وبتتلف على طول الخط من anchor لحد اللاعب،
# بدل ما ترسم كل قطعة كسبرايت كامل زي القديم.
# ---------------------------------------------------------------------------
class ChainVisual extends Node2D:
	## نفس منطقة الحلقة الواحدة القابلة للتكرار جوه chains.png بتاعة main.gd
	const LINK_SRC: Rect2 = Rect2(2, 0, 5, 5)
	const LINK_SCALE: float = 6.0

	var _chain_tex: Texture2D = null
	var _has_texture: bool = false
	var _from: Vector2 = Vector2.ZERO
	var _to: Vector2 = Vector2.ZERO

	func setup(texture_path: String) -> void:
		if ResourceLoader.exists(texture_path):
			_chain_tex = load(texture_path)
			_has_texture = true
		else:
			print("مش لاقي صورة السلسلة: ", texture_path)

	func update_chain(from_pos: Vector2, to_pos: Vector2) -> void:
		_from = from_pos
		_to = to_pos
		queue_redraw()

	func _draw() -> void:
		if not _has_texture:
			return
		var diff: Vector2 = _to - _from
		var dist: float = diff.length()
		if dist < 1.0:
			return
		var dir: Vector2 = diff / dist
		var angle: float = dir.angle() - PI / 2.0
		var link_step: float = LINK_SRC.size.y * LINK_SCALE
		var link_count: int = int(dist / link_step)
		var draw_size: Vector2 = LINK_SRC.size * LINK_SCALE
		for i in range(link_count):
			var link_pos: Vector2 = _from + dir * (link_step * (i + 0.5))
			draw_set_transform(link_pos, angle, Vector2.ONE)
			draw_texture_rect_region(_chain_tex, Rect2(-draw_size / 2.0, draw_size), LINK_SRC)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------------------
# CharAnim: عرض شيت سبرايت (idle/run) بالكود من غير AnimatedSprite2D
# ---------------------------------------------------------------------------
class CharAnim extends Node2D:
	var _sprite: Sprite2D
	var _faces_left_default: bool
	var _frame_w: int
	var _frame_h: int
	var _anims: Dictionary = {}
	var _current: String = ""
	var _frame_index: int = 0
	var _frame_timer: float = 0.0

	func setup(faces_left_default: bool, frame_w: int, frame_h: int) -> void:
		_faces_left_default = faces_left_default
		_frame_w = frame_w
		_frame_h = frame_h
		_sprite = Sprite2D.new()
		_sprite.centered = true
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_sprite)

	func add_anim(anim_name: String, path: String, frame_count: int, fps: float) -> void:
		if not ResourceLoader.exists(path):
			print("مش لاقي سبرايت: ", path)
			return
		_anims[anim_name] = {"texture": load(path), "frame_count": frame_count, "fps": fps}

	func play(anim_name: String) -> void:
		if not _anims.has(anim_name) or _current == anim_name:
			return
		_current = anim_name
		_frame_index = 0
		_frame_timer = 0.0
		_update_frame()

	func face_direction(dir: int) -> void:
		if dir == 0 or _sprite == null:
			return
		_sprite.flip_h = (dir > 0) == _faces_left_default

	func _process(delta: float) -> void:
		if not _anims.has(_current):
			return
		var data: Dictionary = _anims[_current]
		_frame_timer += delta
		var frame_duration: float = 1.0 / float(data["fps"])
		if _frame_timer >= frame_duration:
			_frame_timer -= frame_duration
			_frame_index = (_frame_index + 1) % int(data["frame_count"])
			_update_frame()

	func _update_frame() -> void:
		if not _anims.has(_current):
			return
		var data: Dictionary = _anims[_current]
		var atlas := AtlasTexture.new()
		atlas.atlas = data["texture"]
		atlas.region = Rect2(_frame_index * _frame_w, 0, _frame_w, _frame_h)
		_sprite.texture = atlas


# ---------------------------------------------------------------------------
# شياطين الخلفية - نسخة مبسطة (Flying بس) بتاخد نفس أصول night.gd
# ---------------------------------------------------------------------------
class IntroDemonUnit extends Node2D:
	var _sprite: Sprite2D
	var _frames: Array[Texture2D] = []
	var _fps: float = 8.0
	var _frame_index: int = 0
	var _frame_timer: float = 0.0
	var _corner: Vector2 = Vector2.ZERO
	var _base_scale: float = 1.0
	var _proximity: float = 0.0

	func setup(texture: Texture2D, frame_w: int, frame_h: int, frame_count: int, fps: float, corner: Vector2, base_scale: float) -> void:
		_fps = fps
		_corner = corner
		_base_scale = base_scale
		position = corner

		_sprite = Sprite2D.new()
		_sprite.centered = true
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.flip_h = corner.x > 0.0
		add_child(_sprite)

		if texture:
			for i in range(frame_count):
				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
				_frames.append(atlas)
			_sprite.texture = _frames[0]

		_update_visual()

	func update_proximity(p: float) -> void:
		_proximity = p
		position = _corner.lerp(Vector2.ZERO, p * 0.7)
		scale = Vector2.ONE * (_base_scale * (1.0 + p * 0.5))
		_update_visual()

	func _update_visual() -> void:
		var alpha: float = 0.12 + 0.6 * _proximity
		var lit: Color = Color(0.05, 0.02, 0.08).lerp(Color(1, 1, 1), _proximity * 0.4)
		modulate = Color(lit.r, lit.g, lit.b, alpha)

	func _process(delta: float) -> void:
		if _frames.is_empty():
			return
		_frame_timer += delta
		var frame_duration: float = 1.0 / _fps
		if _frame_timer >= frame_duration:
			_frame_timer -= frame_duration
			_frame_index = (_frame_index + 1) % _frames.size()
			_sprite.texture = _frames[_frame_index]


class IntroDemonField extends Node2D:
	var _demons: Array[IntroDemonUnit] = []
	var _proximity: float = 0.0

	func setup(screen_size: Vector2) -> void:
		var tex: Texture2D = null
		if ResourceLoader.exists(DEMON_FLYING_PATH):
			tex = load(DEMON_FLYING_PATH)
		else:
			print("مش لاقي شيت الشيطان: ", DEMON_FLYING_PATH)

		var half: Vector2 = screen_size / 2.0
		position = half
		var corners: Array[Vector2] = [
			Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
			Vector2(-half.x, half.y), Vector2(half.x, half.y),
		]
		for corner in corners:
			var unit := IntroDemonUnit.new()
			add_child(unit)
			unit.setup(tex, DEMON_FRAME_W, DEMON_FRAME_H, DEMON_FRAME_COUNT, DEMON_FPS, corner, 1.6)
			_demons.append(unit)

	func set_proximity(p: float) -> void:
		_proximity = clamp(p, 0.0, 1.0)
		for d in _demons:
			d.update_proximity(_proximity)

	func get_proximity() -> float:
		return _proximity
