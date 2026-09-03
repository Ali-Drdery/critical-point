class_name TemptationStage
extends StageBase
## مرحلة التخيلات: خيالات بتوهمه إنه اتحرر أو إن سجنه كان جنة.
## الميكانيكة: كيو "ذكر" (أخضر) يظهر -> يضغط بسرعة قبل ما يفوت.
## كيو "وهم" (بنفسجي) يظهر -> يقاوم ومايضغطش لحد ما يختفي لوحده.
## الضغط وقت الوهم = استسلام (غلطة). فوات وقت الذكر = تشتت (غلطة).
## تحدي متصاعد: كل نجاح بيقصّر مدة الكيو الجاي وفجوته (زي الاستغفار).
## تصعيب إضافي: بعد ما الكوره تعدي نص مدتها، بتدخل "منطقة خطر" (معلّمة بعلامة
## حمرا ثابتة على الحلقة) - وجواها ممكن تتقلب نوعها (ذكر <-> وهم) في لحظات
## عشوائية لحد ما تختفي، فمش تقدر تاخد قرارك من أول ما تشوف اللون وتبطّل تركيز.

const _MAIN_TARGET: int = 8
const _BONUS_TARGET: int = 4
const _CUE_MIN: float = 1.1
const _CUE_MAX: float = 1.9
const _GAP_MIN: float = 0.5
const _GAP_MAX: float = 1.0

## كل نجاح بينقص _speed_mult بالقد ده (المدد كلها بتتضرب فيه)، لحد أدنى قيمة.
const _SPEED_STEP: float = 0.07
const _MIN_SPEED_MULT: float = 0.45
const _BONUS_START_SPEED_MULT: float = 0.75   # البونص بيبدأ أسرع من الأساسي أصلًا

## منطقة الخطر: بتبدأ لما نسبة الوقت المتبقي من الكيو توصل للقيمة دي أو أقل.
const _DANGER_ZONE_THRESHOLD: float = 0.5
## المدة بين كل تقلب محتمل والتاني (جوه منطقة الخطر بس)، بتتضرب في _speed_mult
## زي باقي التوقيتات - يعني كل ما المرحلة تتقدم، التقلب نفسه بيبقى أسرع.
const _FLIP_MIN_INTERVAL: float = 0.22
const _FLIP_MAX_INTERVAL: float = 0.45

var _layer: CanvasLayer
var _visual: Node2D
var _cue: String = ""          # "" أو "azkar" أو "illusion"
var _cue_time_left: float = 0.0
var _cue_duration: float = 1.0
var _gap_time_left: float = 0.0
var _responded: bool = false
var _successes: int = 0
var _target: int = 0
var _active: bool = false
var _speed_mult: float = 1.0   # 1.0 = سرعة عادية، بينقص مع كل نجاح (يبقى أسرع)

var _in_danger_zone: bool = false
var _flip_timer: float = 0.0


func _init() -> void:
	stage_name = "Temptation"
	narration_text = "Illusions creep into his mind: maybe he's already free, or maybe this was his true home all along... He has to stay aware and not believe it, returning to remembrance every time the illusion gets close. Watch closely - once it crosses the red mark, it might switch on him."
	key_hints = ["space"]

func _start_challenge() -> void:
	_build_visual()
	_successes = 0
	_target = _MAIN_TARGET
	_speed_mult = 1.0
	_active = true
	_cue = ""
	_gap_time_left = randf_range(_GAP_MIN, _GAP_MAX)
	_visual.set_hint("Stay alert...")
	set_process(true)
	set_process_unhandled_input(true)


func _process(delta: float) -> void:
	if not _active:
		return

	if _cue == "":
		_gap_time_left -= delta
		if _gap_time_left <= 0.0:
			_spawn_cue()
		return

	_cue_time_left -= delta
	var progress: float = clamp(_cue_time_left / _cue_duration, 0.0, 1.0)
	_visual.set_progress(progress, _in_danger_zone)

	if not _responded:
		if not _in_danger_zone and progress <= _DANGER_ZONE_THRESHOLD:
			_in_danger_zone = true
			_flip_timer = randf_range(_FLIP_MIN_INTERVAL, _FLIP_MAX_INTERVAL) * _speed_mult
		if _in_danger_zone:
			_flip_timer -= delta
			if _flip_timer <= 0.0:
				_flip_cue_type()
				_flip_timer = randf_range(_FLIP_MIN_INTERVAL, _FLIP_MAX_INTERVAL) * _speed_mult

	if _cue_time_left <= 0.0:
		if _cue == "azkar" and not _responded:
			_register_mistake()
			_visual.flash_wrong()
		elif _cue == "illusion" and not _responded:
			_on_success()
		_end_cue()


func _unhandled_input(event: InputEvent) -> void:
	if not _active or _cue == "" or _responded:
		return
	if event.is_action_pressed("ui_accept"):
		_responded = true
		if _cue == "azkar":
			_on_success()
		else:
			_register_mistake()
			_visual.flash_wrong()
		_end_cue()


func _spawn_cue() -> void:
	_cue = "azkar" if randf() < 0.55 else "illusion"
	_responded = false
	_in_danger_zone = false
	_flip_timer = 0.0
	_cue_duration = randf_range(_CUE_MIN, _CUE_MAX) * _speed_mult
	_cue_time_left = _cue_duration
	_visual.show_cue(_cue)
	_visual.set_hint("PRESS SPACE!" if _cue == "azkar" else "RESIST - DON'T PRESS")


