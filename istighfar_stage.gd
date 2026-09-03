class_name IstighfarStage
extends StageBase
## مرحلة الاستغفار: تحدي إيقاعي (زي التسبيح الحقيقي).
## سبحة كاملة (7 حبات) مرسومة على شكل حلقة بخيط، وفيها "شرابة" متدلية زي السبحة
## الحقيقية. الحبة اللي دورها يجيلها بتنبض بهدوء، واللاعب يضغط مسطرة (ui_accept)
## في اللحظة اللي هي فيها في أعلى قمة لمعانها. كل ضغطة صح تولّع الحبة وتنقل الدور
## للحبة اللي بعدها في الحلقة. لما كل الحبات (7) تتلوّن -> المرحلة تخلص.
## لو اللاعب خلص بسرعة (أقل من fast_completion_seconds)، بتتفتح "حبة ذهبية" إضافية
## في النص كتحدي بونص مخفي قبل ما المرحلة تقفل خالص. وأي غلطة في أي حبة (عادية أو
## بونص) بتهز الشاشة شوية. مفيش أي نص على الشاشة وقت التحدي نفسه، بس السبحة والنور والصوت.
##
## طبلة التوتر: صوت لوب بيبدأ لحظة ما التحدي يبدأ فعليًا، وبيعلى تدريجيًا مع
## الوقت (مش مع الغلطات) - كل ما التحدي ياخد وقت أطول، الصوت يعلى أكتر، عشان
## يحس اللاعب بضغط الوقت. بيفضل شغال بنفس التصاعد عبر الأساسي والبونص مع بعض.

enum _State { MAIN, BONUS }

const REQUIRED_COUNT: int = 7
const PULSE_SPEED_START: float = 1.3
const PULSE_SPEED_STEP: float = 0.10       # كل ضغطة صح تزوّد سرعة النبضة شوية (تحدي متصاعد)
const TARGET_WINDOW: float = 0.18          # حجم "منطقة النجاح" حوالين قمة النبضة (0 إلى 1)

const BONUS_PULSE_SPEED: float = 2.4       # نبضة الحبة الذهبية أسرع بكتير (تحدي أصعب)
const BONUS_TARGET_WINDOW: float = 0.10    # ومنطقة نجاحها أضيق

## نداءات صوتية قصيرة (زي "أستغفر الله" أو نفَس راحة) بتتشغل عشوائيًا مع كل ضغطة صح.
## سيبها فاضية لحد ما تسجل أصوات — النظام هيشتغل عادي من غيرها (هيتجاهل الصوت بس).
@export var hit_voice_pool: Array[AudioStream] = []

## صوت طبلة توتر (لوب) - بيبدأ هادي وبيعلى تدريجيًا مع الوقت.
@export var tension_drum_sound: AudioStream = preload("res://audio/sfx/freesound_community-war-drum-loop-103870.mp3")
const _DRUM_MIN_VOLUME_DB: float = -24.0
const _DRUM_MAX_VOLUME_DB: float = -2.0
## قد إيه من الوقت (بالثواني) لحد ما الطبلة توصل لأعلى صوت ليها - مظبوطة قريبة
## من مهلة أذان الفجر (26 ثانية في NIGHT_STAGES بتاعة night.gd) عشان الصوت يوصل
## لأقصاه تقريبًا لحظة ما الأذان يقرب. سهل تزوّدها/تقلّلها من الـ Inspector.
@export var drum_ramp_seconds: float = 24.0

var _layer: CanvasLayer
var _visual: Node2D
var _bonus_visual: Node2D
var _state: _State = _State.MAIN
var _pulse_speed: float = PULSE_SPEED_START
var _t: float = 0.0
var _hits: int = 0
var _accepting_input: bool = false

var _drum_audio: AudioStreamPlayer
var _drum_started_at_ms: int = 0


func _init() -> void:
	stage_name = "istighfar"
	narration_text = "The music grows louder in his mind, and the voice inside tells him to give in...\nPress Space at the moment the light glows brightest."
	fast_completion_seconds = 6.0
	key_hints = ["space"]


