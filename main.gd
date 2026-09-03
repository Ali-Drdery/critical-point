extends Node2D
## يدير الأوضة بالكامل: الحركة/الحدود، خلفية الكهف، الأرضية، الخمس مراحل الليلية
## بالترتيب الجغرافي (مش عشوائي)، شريط إرادة + 3 حيوات مشتركة + خلفية شياطين
## (سبرايت حقيقي)، معركة القرين، السلم اللي بيوصل لمنطقة مرتفعة فيها باب مخفي
## بيظهر بس بعد النصر على القرين، وشاشات Game Over / Bad Ending / Good Ending.
##
## آلية "الأذان" لكل مرحلة من الخمسة:
##   - كل تريجر عنده duration بالثواني (على حسب صعوبة المرحلة). بيظهر تايمر
##     مرئي فوق الشاشة أول ما التريجر يشتغل، وبيعد لحد الصفر. لو خلص التحدي
##     الأساسي قبل ما المهلة تخلص، الوقت "يتقدم على طول" للأذان (العد بيتوقف
##     فورًا، التايمر بيختفي، صوت/فلاش الأذان بيشتغل، ولو في bonus بيكمله من
##     غير أي ضغط وقت). لو المهلة خلصت وهو لسه ما خلصش التحدي الأساسي، الأذان
##     بيأذن برضو بس دي خسارة (يخسر حياة).
##   - معركة القرين مفيهاش مهلة وقت خالص.

@onready var player = $Player
@onready var wall_left_shape = $Wallleft/CollisionShape2D
@onready var wall_right_shape = $Wallright/CollisionShape2D
@onready var ceiling_shape = $Ceiling/CollisionShape2D
@onready var floor_shape = $Floor/CollisionShape2D

# --- تخطيط التريجرز/السلم/الباب - قيم تقدر تظبطها لو حسيت حاجة متلاقيتش مكانها ---
const FIRST_TRIGGER_OFFSET: float = 320.0
const TRIGGER_SPACING: float = 340.0
const TRIGGER_ZONE_SIZE: Vector2 = Vector2(70, 140)
const LADDER_WIDTH: float = 40.0
const LADDER_HEIGHT: float = 260.0
const LADDER_OFFSET_FROM_LAST_TRIGGER: float = 300.0
const PLATFORM_WIDTH: float = 420.0
const PLATFORM_HEIGHT: float = 24.0
const QARIN_TRIGGER_OFFSET_X: float = 150.0
const DOOR_OFFSET_X: float = 320.0
const DOOR_FRAMES_DIR: String = "res://doors/end_portal_frames/"
const DOOR_FRAME_COUNT: int = 40
const DOOR_ANIM_FPS: float = 14.0
const DOOR_VISUAL_SCALE: float = 0.4
# --- أصول Crimson Fantasy GUI (قلوب الحيوات + بانر الأذان) ---
const CRIMSON_GUI_PATH: String = "res://ui/crimson/GUISprite.png"
const HEART_FULL_REGION: Rect2 = Rect2(16, 16, 16, 16)
const HEART_EMPTY_REGION: Rect2 = Rect2(64, 16, 16, 16)
const HEART_ICON_SCALE: float = 2.5
const ADHAN_DIVIDER_REGION: Rect2 = Rect2(196, 102, 100, 28)
const ADHAN_DIVIDER_SCALE: float = 1.6
const BAR_EMPTY_REGION: Rect2 = Rect2(16, 51, 64, 9)
const BAR_FILLED_REGION: Rect2 = Rect2(16, 36, 64, 9)
const BAR_SCALE: float = 2.5
const BAR_STRETCH_MARGIN: int = 4
const GAME_FONT: Font = preload("res://fonts/Unutterable-Regular.ttf")


# --- أصول الأرضية (Floor) ---
const FLOOR_FILL_PATH: String = "res://ground/floor_fill.png"
const FLOOR_STRIP_PATH: String = "res://ground/floor_strip.png"
## floor_strip.png الأصلي عرضه 86px، لكن آخر ~13px منه فراغ شفاف بالكامل (مش
## seamless) - ده اللي كان بيسبب الفجوات السودة بين كل تكرار. بنستخدم الجزء
## المفيد بس (72px) ونكرره يدويًا.
const FLOOR_STRIP_TILE_WIDTH: int = 72
const FLOOR_STRIP_FULL_HEIGHT: int = 32
## قد إيه الحافة العلوية بتنزل جوه جسم الأرضية (overlap) عشان تغطي أي خط فاصل
## دقيق بين القطعتين - سهل تزوّده/تقلله لو حسيت في خط بسيط لسه ظاهر.
@export var floor_strip_overlap: float = 6.0# --- إرادة / حيوات / شياطين ---
@export var checkpoint_sound: AudioStream = null
@export var mistake_sound: AudioStream = preload("res://audio/sfx/Hit1.wav")
@export var chain_drag_sound: AudioStream = preload("res://audio/sfx/Dragging_Chain_Sound_Effect.mp3")
@export var progress_sound: AudioStream = preload("res://audio/mixkit-correct-answer-tone-2870.wav")
@export var demon_burn_sound: AudioStream = preload("res://audio/freesound_community-nazgul-scream-1-94999.mp3")
@export var willpower_max: float = 100.0
@export var mistake_damage: float = 20.0
@export var max_lives: int = 3
@export var demon_proximity_per_mistake: float = 0.22
@export var demon_proximity_per_progress: float = 0.10

## الخمس مراحل الليلية بالترتيب الجغرافي - كل عنصر: اسم الأذان + مصنع المرحلة +
## مهلة بالثواني قبل ما "يأذن" (مضبوطة على حسب صعوبة/طول كل مرحلة).
var NIGHT_STAGES: Array[Dictionary] = [
	{"adhan_name": "Fajr",    "duration": 26.0, "factory": func(): return IstighfarStage.new()},
	{"adhan_name": "Dhuhr",   "duration": 24.0, "factory": func(): return TemptationStage.new()},
	{"adhan_name": "Asr",     "duration": 24.0, "factory": func(): return BoredomStage.new()},
	{"adhan_name": "Maghrib", "duration": 30.0, "factory": func(): return DistractionStage.new()},
	{"adhan_name": "Isha",    "duration": 40.0, "factory": func(): return NightRoutineStage.new()},
]

var start_position: Vector2
var last_checkpoint_position: Vector2
var _floor_top_y: float = 0.0
var _last_trigger_x: float = 0.0