## بتتنادى وقت ما الكوره جوه منطقة الخطر - بتقلب نوعها (ذكر <-> وهم) فجأة،
## واللاعب لازم يعيد تقييم قراره على أساس النوع الجديد فورًا.
func _flip_cue_type() -> void:
	_cue = "illusion" if _cue == "azkar" else "azkar"
	_visual.set_cue_type(_cue)
	_visual.flash_flip()
	_visual.set_hint("PRESS SPACE!" if _cue == "azkar" else "RESIST - DON'T PRESS")


func _end_cue() -> void:
	_cue = ""
	_in_danger_zone = false
	_flip_timer = 0.0
	_gap_time_left = randf_range(_GAP_MIN, _GAP_MAX) * _speed_mult
	_visual.hide_cue()
	_visual.set_hint("Stay alert...")


func _on_success() -> void:
	_register_progress()
	_visual.flash_correct()
	_successes += 1
	_speed_mult = max(_MIN_SPEED_MULT, _speed_mult - _SPEED_STEP)
	if _successes >= _target:
		_active = false
		if _target == _MAIN_TARGET:
			_finish_challenge()
		else:
			_finish_bonus_challenge()


func _has_bonus_challenge() -> bool:
	return true


func _start_bonus_challenge() -> void:
	_successes = 0
	_target = _BONUS_TARGET
	_speed_mult = _BONUS_START_SPEED_MULT
	_active = true
	_cue = ""
	_gap_time_left = randf_range(_GAP_MIN, _GAP_MAX) * _speed_mult
	_visual.set_hint("Stay alert...")


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

	_visual = TemptationVisual.new()
	_layer.add_child(_visual)
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	_visual.position = screen_size / 2.0


class TemptationVisual extends Node2D:
	const GAME_FONT: Font = preload("res://fonts/Unutterable-Regular.ttf")
	
	var _cue: String = ""
	var _progress: float = 1.0
	var _in_danger_zone: bool = false
	var _flash_timer: float = 0.0
	var _flash_color: Color = Color(0, 0, 0, 0)
	var _flip_flash_timer: float = 0.0
	var _hint: String = ""

	func _process(delta: float) -> void:
		if _flash_timer > 0.0:
			_flash_timer = max(0.0, _flash_timer - delta)
		if _flip_flash_timer > 0.0:
			_flip_flash_timer = max(0.0, _flip_flash_timer - delta)
		queue_redraw()

	func show_cue(cue: String) -> void:
		_cue = cue
		_progress = 1.0
		_in_danger_zone = false
		queue_redraw()

	## بتغيّر نوع الكيو الحالي (لون + سلوك) من غير ما تصفّر الـ progress - دي
	## اللي بتحصل وقت "التقلب" جوه منطقة الخطر.
	func set_cue_type(cue: String) -> void:
		_cue = cue
		queue_redraw()

	func hide_cue() -> void:
		_cue = ""
		_in_danger_zone = false
		queue_redraw()

	func set_progress(p: float, in_danger_zone: bool = false) -> void:
		_progress = p
		_in_danger_zone = in_danger_zone
		queue_redraw()

	func set_hint(text: String) -> void:
		_hint = text
		queue_redraw()

	func flash_correct() -> void:
		_flash_color = Color(0.35, 1.0, 0.5, 0.55)
		_flash_timer = 0.25

	func flash_wrong() -> void:
		_flash_color = Color(1.0, 0.15, 0.15, 0.6)
		_flash_timer = 0.25

	## ومضة سريعة (أبيض) لحظة ما الكوره تتقلب - عشان اللاعب يحس إن حاجة اتغيرت.
	func flash_flip() -> void:
		_flip_flash_timer = 0.2

	func _draw() -> void:
		if _flash_timer > 0.0:
			var a: float = _flash_timer / 0.25
			draw_circle(Vector2.ZERO, 150.0, Color(_flash_color.r, _flash_color.g, _flash_color.b, _flash_color.a * a))

		if _cue != "":
			var base_color: Color = Color(0.35, 0.85, 0.55, 0.9) if _cue == "azkar" else Color(0.55, 0.15, 0.65, 0.9)
			if _flip_flash_timer > 0.0:
				base_color = base_color.lerp(Color(1.0, 1.0, 1.0, 0.9), _flip_flash_timer / 0.2)
			var pulse: float = 60.0 + 12.0 * sin(Time.get_ticks_msec() / 90.0)
			draw_circle(Vector2.ZERO, pulse, base_color)
			draw_arc(Vector2.ZERO, pulse + 16.0, 0.0, TAU * _progress, 40, Color(1, 1, 1, 0.85), 5.0, true)

			# علامة حمرا ثابتة عند نص المدة - تحذير إن بعد النقطة دي الكرة
			# ممكن "تتقلب" فجأة. بتبقى باهتة قبل ما توصلها، وتبان واضحة وتنبض
			# لما فعلاً تكون جوه منطقة الخطر.
			var marker_dir: Vector2 = Vector2(1.0, 0.0)   # عند زاوية 0 = مكان نص التقدم بالظبط
			var danger_pulse: float = 1.0
			if _in_danger_zone:
				danger_pulse = 0.75 + 0.25 * sin(Time.get_ticks_msec() / 70.0)
			var marker_alpha: float = (0.9 if _in_danger_zone else 0.45) * danger_pulse
			var marker_len: float = 26.0 if _in_danger_zone else 16.0
			draw_line(marker_dir * (pulse + 6.0), marker_dir * (pulse + 6.0 + marker_len), Color(1.0, 0.15, 0.1, marker_alpha), 4.0)

		_draw_hint()

	func _draw_hint() -> void:
		if _hint == "":
			return
		draw_string(GAME_FONT, Vector2(-150, 150), _hint, HORIZONTAL_ALIGNMENT_CENTER, 300, 20, Color(1, 1, 1, 0.85))