func _start_challenge() -> void:
	_state = _State.MAIN
	_hits = 0
	_pulse_speed = PULSE_SPEED_START
	_t = 0.0
	_accepting_input = true
	_build_visual()
	_start_drum()
	set_process(true)


func _build_visual() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)

	_visual = Visual.new()
	_layer.add_child(_visual)
	_visual.setup(REQUIRED_COUNT)
	_visual.position = get_viewport().get_visible_rect().size / 2.0


## بتبدأ صوت الطبلة (لوب) - بيتنادى مرة واحدة بس في بداية الأساسي؛ لو اتنادت
## تاني وهو شغال بالفعل (يعني إحنا داخلين على البونص) بتتجاهل، عشان الصوت يكمل
## نفس التصاعد من غير ما يرجع يبدأ من الأول.
func _start_drum() -> void:
	if _drum_audio:
		return
	_drum_audio = AudioStreamPlayer.new()
	add_child(_drum_audio)
	if tension_drum_sound:
		var stream: AudioStream = tension_drum_sound.duplicate()
		if stream is AudioStreamMP3:
			stream.loop = true
		_drum_audio.stream = stream
	_drum_audio.volume_db = _DRUM_MIN_VOLUME_DB
	_drum_audio.play()
	_drum_started_at_ms = Time.get_ticks_msec()


## بتحسب الوقت اللي عدى من بداية الطبلة وتعلّي صوتها تدريجيًا لحد drum_ramp_seconds.
func _update_drum_volume() -> void:
	if not _drum_audio:
		return
	var elapsed_seconds: float = (Time.get_ticks_msec() - _drum_started_at_ms) / 1000.0
	var t: float = clamp(elapsed_seconds / drum_ramp_seconds, 0.0, 1.0)
	_drum_audio.volume_db = lerp(_DRUM_MIN_VOLUME_DB, _DRUM_MAX_VOLUME_DB, t)


func _stop_drum() -> void:
	if _drum_audio:
		_drum_audio.stop()
		_drum_audio.queue_free()
		_drum_audio = null


func _process(delta: float) -> void:
	_update_drum_volume()
	if not _accepting_input:
		return
	_t += delta * _pulse_speed
	var phase: float = fmod(_t, 1.0)
	var glow: float = 0.5 + 0.5 * sin(phase * TAU)
	var window: float = BONUS_TARGET_WINDOW if _state == _State.BONUS else TARGET_WINDOW
	var in_window: bool = glow > 1.0 - window
	if _state == _State.MAIN:
		_visual.update_glow(glow, in_window)
	else:
		_bonus_visual.update_glow(glow, in_window)


func _unhandled_input(event: InputEvent) -> void:
	if not _accepting_input:
		return
	if event.is_action_pressed("ui_accept"):
		var phase: float = fmod(_t, 1.0)
		var glow: float = 0.5 + 0.5 * sin(phase * TAU)
		var window: float = BONUS_TARGET_WINDOW if _state == _State.BONUS else TARGET_WINDOW
		var success: bool = glow > 1.0 - window

		if _state == _State.MAIN:
			if success:
				_register_hit()
			else:
				_visual.register_miss()
				_shake_layer(_layer)
				_register_mistake()
		else:
			if success:
				_register_bonus_hit()
			else:
				_bonus_visual.register_miss()
				_shake_layer(_layer)
				_register_mistake()
		get_viewport().set_input_as_handled()


func _register_hit() -> void:
	_hits += 1
	_pulse_speed += PULSE_SPEED_STEP
	_visual.light_bead(_hits)
	_register_progress()

	if hit_voice_pool.size() > 0:
		GameAudio.play_success_voice(hit_voice_pool[randi() % hit_voice_pool.size()])

	if _hits >= REQUIRED_COUNT:
		_end_main_visual()


func _end_main_visual() -> void:
	_accepting_input = false
	set_process(false)

	var tw: Tween = create_tween()
	tw.tween_property(_visual, "modulate:a", 0.0, 0.6)
	await tw.finished

	_layer.queue_free()
	_layer = null
	_finish_challenge()  # في StageBase — بتقرر تفتح البونص ولا تخلص المرحلة على طول