var _active_challenge_stage: StageBase = null
var _active_trigger: Area2D = null
var _is_qarin_challenge: bool = false

var willpower: float = 0.0
var _lives_remaining: int = 3
var _is_dying: bool = false
var _qarin_defeated: bool = false
var _ending_active: bool = false

var demon_proximity: float = 0.0
var _demon_layer: CanvasLayer
var _demon_backdrop: Node2D

# --- مهلة (أذان) التحدي الشغال حاليًا ---
var _main_already_succeeded: bool = false
var _deadline_active: bool = false
var _time_remaining: float = 0.0
var _time_total: float = 1.0

var _hud_layer: CanvasLayer
var _darkness_overlay: ColorRect
var _danger_overlay: ColorRect
var _willpower_bar: TextureProgressBar
var _adhan_container: Control
var _adhan_label: Label
var _adhan_divider: TextureRect
var _hearts_container: HBoxContainer
var _heart_textures: Array[TextureRect] = []
var _crimson_gui_tex: Texture2D
var _timer_label: Label

const _TIMER_NORMAL_COLOR: Color = Color(1, 1, 1, 0.9)
const _TIMER_DANGER_COLOR: Color = Color(1.0, 0.2, 0.15, 1.0)

var _door_area: Area2D
var _door_visual: AnimatedSprite2D
var _ladder_zone: Area2D


func _ready() -> void:
	if ResourceLoader.exists("res://audio/adhan.ogg"):
		checkpoint_sound = load("res://audio/adhan.ogg")
	if ResourceLoader.exists("res://audio/mixkit-correct-answer-tone-2870.wav"):
		progress_sound = load("res://audio/mixkit-correct-answer-tone-2870.wav")
	if ResourceLoader.exists("res://audio/freesound_community-nazgul-scream-1-94999.mp3"):
		demon_burn_sound = load("res://audio/freesound_community-nazgul-scream-1-94999.mp3")

	_build_cave_background()
	_style_floor()

	start_position = player.position
	last_checkpoint_position = start_position

	var floor_rect: RectangleShape2D = floor_shape.shape
	_floor_top_y = floor_shape.global_position.y - floor_rect.size.y / 2.0

	player.set_camera_limits(
		int(wall_left_shape.global_position.x),
		int(wall_right_shape.global_position.x),
		int(ceiling_shape.global_position.y),
		int(floor_shape.global_position.y) + 100
	)

	willpower = willpower_max
	_lives_remaining = max_lives

	_build_hud()
	_build_demon_backdrop()
	_build_night_triggers()
	_build_ladder_and_door()


func _process(delta: float) -> void:
	if not _deadline_active or _is_dying:
		return
	_time_remaining -= delta
	var frac_remaining: float = clamp(_time_remaining / _time_total, 0.0, 1.0)
	var danger: float = pow(1.0 - frac_remaining, 2.5)
	_danger_overlay.color.a = danger * 0.55
	_update_timer_label(danger)

	if _time_remaining <= 0.0:
		_on_stage_time_up()


func _unhandled_input(event: InputEvent) -> void:
	if _ending_active and event.is_action_pressed("ui_accept"):
		get_tree().change_scene_to_file("res://main_menu.tscn")


# ---------------------------------------------------------------------------
# خلفية الكهف + الأرضية
# ---------------------------------------------------------------------------

func _build_cave_background() -> void:
	var fallback := ColorRect.new()
	fallback.color = Color(0.05, 0.05, 0.08)
	fallback.z_index = -20
	fallback.size = Vector2(6000, 2000)
	fallback.position = Vector2(-2000, -1000)
	add_child(fallback)

	var layer_width: float = 384.0 * 3.0
	var room_left: float = wall_left_shape.global_position.x
	var room_right: float = wall_right_shape.global_position.x
	var start_x: float = room_left - layer_width * 2.0
	var end_x: float = room_right + layer_width * 2.0
	var tiles_needed: int = int(ceil((end_x - start_x) / layer_width))

	var loaded_count: int = 0
	for i in range(8):
		var path: String = "res://backgrounds/cave/%d.png" % i
		if not ResourceLoader.exists(path):
			print("مش لاقي الملف: ", path)
			continue
		loaded_count += 1
		var tex: Texture2D = load(path)
		var z: int = -19 + (7 - i)

		for t in range(tiles_needed):
			var sprite := Sprite2D.new()
			sprite.texture = tex
			sprite.centered = false
			sprite.scale = Vector2(3, 3)
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.z_index = z
			sprite.position = Vector2(start_x + t * layer_width, -110)
			add_child(sprite)

	print("خلفية الكهف: اتحمّل ", loaded_count, " من 8 طبقات")


func _style_floor() -> void:
	var shape: RectangleShape2D = floor_shape.shape
	var floor_top_left: Vector2 = floor_shape.global_position - shape.size / 2.0

	if not ResourceLoader.exists(FLOOR_FILL_PATH) or not ResourceLoader.exists(FLOOR_STRIP_PATH):
		var fallback := ColorRect.new()
		fallback.color = Color(0.15, 0.12, 0.1)
		fallback.size = shape.size
		fallback.position = floor_top_left
		fallback.z_index = -5
		add_child(fallback)
		print("مش لاقي floor_fill.png أو floor_strip.png - هيتستخدم لون واحد بديل")
		return

	_tile_floor_fill(floor_top_left, shape.size)
	_tile_floor_strip(floor_top_left, shape.size.x)


## بيغطي جسم الأرضية بالكامل بتكستشر floor_fill.png مكرر - اتأكدنا إن حوافه
## (شمال/يمين/فوق/تحت) بتتطابق تمامًا لما بتتكرر، فمفيش أي فجوات هنا خالص.
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


## بيكرر الحافة العلوية (floor_strip.png) أفقيًا فوق الأرضية مباشرة، مقصوصة
## على الجزء المفيد بس (FLOOR_STRIP_TILE_WIDTH) عشان نتجنب الفراغ الشفاف اللي
## كان بيسبب الفجوات في السكرين شوت.
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


# ---------------------------------------------------------------------------
# بناء التريجرز الخمسة + السلم + المنصة + الباب - كله بالكود
# ---------------------------------------------------------------------------

