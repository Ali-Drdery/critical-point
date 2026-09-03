class_name QarinStage
extends StageBase
## معركة القرين - آخر مواجهة في الليل. مزيج من ميكانيكتين اتعلمهم قبل كده في نفس
## الوقت: تفاعل مع كيوهات "ذكر/وهم" (زي Temptation) + مزامنة رفع وزن بإيدين
## (زي Boredom) - الاتنين شغالين مع بعض بالتوازي وبيتسارعوا مع كل نجاح، عشان
## يحس اللاعب إن القرين بيضغط عليه من كل الاتجاهات مرة واحدة. مفيش bonus هنا -
## تحدي واحد متواصل. النجاح الكلي = عدد معين من "نجاحات" (كيو أو مزامنة) مجمّعة
## مع بعض؛ أي غلطة في أي حتة بتاخد من الإرادة زي أي مرحلة تانية (عن طريق
## mistake_made العادية اللي night.gd متوصل بيها بالفعل).

const _TOTAL_TARGET: int = 14

# --- كيو (ذكر/وهم) ---
const _CUE_MIN: float = 0.85
const _CUE_MAX: float = 1.4
const _GAP_MIN: float = 0.5
const _GAP_MAX: float = 0.9
const _DANGER_ZONE_THRESHOLD: float = 0.5
const _FLIP_MIN_INTERVAL: float = 0.18
const _FLIP_MAX_INTERVAL: float = 0.35

# --- مزامنة (شمال/يمين) ---
const _LEFT_PERIOD: float = 1.1
const _RIGHT_PERIOD: float = 1.35
const _ZONE_WIDTH: float = 0.24
const _SYNC_WINDOW: float = 0.32

## كل نجاح (سواء كيو أو مزامنة) بيسرّع الاتنين مع بعض، لحد سقف أدنى.
const _SPEED_STEP: float = 0.045
const _MIN_SPEED_MULT: float = 0.5

var _layer: CanvasLayer
var _visual: Node2D

var _successes: int = 0
var _speed_mult: float = 1.0
var _active: bool = false

# حالة الكيو
var _cue: String = ""
var _cue_time_left: float = 0.0
var _cue_duration: float = 1.0
var _cue_responded: bool = false
var _gap_time_left: float = 0.0
var _in_danger_zone: bool = false
var _flip_timer: float = 0.0

# حالة المزامنة
var _left_phase: float = 0.0
var _right_phase: float = 0.0
var _left_ready: bool = false
var _right_ready: bool = false
var _left_ready_time_ms: int = 0
var _right_ready_time_ms: int = 0


func _init() -> void:
	stage_name = "Qarin"
	narration_text = "The qarin doesn't whisper anymore - it screams from every direction at once. Memories, urges, weakness, all pulling at him together. He has to hold on to himself through all of it, or lose himself completely."
	key_hints = ["space", "left", "right"]

func _start_challenge() -> void:
	_build_visual()
	_successes = 0
	_speed_mult = 1.0
	_active = true

	_cue = ""
	_gap_time_left = randf_range(_GAP_MIN, _GAP_MAX)

	_left_phase = 0.0
	_right_phase = 0.4
	_left_ready = false
	_right_ready = false

	_visual.set_hint("Hold on...")
	set_process(true)
	set_process_unhandled_input(true)


func _process(delta: float) -> void:
	if not _active:
		return
	_process_cue(delta)
	_process_sync(delta)


# ---------------------------------------------------------------------------
# كيو (ذكر/وهم)
# ---------------------------------------------------------------------------

func _process_cue(delta: float) -> void:
	if _cue == "":
		_gap_time_left -= delta
		if _gap_time_left <= 0.0:
			_spawn_cue()
		return

	_cue_time_left -= delta
	var progress: float = clamp(_cue_time_left / _cue_duration, 0.0, 1.0)
	_visual.set_cue_progress(progress, _in_danger_zone)

	if not _cue_responded:
		if not _in_danger_zone and progress <= _DANGER_ZONE_THRESHOLD:
			_in_danger_zone = true
			_flip_timer = randf_range(_FLIP_MIN_INTERVAL, _FLIP_MAX_INTERVAL) * _speed_mult
		if _in_danger_zone:
			_flip_timer -= delta
			if _flip_timer <= 0.0:
				_cue = "illusion" if _cue == "azkar" else "azkar"
				_visual.set_cue_type(_cue)
				_visual.flash_cue_flip()
				_flip_timer = randf_range(_FLIP_MIN_INTERVAL, _FLIP_MAX_INTERVAL) * _speed_mult

	if _cue_time_left <= 0.0:
		if _cue == "azkar" and not _cue_responded:
			_register_mistake()
			_visual.flash_cue_wrong()
		elif _cue == "illusion" and not _cue_responded:
			_on_success()
		_end_cue()