## بتتنادى من NightManager لما شريط الصحة يخلص أثناء التحدي — توقف كل حاجة فورًا
## (من غير fade) عشان مشهد السلاسل يبدأ على طول.
func interrupt() -> void:
	_accepting_input = false
	set_process(false)
	set_process_unhandled_input(false)
	if _layer:
		_layer.queue_free()
		_layer = null
	_bonus_visual = null
	_stop_drum()


# ---------------------------------------------------------------------------
# التحدي المخفي (البونص): حبة ذهبية واحدة إضافية، أسرع وأصعب توقيت
# ---------------------------------------------------------------------------

func _has_bonus_challenge() -> bool:
	return true


func _start_bonus_challenge() -> void:
	_state = _State.BONUS
	_t = 0.0
	_pulse_speed = BONUS_PULSE_SPEED
	_accepting_input = true

	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)

	_bonus_visual = BonusVisual.new()
	_layer.add_child(_bonus_visual)
	_bonus_visual.position = get_viewport().get_visible_rect().size / 2.0
	set_process(true)


func _register_bonus_hit() -> void:
	_accepting_input = false
	set_process(false)
	_bonus_visual.mark_success()
	_register_progress()

	if hit_voice_pool.size() > 0:
		GameAudio.play_success_voice(hit_voice_pool[randi() % hit_voice_pool.size()])

	_stop_drum()

	var tw: Tween = create_tween()
	tw.tween_property(_bonus_visual, "modulate:a", 0.0, 0.6)
	await tw.finished

	_layer.queue_free()
	_layer = null
	_bonus_visual = null
	_finish_bonus_challenge()  # في StageBase — بتشغل success_voice وتقفل المرحلة فعليًا