func _build_night_triggers() -> void:
	var x: float = start_position.x + FIRST_TRIGGER_OFFSET
	for i in range(NIGHT_STAGES.size()):
		var trigger: Area2D = _make_trigger_area(
			"ChallengeTrigger_%d" % i,
			Vector2(x, _floor_top_y - TRIGGER_ZONE_SIZE.y / 2.0)
		)
		trigger.set_meta("stage_index", i)
		trigger.body_entered.connect(_on_challenge_trigger_entered.bind(trigger))
		x += TRIGGER_SPACING
	_last_trigger_x = x - TRIGGER_SPACING


func _make_trigger_area(area_name: String, pos: Vector2) -> Area2D:
	var area := Area2D.new()
	area.name = area_name
	area.position = pos
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = TRIGGER_ZONE_SIZE
	shape.shape = rect
	area.add_child(shape)
	add_child(area)

	var arrow := TriggerArrow.new()
	arrow.setup(-TRIGGER_ZONE_SIZE.y / 2.0 - 26.0)
	area.add_child(arrow)
	area.set_meta("arrow", arrow)

	return area


func _build_ladder_and_door() -> void:
	var ladder_x: float = _last_trigger_x + LADDER_OFFSET_FROM_LAST_TRIGGER
	var platform_top_y: float = _floor_top_y - LADDER_HEIGHT

	# --- السلم ---
	_ladder_zone = Area2D.new()
	_ladder_zone.name = "LadderZone"
	_ladder_zone.position = Vector2(ladder_x, _floor_top_y - LADDER_HEIGHT / 2.0)
	var ladder_shape := CollisionShape2D.new()
	var ladder_rect := RectangleShape2D.new()
	ladder_rect.size = Vector2(LADDER_WIDTH, LADDER_HEIGHT)
	ladder_shape.shape = ladder_rect
	_ladder_zone.add_child(ladder_shape)
	_ladder_zone.body_entered.connect(_on_ladder_entered)
	_ladder_zone.body_exited.connect(_on_ladder_exited)
	add_child(_ladder_zone)

	var ladder_visual := LadderVisual.new()
	ladder_visual.position = _ladder_zone.position
	ladder_visual.setup(LADDER_WIDTH, LADDER_HEIGHT)
	ladder_visual.z_index = -3
	add_child(ladder_visual)

	# --- المنصة المرتفعة (أرضية حقيقية يقف عليها بعد ما يطلع) ---
	var platform_center_x: float = ladder_x + LADDER_WIDTH / 2.0 + PLATFORM_WIDTH / 2.0
	var platform := StaticBody2D.new()
	platform.position = Vector2(platform_center_x, platform_top_y + PLATFORM_HEIGHT / 2.0)
	var platform_shape := CollisionShape2D.new()
	var platform_rect := RectangleShape2D.new()
	platform_rect.size = Vector2(PLATFORM_WIDTH, PLATFORM_HEIGHT)
	platform_shape.shape = platform_rect
	platform.add_child(platform_shape)
	add_child(platform)

	var platform_visual := ColorRect.new()
	platform_visual.color = Color(0.16, 0.13, 0.11)
	platform_visual.size = platform_rect.size
	platform_visual.position = platform.position - platform_rect.size / 2.0
	platform_visual.z_index = -4
	add_child(platform_visual)

	var platform_left_x: float = platform_center_x - PLATFORM_WIDTH / 2.0

	# --- تريجر معركة القرين، فوق المنصة ---
	var qarin_trigger: Area2D = _make_trigger_area(
		"ChallengeTrigger_Qarin",
		Vector2(platform_left_x + QARIN_TRIGGER_OFFSET_X, platform_top_y - TRIGGER_ZONE_SIZE.y / 2.0)
	)
	qarin_trigger.set_meta("is_qarin", true)
	qarin_trigger.body_entered.connect(_on_challenge_trigger_entered.bind(qarin_trigger))

	# --- الباب - مخفي تمامًا لحد ما يكسب القرين ---
	_door_area = Area2D.new()
	_door_area.name = "DoorTrigger"
	_door_area.position = Vector2(platform_left_x + DOOR_OFFSET_X, platform_top_y - 40.0)
	var door_shape := CollisionShape2D.new()
	var door_rect := RectangleShape2D.new()
	door_rect.size = Vector2(60, 110)
	door_shape.shape = door_rect
	_door_area.add_child(door_shape)
	_door_area.monitoring = false
	_door_area.body_entered.connect(_on_door_entered)
	add_child(_door_area)

	_door_visual = AnimatedSprite2D.new()
	_door_visual.sprite_frames = _build_door_sprite_frames()
	_door_visual.animation = "open"
	_door_visual.frame = 0
	_door_visual.position = _door_area.position
	_door_visual.scale = Vector2.ONE * DOOR_VISUAL_SCALE
	_door_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_door_visual.modulate.a = 0.0
	_door_visual.z_index = -2
	add_child(_door_visual)

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

func _on_ladder_entered(body: Node2D) -> void:
	if body.name == "Player" and body.has_method("set_climbing"):
		body.set_climbing(true)


func _on_ladder_exited(body: Node2D) -> void:
	if body.name == "Player" and body.has_method("set_climbing"):
		body.set_climbing(false)


# ---------------------------------------------------------------------------
# تشغيل التحديات + آلية الأذان
# ---------------------------------------------------------------------------

func _on_challenge_trigger_entered(body: Node2D, trigger: Area2D) -> void:
	if body.name != "Player":
		return
	if _active_challenge_stage != null:
		return

	GameAudio.stop_all()
	_revive_demons()

	trigger.set_deferred("monitoring", false)
	player.is_in_challenge = true
	_active_trigger = trigger
	_is_qarin_challenge = trigger.has_meta("is_qarin")

	_deadline_active = false
	_danger_overlay.color.a = 0.0
	_hide_timer_label()
	_main_already_succeeded = false

	var stage: StageBase
	if _is_qarin_challenge:
		stage = QarinStage.new()
	else:
		var idx: int = trigger.get_meta("stage_index")
		var entry: Dictionary = NIGHT_STAGES[idx]
		stage = entry["factory"].call()
		_time_total = entry["duration"]

	_active_challenge_stage = stage
	add_child(stage)
	stage.mistake_made.connect(_on_mistake)
	stage.progress_made.connect(_on_progress)
	stage.main_challenge_finished.connect(_on_main_challenge_finished)
	stage.challenge_started.connect(_on_stage_challenge_started)
	if _is_qarin_challenge:
		stage.stage_completed.connect(_on_qarin_victory)
	else:
		stage.stage_completed.connect(_on_challenge_success)
	stage.run()