func _spawn_cue() -> void:
	_cue = "azkar" if randf() < 0.55 else "illusion"
	_cue_responded = false
	_in_danger_zone = false
	_flip_timer = 0.0
	_cue_duration = randf_range(_CUE_MIN, _CUE_MAX) * _speed_mult
	_cue_time_left = _cue_duration
	_visual.show_cue(_cue)


func _end_cue() -> void:
	_cue = ""
	_in_danger_zone = false
	_flip_timer = 0.0
	_gap_time_left = randf_range(_GAP_MIN, _GAP_MAX) * _speed_mult
	_visual.hide_cue()


func _try_cue() -> void:
	if _cue == "" or _cue_responded:
		return
	_cue_responded = true
	if _cue == "azkar":
		_on_success()
	else:
		_register_mistake()
		_visual.flash_cue_wrong()
	_end_cue()


# ---------------------------------------------------------------------------
# مزامنة (شمال/يمين)
# ---------------------------------------------------------------------------

func _process_sync(delta: float) -> void:
	_left_phase = fmod(_left_phase + delta / (_LEFT_PERIOD * _speed_mult), 1.0)
	_right_phase = fmod(_right_phase + delta / (_RIGHT_PERIOD * _speed_mult), 1.0)

	var left_pos: float = 0.5 - 0.5 * cos(_left_phase * TAU)
	var right_pos: float = 0.5 - 0.5 * cos(_right_phase * TAU)
	var left_in_zone: bool = left_pos >= (1.0 - _ZONE_WIDTH)
	var right_in_zone: bool = right_pos >= (1.0 - _ZONE_WIDTH)
	_visual.update_arms(left_pos, right_pos, left_in_zone, right_in_zone)

	if _left_ready and (Time.get_ticks_msec() - _left_ready_time_ms) / 1000.0 > _SYNC_WINDOW:
		_left_ready = false
		_register_mistake()
		_visual.flash_arm_wrong("left")
	if _right_ready and (Time.get_ticks_msec() - _right_ready_time_ms) / 1000.0 > _SYNC_WINDOW:
		_right_ready = false
		_register_mistake()
		_visual.flash_arm_wrong("right")


func _try_hand(hand: String) -> void:
	var phase: float = _left_phase if hand == "left" else _right_phase
	var pos: float = 0.5 - 0.5 * cos(phase * TAU)
	var in_zone: bool = pos >= (1.0 - _ZONE_WIDTH)

	if not in_zone:
		_register_mistake()
		_visual.flash_arm_wrong(hand)
		return

	if hand == "left":
		_left_ready = true
		_left_ready_time_ms = Time.get_ticks_msec()
	else:
		_right_ready = true
		_right_ready_time_ms = Time.get_ticks_msec()

	_visual.flash_arm_ready(hand)

	if _left_ready and _right_ready:
		var diff_sec: float = abs(_left_ready_time_ms - _right_ready_time_ms) / 1000.0
		if diff_sec <= _SYNC_WINDOW:
			_left_ready = false
			_right_ready = false
			_visual.flash_sync_correct()
			_on_success()


# ---------------------------------------------------------------------------
# إدخال + تقدّم عام
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_accept"):
		_try_cue()
	elif event.is_action_pressed("ui_left"):
		_try_hand("left")
	elif event.is_action_pressed("ui_right"):
		_try_hand("right")


func _on_success() -> void:
	_register_progress()
	_successes += 1
	_speed_mult = max(_MIN_SPEED_MULT, _speed_mult - _SPEED_STEP)
	_visual.set_hint("%d / %d" % [_successes, _TOTAL_TARGET])

	if _successes >= _TOTAL_TARGET:
		_active = false
		_finish_challenge()