## الرسم البصري: سبحة حقيقية على شكل حلقة بخيط وشرابة. inner class عشان كل حاجة
## خاصة بمرحلة الاستغفار تفضل في ملف واحد بس.
class Visual extends Node2D:
	const RING_RADIUS: float = 100.0          # نصف قطر حلقة السبحة
	const GAP_DEGREES: float = 34.0           # الفجوة تحت (مكان الشرابة) بالدرجات
	const BEAD_RADIUS_NORMAL: float = 11.0    # حجم أي حبة عادية (مولّعة أو لسه)
	const BEAD_RADIUS_CURRENT_MIN: float = 13.0
	const BEAD_RADIUS_CURRENT_MAX: float = 21.0

	var _glow: float = 0.0
	var _in_window: bool = false
	var _bead_count: int = 0
	var _lit_beads: int = 0
	var _miss_flash: float = 0.0

	func setup(bead_count: int) -> void:
		_bead_count = bead_count
		queue_redraw()

	func update_glow(glow: float, in_window: bool) -> void:
		_glow = glow
		_in_window = in_window
		if _miss_flash > 0.0:
			_miss_flash = max(0.0, _miss_flash - 0.02)
		queue_redraw()

	func register_miss() -> void:
		_miss_flash = 1.0
		queue_redraw()

	func light_bead(count: int) -> void:
		_lit_beads = count
		queue_redraw()

	## مكان حبة رقم index على حلقة السبحة (بتبدأ من فوق وتلف، وسايبة فجوة تحت للشرابة)
	func _bead_position(index: int) -> Vector2:
		var usable_deg: float = 360.0 - GAP_DEGREES
		var start_deg: float = -90.0 - usable_deg / 2.0
		var step_deg: float = usable_deg / float(max(_bead_count - 1, 1))
		var angle: float = deg_to_rad(start_deg + index * step_deg)
		return Vector2(cos(angle), sin(angle)) * RING_RADIUS

	func _draw() -> void:
		# الخيط اللي رابط الحبات ببعض
		var thread_points: PackedVector2Array = PackedVector2Array()
		for i in range(_bead_count):
			thread_points.append(_bead_position(i))
		if thread_points.size() > 1:
			draw_polyline(thread_points, Color(0.55, 0.45, 0.22, 0.5), 2.0, true)

		# الشرابة المتدلية تحت (زي أي سبحة حقيقية)
		var tassel_start: Vector2 = Vector2(0, RING_RADIUS)
		var tassel_end: Vector2 = Vector2(0, RING_RADIUS + 24.0)
		draw_line(tassel_start, tassel_end, Color(0.55, 0.45, 0.22, 0.6), 3.0)
		draw_circle(tassel_end, 5.0, Color(0.55, 0.45, 0.22, 0.6))

		for i in range(_bead_count):
			var pos: Vector2 = _bead_position(i)
			var is_current: bool = i == _lit_beads and _lit_beads < _bead_count
			var lit: bool = i < _lit_beads

			if is_current:
				# دي الحبة اللي دورها دلوقتي — بتنبض، ولازم تتضغط عليها في قمة لمعانها
				var radius: float = lerp(BEAD_RADIUS_CURRENT_MIN, BEAD_RADIUS_CURRENT_MAX, _glow)
				var col: Color = Color(0.85, 0.75, 0.35)
				if _in_window:
					col = Color(1.0, 0.95, 0.6)
				if _miss_flash > 0.0:
					col = col.lerp(Color(0.85, 0.25, 0.25), _miss_flash)
				draw_circle(pos, radius + 9.0, Color(col.r, col.g, col.b, 0.25))
				draw_circle(pos, radius, col)
				draw_circle(pos + Vector2(-radius * 0.3, -radius * 0.3), radius * 0.25, Color(1, 1, 1, 0.5))
			elif lit:
				# حبة خلصت وولّعت
				draw_circle(pos, BEAD_RADIUS_NORMAL, Color(0.9, 0.8, 0.4))
				draw_circle(pos + Vector2(-3, -3), BEAD_RADIUS_NORMAL * 0.3, Color(1, 1, 1, 0.35))
			else:
				# حبة لسه معدهاش الدور
				draw_circle(pos, BEAD_RADIUS_NORMAL, Color(0.28, 0.28, 0.3))
				draw_arc(pos, BEAD_RADIUS_NORMAL, 0.0, TAU, 16, Color(0.5, 0.5, 0.5, 0.4), 1.0, true)


## الرسم البصري للحبة الذهبية بتاعة التحدي المخفي (البونص) — شكل نجمة صغيرة
## في نص الشاشة، بتنبض أسرع من الحبات العادية.
class BonusVisual extends Node2D:
	var _glow: float = 0.0
	var _in_window: bool = false
	var _miss_flash: float = 0.0
	var _success: bool = false

	func update_glow(glow: float, in_window: bool) -> void:
		_glow = glow
		_in_window = in_window
		if _miss_flash > 0.0:
			_miss_flash = max(0.0, _miss_flash - 0.03)
		queue_redraw()

	func register_miss() -> void:
		_miss_flash = 1.0
		queue_redraw()

	func mark_success() -> void:
		_success = true
		queue_redraw()

	func _draw() -> void:
		var radius: float = lerp(14.0, 26.0, _glow)
		var col: Color = Color(1.0, 0.85, 0.3)
		if _in_window:
			col = Color(1.0, 1.0, 0.75)
		if _miss_flash > 0.0:
			col = col.lerp(Color(0.85, 0.25, 0.25), _miss_flash)
		if _success:
			col = Color(1.0, 1.0, 0.9)

		draw_circle(Vector2.ZERO, radius + 14.0, Color(col.r, col.g, col.b, 0.25))

		# شكل نجمة بسيطة بدل دايرة عادية عشان تبان "حبة استثنائية"
		var points: PackedVector2Array = PackedVector2Array()
		var spikes: int = 8
		for i in range(spikes * 2):
			var r: float = radius if i % 2 == 0 else radius * 0.45
			var angle: float = i * PI / spikes
			points.append(Vector2(cos(angle), sin(angle)) * r)
		draw_colored_polygon(points, col)