## بتتنادى من StageBase.challenge_started - لحظة ما السرد يخلص فعليًا والتحدي
## يبدأ. هنا بالظبط نبدأ عدّ المهلة، مش أول ما التريجر يتلمس.
func _on_stage_challenge_started() -> void:
	if _is_qarin_challenge:
		return
	_time_remaining = _time_total
	_deadline_active = true
	_show_timer_label()


## بتتنادى لما اللاعب ينجح في التحدي الأساسي. مبقتش بتوقف المهلة ولا تشغّل
## الأذان فورًا - بس بتسجّل إنه نجح، والوقت الأصلي فاضل يعد عادي. لو فيه بونص
## هيشتغل دلوقتي، وهو اللي هيقرر مصيره حسب الوقت المتبقي.
func _on_main_challenge_finished() -> void:
	_main_already_succeeded = true


func _play_adhan_cue() -> void:
	if _active_trigger == null or _is_qarin_challenge:
		return
	var idx: int = _active_trigger.get_meta("stage_index")
	_flash_adhan_name(NIGHT_STAGES[idx]["adhan_name"])
	GameAudio.play_checkpoint(checkpoint_sound, 6.0)


func _on_stage_time_up() -> void:
	if _is_dying or not _deadline_active:
		return
	_deadline_active = false
	_danger_overlay.color.a = 0.0
	_hide_timer_label()
	_play_adhan_cue()

	if _main_already_succeeded:
		## خلص التحدي الأساسي بالفعل - أي بونص شغال بيتقفل فورًا من غير خسارة
		## حياة، والمرحلة تتحسب ناجحة عادي.
		if _active_challenge_stage:
			_active_challenge_stage.interrupt()
		_finish_stage_as_success()
		return

	if _active_challenge_stage:
		_active_challenge_stage.interrupt()
	_start_stage_death_sequence_narrated(
		"The adhan echoes through the room, and he's still lost in it... the chains pull him back."
	)


func _on_mistake() -> void:
	if _is_dying:
		return
	GameAudio.play_sfx(mistake_sound)
	_shake_layer(_hud_layer)
	willpower = max(0.0, willpower - mistake_damage)
	_update_willpower_bar()

	demon_proximity = clamp(demon_proximity + demon_proximity_per_mistake, 0.0, 1.0)
	_update_demon_visual()
	if _demon_backdrop:
		_demon_backdrop.flash_mistake()
	if player.has_method("flash_hurt"):
		player.flash_hurt()

	if willpower <= 0.0:
		if _is_qarin_challenge:
			_start_bad_ending_sequence()
		else:
			_deadline_active = false
			_hide_timer_label()
			if _active_challenge_stage:
				_active_challenge_stage.interrupt()
			_start_stage_death_sequence_narrated("The chains pull him back again... not tonight.")


func _on_progress() -> void:
	GameAudio.play_sfx(progress_sound)
	demon_proximity = clamp(demon_proximity - demon_proximity_per_progress, 0.0, 1.0)
	_update_demon_visual()
	if _demon_backdrop:
		_demon_backdrop.flash_progress()


func _on_challenge_success() -> void:
	var trigger: Area2D = _active_trigger
	var stage: StageBase = _active_challenge_stage

	if _deadline_active:
		_deadline_active = false
		_danger_overlay.color.a = 0.0
		_hide_timer_label()
		_play_adhan_cue()

	_active_challenge_stage = null
	_active_trigger = null
	_main_already_succeeded = false

	await _burn_demons()

	last_checkpoint_position = trigger.global_position
	if trigger.has_meta("arrow"):
		var arrow: Node2D = trigger.get_meta("arrow")
		if is_instance_valid(arrow):
			var tw_arrow: Tween = create_tween()
			tw_arrow.tween_property(arrow, "modulate:a", 0.0, 0.4)
	player.is_in_challenge = false
	if is_instance_valid(stage):
		stage.queue_free()

## بتتنادى بس لما الوقت يخلص وهو أصلاً نجح في التحدي الأساسي (يعني كان بيحاول
## في البونص). بتقفل البونص فورًا وتتعامل مع المرحلة كأنها نجحت عادي، من غير
## أي خسارة حياة.
func _finish_stage_as_success() -> void:
	var trigger: Area2D = _active_trigger
	var stage: StageBase = _active_challenge_stage
	_active_challenge_stage = null
	_active_trigger = null
	_main_already_succeeded = false

	await _burn_demons()

	if trigger:
		last_checkpoint_position = trigger.global_position
		if trigger.has_meta("arrow"):
			var arrow: Node2D = trigger.get_meta("arrow")
			if is_instance_valid(arrow):
				var tw_arrow: Tween = create_tween()
				tw_arrow.tween_property(arrow, "modulate:a", 0.0, 0.4)
	player.is_in_challenge = false
	if is_instance_valid(stage):
		stage.queue_free()

func _shake_layer(layer: CanvasLayer, amount: float = 6.0, duration: float = 0.3) -> void:
	if layer == null:
		return
	var tw: Tween = create_tween()
	var steps: int = 6
	for i in range(steps):
		var offset: Vector2 = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
		tw.tween_property(layer, "offset", offset, duration / steps)
	tw.tween_property(layer, "offset", Vector2.ZERO, duration / steps)


# ---------------------------------------------------------------------------
# HUD (إرادة + حيوات + أذان + تايمر المرحلة)
# ---------------------------------------------------------------------------