func interrupt() -> void:
	super()
	_active = false


func _cleanup_visual() -> void:
	if _layer:
		_layer.queue_free()
		_layer = null


func _build_visual() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)

	_visual = QarinVisual.new()
	_layer.add_child(_visual)
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	_visual.position = screen_size / 2.0
	_visual.setup()


class QarinVisual extends Node2D:
	const SPRITE_SCALE: float = 3.0

	var _idle_tex: Texture2D
	var _attack_tex: Texture2D
	var _defeat_tex: Texture2D
	var _sprite: Sprite2D
	var _attack_flash_timer: float = 0.0

	# كيو
	var _cue: String = ""
	var _cue_progress: float = 1.0
	var _cue_in_danger: bool = false
	var _cue_flash_timer: float = 0.0
	var _cue_flash_color: Color = Color(0, 0, 0, 0)
	var _cue_flip_timer: float = 0.0

	# مزامنة
	var _left_pos: float = 0.0
	var _right_pos: float = 0.0
	var _left_in_zone: bool = false
	var _right_in_zone: bool = false
	var _flash_left_timer: float = 0.0
	var _flash_right_timer: float = 0.0
	var _flash_left_color: Color = Color(0, 0, 0, 0)
	var _flash_right_color: Color = Color(0, 0, 0, 0)

	var _sync_flash_timer: float = 0.0
	var _hint: String = ""

	func setup() -> void:
		if ResourceLoader.exists("res://qarin/qarin_idle.png"):
			_idle_tex = load("res://qarin/qarin_idle.png")
		if ResourceLoader.exists("res://qarin/qarin_attack.png"):
			_attack_tex = load("res://qarin/qarin_attack.png")
		if ResourceLoader.exists("res://qarin/qarin_defeat.png"):
			_defeat_tex = load("res://qarin/qarin_defeat.png")

		_sprite = Sprite2D.new()
		_sprite.centered = true
		_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.position = Vector2(0, -30)
		_sprite.texture = _idle_tex
		add_child(_sprite)

	func play_defeat_pose() -> void:
		if _sprite and _defeat_tex:
			_sprite.texture = _defeat_tex

	func _process(delta: float) -> void:
		if _attack_flash_timer > 0.0:
			_attack_flash_timer = max(0.0, _attack_flash_timer - delta)
			if _sprite and _attack_tex:
				_sprite.texture = _attack_tex
		elif _sprite and _idle_tex:
			_sprite.texture = _idle_tex

		if _cue_flash_timer > 0.0:
			_cue_flash_timer = max(0.0, _cue_flash_timer - delta)
		if _cue_flip_timer > 0.0:
			_cue_flip_timer = max(0.0, _cue_flip_timer - delta)
		if _flash_left_timer > 0.0:
			_flash_left_timer = max(0.0, _flash_left_timer - delta)
		if _flash_right_timer > 0.0:
			_flash_right_timer = max(0.0, _flash_right_timer - delta)
		if _sync_flash_timer > 0.0:
			_sync_flash_timer = max(0.0, _sync_flash_timer - delta)
		queue_redraw()

	func set_hint(text: String) -> void:
		_hint = text

	func show_cue(cue: String) -> void:
		_cue = cue
		_cue_progress = 1.0
		_cue_in_danger = false
		if cue == "illusion":
			_attack_flash_timer = 0.4

	func set_cue_type(cue: String) -> void:
		_cue = cue

	func hide_cue() -> void:
		_cue = ""
		_cue_in_danger = false

	func set_cue_progress(p: float, in_danger: bool) -> void:
		_cue_progress = p
		_cue_in_danger = in_danger

	func flash_cue_wrong() -> void:
		_cue_flash_color = Color(1.0, 0.15, 0.15, 0.6)
		_cue_flash_timer = 0.25

	func flash_cue_flip() -> void:
		_cue_flip_timer = 0.2

	func update_arms(left_pos: float, right_pos: float, left_in_zone: bool, right_in_zone: bool) -> void:
		_left_pos = left_pos
		_right_pos = right_pos
		_left_in_zone = left_in_zone
		_right_in_zone = right_in_zone

	func flash_arm_ready(hand: String) -> void:
		if hand == "left":
			_flash_left_color = Color(0.4, 0.75, 1.0, 0.7)
			_flash_left_timer = 0.2
		else:
			_flash_right_color = Color(0.4, 0.75, 1.0, 0.7)
			_flash_right_timer = 0.2

	func flash_arm_wrong(hand: String) -> void:
		if hand == "left":
			_flash_left_color = Color(1.0, 0.15, 0.15, 0.7)
			_flash_left_timer = 0.25
		else:
			_flash_right_color = Color(1.0, 0.15, 0.15, 0.7)
			_flash_right_timer = 0.25

	func flash_sync_correct() -> void:
		_sync_flash_timer = 0.3
		_attack_flash_timer = 0.3

	func _draw() -> void:
		if _sync_flash_timer > 0.0:
			var a: float = _sync_flash_timer / 0.3
			draw_circle(Vector2(0, -30), 170.0, Color(0.35, 1.0, 0.5, 0.35 * a))
		if _cue_flash_timer > 0.0:
			var a2: float = _cue_flash_timer / 0.25
			draw_circle(Vector2(0, -30), 170.0, Color(_cue_flash_color.r, _cue_flash_color.g, _cue_flash_color.b, _cue_flash_color.a * a2))

		if _cue != "":
			var cue_color: Color = Color(0.35, 0.85, 0.55, 0.9) if _cue == "azkar" else Color(0.55, 0.15, 0.65, 0.9)
			if _cue_flip_timer > 0.0:
				cue_color = cue_color.lerp(Color(1, 1, 1, 0.9), _cue_flip_timer / 0.2)
			draw_circle(Vector2(0, -140), 20.0, cue_color)
			draw_arc(Vector2(0, -140), 30.0, 0.0, TAU * _cue_progress, 40, Color(1, 1, 1, 0.85), 3.0, true)

			var danger_pulse: float = 1.0
			if _cue_in_danger:
				danger_pulse = 0.75 + 0.25 * sin(Time.get_ticks_msec() / 70.0)
			var marker_alpha: float = (0.9 if _cue_in_danger else 0.4) * danger_pulse
			draw_line(Vector2(36, -140), Vector2(36 + (18.0 if _cue_in_danger else 10.0), -140), Color(1.0, 0.15, 0.1, marker_alpha), 3.0)

		_draw_arm(Vector2(-170, 40), _left_pos, _left_in_zone, _flash_left_color, _flash_left_timer, "L")
		_draw_arm(Vector2(170, 40), _right_pos, _right_in_zone, _flash_right_color, _flash_right_timer, "R")
		_draw_hint()

	func _draw_arm(base_pos: Vector2, pos_pct: float, in_zone: bool, flash_color: Color, flash_timer: float, label: String) -> void:
		var track_h: float = 130.0
		var track_w: float = 20.0
		var top: Vector2 = base_pos + Vector2(0, -track_h / 2.0)
		draw_rect(Rect2(top - Vector2(track_w / 2.0, 0), Vector2(track_w, track_h)), Color(0, 0, 0, 0.45))

		var zone_h: float = track_h * 0.26
		var zone_color: Color = Color(0.4, 0.9, 0.5, 0.55) if in_zone else Color(0.9, 0.75, 0.3, 0.35)
		draw_rect(Rect2(top - Vector2(track_w / 2.0, 0), Vector2(track_w, zone_h)), zone_color)

		var marker_y: float = top.y + track_h * (1.0 - pos_pct)
		var marker_color: Color = flash_color if flash_timer > 0.0 else Color(0.9, 0.9, 0.9, 0.95)
		draw_circle(Vector2(base_pos.x, marker_y), 12.0, marker_color)

		var font: Font = ThemeDB.fallback_font
		draw_string(font, base_pos + Vector2(-8, track_h / 2.0 + 24), label, HORIZONTAL_ALIGNMENT_CENTER, 40, 20, Color(1, 1, 1, 0.85))

	func _draw_hint() -> void:
		if _hint == "":
			return
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(-150, 170), _hint, HORIZONTAL_ALIGNMENT_CENTER, 300, 20, Color(1, 1, 1, 0.85))