func _build_hud() -> void:
	if ResourceLoader.exists(CRIMSON_GUI_PATH):
		_crimson_gui_tex = load(CRIMSON_GUI_PATH)
	else:
		print("مش لاقي GUISprite.png - القلوب والبانر هيبانوا فاضيين")

	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 20
	add_child(_hud_layer)

	_darkness_overlay = ColorRect.new()
	_darkness_overlay.color = Color(0, 0, 0, 0.0)
	_darkness_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_darkness_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_layer.add_child(_darkness_overlay)

	_danger_overlay = ColorRect.new()
	_danger_overlay.color = Color(0.6, 0.0, 0.0, 0.0)
	_danger_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_danger_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_layer.add_child(_danger_overlay)

	_willpower_bar = TextureProgressBar.new()
	_willpower_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_willpower_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_willpower_bar.offset_top = 24
	_willpower_bar.offset_bottom = 24 + BAR_EMPTY_REGION.size.y * BAR_SCALE
	_willpower_bar.offset_left = 60
	_willpower_bar.offset_right = -60
	_willpower_bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_willpower_bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	_willpower_bar.nine_patch_stretch = true
	_willpower_bar.stretch_margin_left = BAR_STRETCH_MARGIN
	_willpower_bar.stretch_margin_right = BAR_STRETCH_MARGIN
	_willpower_bar.min_value = 0.0
	_willpower_bar.max_value = willpower_max
	_willpower_bar.value = willpower_max
	if _crimson_gui_tex:
		_willpower_bar.texture_under = _make_atlas(_crimson_gui_tex, BAR_EMPTY_REGION)
		_willpower_bar.texture_progress = _make_atlas(_crimson_gui_tex, BAR_FILLED_REGION)
	_hud_layer.add_child(_willpower_bar)

	_timer_label = Label.new()
	_timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_timer_label.offset_left = -60
	_timer_label.offset_right = 60
	_timer_label.offset_top = 50
	_timer_label.offset_bottom = 90
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 32)
	_timer_label.add_theme_color_override("font_color", _TIMER_NORMAL_COLOR)
	_timer_label.add_theme_font_override("font", GAME_FONT)
	_timer_label.modulate.a = 0.0
	_hud_layer.add_child(_timer_label)

	# --- بانر الأذان: نص + فاصل مزخرف بجوهرة تحته (Crimson Fantasy GUI) ---
	_adhan_container = Control.new()
	_adhan_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_adhan_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_adhan_container.offset_left = -260
	_adhan_container.offset_top = 46
	_adhan_container.offset_right = -20
	_adhan_container.offset_bottom = 100
	_adhan_container.modulate.a = 0.0
	_hud_layer.add_child(_adhan_container)

	_adhan_label = Label.new()
	_adhan_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_adhan_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_adhan_label.offset_top = 0
	_adhan_label.offset_bottom = 28
	_adhan_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_adhan_label.add_theme_font_size_override("font_size", 20)
	_adhan_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6, 0.95))
	_adhan_label.add_theme_font_override("font", GAME_FONT)
	_adhan_container.add_child(_adhan_label)

	_adhan_divider = TextureRect.new()
	_adhan_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_adhan_divider.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_adhan_divider.stretch_mode = TextureRect.STRETCH_SCALE
	_adhan_divider.anchor_left = 0.0
	_adhan_divider.anchor_right = 1.0
	_adhan_divider.offset_left = 40
	_adhan_divider.offset_right = -40
	_adhan_divider.offset_top = 30
	_adhan_divider.offset_bottom = 30 + ADHAN_DIVIDER_REGION.size.y * ADHAN_DIVIDER_SCALE
	if _crimson_gui_tex:
		_adhan_divider.texture = _make_atlas(_crimson_gui_tex, ADHAN_DIVIDER_REGION)
	_adhan_container.add_child(_adhan_divider)

	# --- قلوب الحيوات (Crimson Fantasy GUI) بدل نص ♥♥♥ ---
	_hearts_container = HBoxContainer.new()
	_hearts_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hearts_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hearts_container.offset_left = 20
	_hearts_container.offset_top = 22
	_hearts_container.add_theme_constant_override("separation", 6)
	_hud_layer.add_child(_hearts_container)

	_heart_textures.clear()
	for i in range(max_lives):
		var heart := TextureRect.new()
		heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		heart.custom_minimum_size = HEART_FULL_REGION.size * HEART_ICON_SCALE
		heart.stretch_mode = TextureRect.STRETCH_SCALE
		heart.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if _crimson_gui_tex:
			heart.texture = _make_atlas(_crimson_gui_tex, HEART_FULL_REGION)
		_hearts_container.add_child(heart)
		_heart_textures.append(heart)

	call_deferred("_update_willpower_bar", false)
	_update_lives_hud()


func _make_atlas(tex: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = region
	return atlas


func _update_lives_hud() -> void:
	if _crimson_gui_tex == null:
		return
	for i in range(_heart_textures.size()):
		var region: Rect2 = HEART_FULL_REGION if i < _lives_remaining else HEART_EMPTY_REGION
		_heart_textures[i].texture = _make_atlas(_crimson_gui_tex, region)


## بتتنادى أول ما تريجر مرحلة (غير القرين) يشتغل - بتفضّي التايمر وتفرزه بفيد
## سريع، عشان يبقى واضح إن مهلة جديدة بدأت.
func _show_timer_label() -> void:
	_update_timer_label(0.0)
	var tw: Tween = create_tween()
	tw.tween_property(_timer_label, "modulate:a", 1.0, 0.3)


## بتتنادى لما المهلة تنتهي لأي سبب (نجاح مبكر، فوات الوقت، أو خروج من تحدي).
func _hide_timer_label() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(_timer_label, "modulate:a", 0.0, 0.3)


## بتتنادى كل فريم وقت ما فيه مهلة شغالة - بتحدّث الرقم وتلوّنه من أبيض لأحمر
## كل ما الوقت يقرب يخلص (نفس منحنى _danger_overlay).
func _update_timer_label(danger: float) -> void:
	var seconds_left: int = int(ceil(max(0.0, _time_remaining)))
	var minutes: int = seconds_left / 60
	var secs: int = seconds_left % 60
	_timer_label.text = "%d:%02d" % [minutes, secs]
	_timer_label.add_theme_color_override("font_color", _TIMER_NORMAL_COLOR.lerp(_TIMER_DANGER_COLOR, danger))


func _flash_adhan_name(adhan_name: String) -> void:
	_adhan_label.text = "%s Adhan" % adhan_name
	_adhan_label.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(_adhan_label, "modulate:a", 1.0, 0.4)
	tw.tween_interval(2.0)
	tw.tween_property(_adhan_label, "modulate:a", 0.0, 0.6)


func _update_willpower_bar(animate: bool = true) -> void:
	var target_dark: float = 0.75 * (1.0 - clamp(willpower / willpower_max, 0.0, 1.0))

	if animate:
		var tw: Tween = create_tween()
		tw.set_parallel(true)
		tw.tween_property(_willpower_bar, "value", willpower, 0.25)
		tw.tween_property(_darkness_overlay, "color:a", target_dark, 0.25)
	else:
		_willpower_bar.value = willpower
		_darkness_overlay.color.a = target_dark


# ---------------------------------------------------------------------------
# خلفية الشياطين
# ---------------------------------------------------------------------------

func _build_demon_backdrop() -> void:
	_demon_layer = CanvasLayer.new()
	_demon_layer.layer = 5
	add_child(_demon_layer)

	_demon_backdrop = DemonBackdrop.new()
	_demon_layer.add_child(_demon_backdrop)
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	_demon_backdrop.position = screen_size / 2.0
	_demon_backdrop.setup(screen_size)


func _update_demon_visual() -> void:
	if _demon_backdrop == null:
		return
	var tw: Tween = create_tween()
	tw.tween_method(_demon_backdrop.set_proximity, _demon_backdrop.get_proximity(), demon_proximity, 0.3)


## بتحرق الشياطين (أنيميشن Death) وتسيبهم مختفيين - ملحوظة: مبترجعهمش يظهروا
## تاني هنا؛ _revive_demons() هي المسؤولة عن كده، وبتتنادى بس أول ما تحدي جديد
## يبدأ فعليًا، عشان مايبانوش "راجعين على طول" قدام عين اللاعب.
func _burn_demons() -> void:
	if _demon_backdrop == null:
		return
	GameAudio.play_sfx(demon_burn_sound, -8.0)
	var tw: Tween = create_tween()
	tw.tween_method(_demon_backdrop.set_burn, 0.0, 1.0, 0.8)
	await tw.finished
	demon_proximity = 0.0
	_demon_backdrop.set_proximity(0.0)


## بترجّع الشياطين تظهر تاني (burn=0) - بتتنادى في أول أي تحدي جديد.
func _revive_demons() -> void:
	if _demon_backdrop == null:
		return
	_demon_backdrop.set_burn(0.0)


# ---------------------------------------------------------------------------
# فقدان حياة + معركة القرين + شاشات النهاية
# ---------------------------------------------------------------------------

func _start_stage_death_sequence_narrated(narration: String) -> void:
	await _lose_a_life(narration)


func _lose_a_life(narration: String) -> void:
	_is_dying = true
	_danger_overlay.color.a = 0.0
	_hide_timer_label()

	_lives_remaining -= 1
	_update_lives_hud()
	var is_final_life: bool = _lives_remaining <= 0

	GameAudio.play_narration(narration, null, 2.2)
	await GameAudio.narration_finished

	await _play_chain_pull_visual(not is_final_life)

	demon_proximity = 0.0
	if _demon_backdrop:
		_demon_backdrop.set_proximity(0.0)

	## المرحلة القديمة اتقفلت (interrupt) قبل النداء على الدالة دي، لكن فضلت
	## حية جوه _active_challenge_stage - لازم نحررها ونصفّرها هنا، وإلا أي
	## دخول تاني لأي تريجر هيتجاهل للأبد (الشرط في _on_challenge_trigger_entered
	## هيفضل صح على طول).
	if is_instance_valid(_active_challenge_stage):
		_active_challenge_stage.queue_free()
	_active_challenge_stage = null

	if is_final_life:
		if _demon_backdrop:
			_demon_backdrop.set_burn(1.0)
		await get_tree().create_timer(0.3).timeout
		_show_game_over_screen()
		return

	willpower = willpower_max
	_update_willpower_bar(false)
	player.position = last_checkpoint_position
	if _active_trigger and is_instance_valid(_active_trigger):
		_active_trigger.set_deferred("monitoring", true)
	_active_trigger = null
	_is_qarin_challenge = false
	player.is_in_challenge = false
	_is_dying = false


func _on_qarin_victory() -> void:
	var stage: StageBase = _active_challenge_stage
	var trigger: Area2D = _active_trigger
	_active_challenge_stage = null
	_active_trigger = null
	_is_qarin_challenge = false
	player.is_in_challenge = false
	if is_instance_valid(stage):
		stage.queue_free()
	if trigger and trigger.has_meta("arrow"):
		var arrow: Node2D = trigger.get_meta("arrow")
		if is_instance_valid(arrow):
			var tw_arrow: Tween = create_tween()
			tw_arrow.tween_property(arrow, "modulate:a", 0.0, 0.4)

	_qarin_defeated = true
	await _burn_demons()
	_reveal_door()
	GameAudio.play_narration("He broke free from its grip. Something ahead feels different now.", null, 2.0)

func _reveal_door() -> void:
	_door_area.monitoring = true
	_door_visual.play("open")
	var tw: Tween = create_tween()
	tw.tween_property(_door_visual, "modulate:a", 1.0, 1.2)


func _on_door_entered(body: Node2D) -> void:
	if body.name != "Player" or not _qarin_defeated or _ending_active:
		return
	player.is_in_challenge = true
	GameAudio.play_narration("He steps through, and the chains finally fall away.", null, 2.2)
	await GameAudio.narration_finished
	await get_tree().create_timer(0.3).timeout
	_show_good_ending_screen()


func _start_bad_ending_sequence() -> void:
	_is_dying = true
	if _active_challenge_stage:
		_active_challenge_stage.interrupt()

	GameAudio.play_narration("The qarin's voice wins this time. He stops fighting it, and the chains don't pull him back anymore.", null, 2.2)
	await GameAudio.narration_finished

	await _play_chain_pull_visual(false)

	demon_proximity = 0.0
	if _demon_backdrop:
		_demon_backdrop.set_proximity(0.0)
		_demon_backdrop.set_burn(1.0)

	if is_instance_valid(_active_challenge_stage):
		_active_challenge_stage.queue_free()
	_active_challenge_stage = null

	await get_tree().create_timer(0.3).timeout
	_show_bad_ending_screen()


func _play_chain_pull_visual(fade_back: bool = true) -> ColorRect:
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_layer.add_child(fade)

	var chains := ChainPullVisual.new()
	_hud_layer.add_child(chains)
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	chains.position = screen_size / 2.0
	chains.setup(screen_size)

	GameAudio.play_sfx(chain_drag_sound)

	var tw: Tween = create_tween()
	tw.tween_property(fade, "color:a", 1.0, 1.4)
	tw.parallel().tween_method(chains.set_progress, 0.0, 1.0, 1.4)
	await tw.finished

	await get_tree().create_timer(0.5).timeout
	chains.queue_free()

	if not fade_back:
		return fade

	var tw2: Tween = create_tween()
	tw2.tween_property(fade, "color:a", 0.0, 0.6)
	await tw2.finished
	fade.queue_free()
	return null


func _show_game_over_screen() -> void:
	_show_ending_screen("GAME OVER", "", Color(1.0, 0.15, 0.15, 1.0), "Press Space to try again")


func _show_bad_ending_screen() -> void:
	_show_ending_screen("THE END", "He let go, and stopped fighting.", Color(0.55, 0.05, 0.05, 1.0), "Press Space to try again")


func _show_good_ending_screen() -> void:
	_show_ending_screen("FREE", "He held on, and broke the chains.", Color(1.0, 0.92, 0.65, 1.0), "Press Space to play again")


func _show_ending_screen(title_text: String, subtitle_text: String, title_color: Color, hint_text: String) -> void:
	var label := Label.new()
	label.text = title_text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", title_color)
	label.add_theme_font_override("font", GAME_FONT)
	label.offset_left = -300
	label.offset_right = 300
	label.offset_top = -100
	label.offset_bottom = -40
	label.modulate.a = 0.0
	_hud_layer.add_child(label)

	var subtitle: Label = null
	if subtitle_text != "":
		subtitle = Label.new()
		subtitle.text = subtitle_text
		subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		subtitle.set_anchors_preset(Control.PRESET_CENTER)
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		subtitle.add_theme_font_size_override("font_size", 22)
		subtitle.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
		subtitle.add_theme_font_override("font", GAME_FONT)
		subtitle.offset_left = -300
		subtitle.offset_right = 300
		subtitle.offset_top = -30
		subtitle.offset_bottom = 5
		subtitle.modulate.a = 0.0
		_hud_layer.add_child(subtitle)

	var hint := Label.new()
	hint.text = hint_text
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.set_anchors_preset(Control.PRESET_CENTER)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	hint.add_theme_font_override("font", GAME_FONT)
	hint.offset_left = -300
	hint.offset_right = 300
	hint.offset_top = 40
	hint.offset_bottom = 75
	hint.modulate.a = 0.0
	_hud_layer.add_child(hint)

	var tw: Tween = create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.6)
	tw.parallel().tween_property(hint, "modulate:a", 1.0, 0.6)
	if subtitle:
		tw.parallel().tween_property(subtitle, "modulate:a", 1.0, 0.6)

	_ending_active = true


# ---------------------------------------------------------------------------
# فيجوالز: سلم + باب + سلاسل
# ---------------------------------------------------------------------------

class LadderVisual extends Node2D:
	var _w: float = 40.0
	var _h: float = 260.0

	func setup(w: float, h: float) -> void:
		_w = w
		_h = h
		queue_redraw()

	func _draw() -> void:
		var half_h: float = _h / 2.0
		var rail_color: Color = Color(0.45, 0.32, 0.18, 0.95)
		draw_line(Vector2(-_w / 2.0, -half_h), Vector2(-_w / 2.0, half_h), rail_color, 5.0)
		draw_line(Vector2(_w / 2.0, -half_h), Vector2(_w / 2.0, half_h), rail_color, 5.0)
		var rung_count: int = int(_h / 28.0)
		for i in range(rung_count):
			var y: float = -half_h + 14.0 + i * 28.0
			draw_line(Vector2(-_w / 2.0, y), Vector2(_w / 2.0, y), rail_color, 4.0)


class TriggerArrow extends Node2D:
	var _base_y: float = 0.0
	var _t: float = 0.0

	func setup(base_y: float) -> void:
		_base_y = base_y
		_t = randf() * TAU
		position.y = base_y

	func _process(delta: float) -> void:
		_t += delta * 3.0
		position.y = _base_y + sin(_t) * 6.0
		queue_redraw()

	func _draw() -> void:
		var w: float = 12.0
		var h: float = 16.0
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(-w, -h), Vector2(w, -h), Vector2(0.0, 0.0),
		])
		draw_colored_polygon(pts, Color(1.0, 0.92, 0.55, 0.85))
		draw_polyline(PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(0.0, 0.0), Vector2(-w, -h)]), Color(0.55, 0.4, 0.15, 0.9), 2.0, true)

## رسم بصري لسلاسل حقيقية (chains.png) بتتقفل من زوايا الشاشة الأربعة على النص.
## لو الملف مش موجود، بيرجع تلقائيًا لرسم الحلقات القديم (دواير) كـ fallback.
class ChainPullVisual extends Node2D:
	const CHAIN_TEX_PATH: String = "res://effects/chains.png"
	## منطقة حلقة واحدة قابلة للتكرار (اللون الفضي) جوه chains.png - اتأكدنا
	## إنها متكررة بشكل متطابق تمامًا كل 5 بكسل رأسيًا (seamless).
	const LINK_SRC: Rect2 = Rect2(2, 0, 5, 5)
	const LINK_SCALE: float = 6.0

	var _progress: float = 0.0
	var _chain_tex: Texture2D = null
	var _corners: Array[Vector2] = []
	var _directions: Array[Vector2] = []
	var _angles: Array[float] = []

	func setup(screen_size: Vector2) -> void:
		if ResourceLoader.exists(CHAIN_TEX_PATH):
			_chain_tex = load(CHAIN_TEX_PATH)
		else:
			print("مش لاقي chains.png - هيتستخدم شكل دواير بديل")

		var half: Vector2 = screen_size / 2.0
		_corners = [
			Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
			Vector2(-half.x, half.y), Vector2(half.x, half.y),
		]
		_directions.clear()
		_angles.clear()
		for corner in _corners:
			var dir: Vector2 = (Vector2.ZERO - corner).normalized()
			_directions.append(dir)
			_angles.append(dir.angle() - PI / 2.0)
		queue_redraw()

	func set_progress(p: float) -> void:
		_progress = p
		queue_redraw()

	func _draw() -> void:
		for i in range(_corners.size()):
			var corner: Vector2 = _corners[i]
			var direction: Vector2 = _directions[i]
			var head: Vector2 = corner.lerp(Vector2.ZERO, _progress)
			if _chain_tex:
				_draw_chain_texture(corner, direction, _angles[i], corner.distance_to(head))
			else:
				_draw_chain_fallback(corner, head)

	## بيكرر حلقة السلسلة الحقيقية على طول الخط من الركن لحد نقطة السحب الحالية
	## (head)، مدوّرة عشان تتجه ناحية نص الشاشة بالظبط.
	func _draw_chain_texture(corner: Vector2, direction: Vector2, angle: float, dist: float) -> void:
		var link_step: float = LINK_SRC.size.y * LINK_SCALE
		var link_count: int = int(dist / link_step)
		var draw_size: Vector2 = LINK_SRC.size * LINK_SCALE
		for i in range(link_count):
			var link_pos: Vector2 = corner + direction * (link_step * (i + 0.5))
			draw_set_transform(link_pos, angle, Vector2.ONE)
			draw_texture_rect_region(_chain_tex, Rect2(-draw_size / 2.0, draw_size), LINK_SRC)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw_chain_fallback(corner: Vector2, head: Vector2) -> void:
		var link_count: int = 6
		for i in range(link_count):
			var t: float = float(i) / float(link_count - 1)
			var link_pos: Vector2 = corner.lerp(head, t)
			draw_circle(link_pos, 8.0, Color(0.12, 0.12, 0.12, 0.9))
			draw_arc(link_pos, 8.0, 0.0, TAU, 12, Color(0.45, 0.45, 0.45, 0.6), 2.0, true)

# ---------------------------------------------------------------------------
# خلفية الشياطين - سبرايت حقيقي (Flying Demon Pack)
# ---------------------------------------------------------------------------

class DemonUnit extends Node2D:
	const FRAME_W: int = 79
	const FRAME_H: int = 69

	var _anims: Dictionary = {}
	var _sprite: Sprite2D
	var _corner: Vector2 = Vector2.ZERO
	var _base_scale: float = 1.0
	var _proximity: float = 0.0
	var _burn: float = 0.0

	var _current_anim: String = ""
	var _one_shot: bool = false
	var _frame_index: int = 0
	var _frame_timer: float = 0.0

	func setup(anims: Dictionary, corner: Vector2, base_scale: float) -> void:
		_anims = anims
		_corner = corner
		_base_scale = base_scale
		position = corner

		_sprite = Sprite2D.new()
		_sprite.centered = true
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.flip_h = corner.x > 0.0
		add_child(_sprite)

		_set_anim("flying", false)
		_update_modulate()

	func update_proximity(p: float, screen_size: Vector2) -> void:
		_proximity = p
		position = _corner.lerp(Vector2.ZERO, p * 0.75)
		scale = Vector2.ONE * (_base_scale * (1.0 + p * 0.6))
		_update_modulate()

	func update_burn(b: float) -> void:
		_burn = b
		_update_modulate()
		visible = b < 1.0

	func play_attack() -> void:
		if _current_anim == "death":
			return
		_set_anim("attack", true)

	func play_hurt() -> void:
		if _current_anim == "death":
			return
		_set_anim("hurt", true)

	func play_death() -> void:
		_set_anim("death", true)

	func _process(delta: float) -> void:
		if not _anims.has(_current_anim):
			return
		var data: Dictionary = _anims[_current_anim]
		_frame_timer += delta
		var frame_duration: float = 1.0 / data["fps"]
		if _frame_timer >= frame_duration:
			_frame_timer -= frame_duration
			_frame_index += 1
			if _frame_index >= data["frame_count"]:
				if _one_shot:
					_frame_index = data["frame_count"] - 1
					_update_frame()
					if _current_anim == "attack" or _current_anim == "hurt":
						_set_anim("flying", false)
					return
				else:
					_frame_index = 0
			_update_frame()

	func _set_anim(anim_name: String, one_shot: bool) -> void:
		if not _anims.has(anim_name):
			return
		if _current_anim == anim_name and _one_shot == one_shot:
			return
		_current_anim = anim_name
		_one_shot = one_shot
		_frame_index = 0
		_frame_timer = 0.0
		_update_frame()

	func _update_frame() -> void:
		var data: Dictionary = _anims[_current_anim]
		var tex: Texture2D = data["texture"]
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(_frame_index * FRAME_W, 0, FRAME_W, FRAME_H)
		_sprite.texture = atlas

	func _update_modulate() -> void:
		var alpha: float = (0.15 + 0.55 * _proximity) * (1.0 - _burn)
		var shadow_color: Color = Color(0.05, 0.02, 0.08)
		var lit_color: Color = shadow_color.lerp(Color(1, 1, 1), _proximity * 0.45)
		var final_color: Color = lit_color.lerp(Color(1.0, 0.55, 0.15), _burn)
		modulate = Color(final_color.r, final_color.g, final_color.b, alpha)


class DemonBackdrop extends Node2D:
	const DEMON_SCALE: float = 1.7

	var _anims: Dictionary = {}
	var _demons: Array[DemonUnit] = []
	var _proximity: float = 0.0
	var _burn: float = 0.0
	var _screen_size: Vector2 = Vector2.ZERO

	func setup(screen_size: Vector2) -> void:
		_screen_size = screen_size
		_load_animations()

		var half: Vector2 = screen_size / 2.0
		var corners: Array[Vector2] = [
			Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
			Vector2(-half.x, half.y), Vector2(half.x, half.y),
		]
		for corner in corners:
			var unit := DemonUnit.new()
			add_child(unit)
			unit.setup(_anims, corner, DEMON_SCALE)
			unit.update_proximity(0.0, screen_size)
			_demons.append(unit)

	func _load_animations() -> void:
		_load_anim("flying", "res://demons/without_outline/FLYING.png", 4, 8.0)
		_load_anim("idle", "res://demons/without_outline/IDLE.png", 4, 6.0)
		_load_anim("attack", "res://demons/without_outline/ATTACK.png", 8, 12.0)
		_load_anim("hurt", "res://demons/without_outline/HURT.png", 4, 10.0)
		_load_anim("death", "res://demons/without_outline/DEATH.png", 7, 9.0)

	func _load_anim(id: String, path: String, frame_count: int, fps: float) -> void:
		if not ResourceLoader.exists(path):
			print("مش لاقي شيت الشيطان: ", path)
			return
		var tex: Texture2D = load(path)
		if tex == null:
			return
		_anims[id] = {"texture": tex, "frame_count": frame_count, "fps": fps}

	func set_proximity(p: float) -> void:
		_proximity = clamp(p, 0.0, 1.0)
		for d in _demons:
			d.update_proximity(_proximity, _screen_size)

	func get_proximity() -> float:
		return _proximity

	func set_burn(b: float) -> void:
		var was_zero: bool = _burn <= 0.0
		_burn = clamp(b, 0.0, 1.0)
		if was_zero and _burn > 0.0:
			for d in _demons:
				d.play_death()
		for d in _demons:
			d.update_burn(_burn)

	func flash_mistake() -> void:
		for d in _demons:
			d.play_hurt()

	func flash_progress() -> void:
		for d in _demons:
			d.play_attack()
