class_name BoredomStage
extends StageBase
## مرحلة الملل: رفع أوزان بإيدين لازم يتزامنوا مع بعض. كل إيد (شمال/يمين) عندها
## وزن بيتحرك لوحده بين تحت وفوق بسرعته الخاصة. تضغط ui_left/ui_right وهي في
## "قمة الرفعة" (منطقة النجاح)، ولازم الإيدين الاتنين يضغطوا صح جوه نافذة تزامن
## قصيرة من بعض عشان الرفعة تتحسب. غلطة: ضغط والوزن مش في المنطقة، أو إيد جاهزة
## استنت أكتر من نافذة التزامن من غير ما التانية تلحق.

const _MAIN_TARGET: int = 5
const _BONUS_TARGET: int = 3

const _LEFT_PERIOD: float = 1.3
const _RIGHT_PERIOD: float = 1.6

const _MAIN_ZONE_WIDTH: float = 0.28
const _BONUS_ZONE_WIDTH: float = 0.16

const _SYNC_WINDOW: float = 0.35

## كل نجاح بيسرّع دورة الوزنين شوية (بيقصّر الـ period) لحد سقف أدنى.
const _PERIOD_STEP: float = 0.09
const _MIN_PERIOD_MULT: float = 0.55

var _layer: CanvasLayer
var _visual: Node2D

var _left_phase: float = 0.0
var _right_phase: float = 0.0
var _period_mult: float = 1.0
var _zone_width: float = 0.28

var _left_ready: bool = false
var _right_ready: bool = false
var _left_ready_time_ms: int = 0
var _right_ready_time_ms: int = 0

var _successes: int = 0
var _target: int = 0
var _active: bool = false


func _init() -> void:
	stage_name = "Boredom"
	narration_text = "الملل بيقتله وهو واقف من غير حاجة يعملها... لازم يرفع الوزن بإيديه الاتنين مع بعض بالظبط، عشان يفرّغ الطاقة دي صح."
	key_hints = ["left", "right"]

func _start_challenge() -> void:
	_build_visual()
	_reset_round(_MAIN_TARGET, 1.0, _MAIN_ZONE_WIDTH)


func _reset_round(target: int, period_mult: float, zone_width: float) -> void:
	_successes = 0
	_target = target
	_period_mult = period_mult
	_zone_width = zone_width
	_left_phase = 0.0
	_right_phase = 0.25   # يبدأوا مش متزامنين، عشان اللاعب هو اللي يزامنهم
	_left_ready = false
	_right_ready = false
	_active = true
	set_process(true)
	set_process_unhandled_input(true)


func _process(delta: float) -> void:
	if not _active:
		return

	_left_phase = fmod(_left_phase + delta / (_LEFT_PERIOD * _period_mult), 1.0)
	_right_phase = fmod(_right_phase + delta / (_RIGHT_PERIOD * _period_mult), 1.0)

	var left_pos: float = 0.5 - 0.5 * cos(_left_phase * TAU)
	var right_pos: float = 0.5 - 0.5 * cos(_right_phase * TAU)
	var left_in_zone: bool = left_pos >= (1.0 - _zone_width)
	var right_in_zone: bool = right_pos >= (1.0 - _zone_width)

	_visual.update_arms(left_pos, right_pos, left_in_zone, right_in_zone)

	if _left_ready and (Time.get_ticks_msec() - _left_ready_time_ms) / 1000.0 > _SYNC_WINDOW:
		_left_ready = false
		_register_mistake()
		_visual.flash_wrong("left")
	if _right_ready and (Time.get_ticks_msec() - _right_ready_time_ms) / 1000.0 > _SYNC_WINDOW:
		_right_ready = false
		_register_mistake()
		_visual.flash_wrong("right")


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_left"):
		_try_hand("left")
	elif event.is_action_pressed("ui_right"):
		_try_hand("right")


func _try_hand(hand: String) -> void:
	var phase: float = _left_phase if hand == "left" else _right_phase
	var pos: float = 0.5 - 0.5 * cos(phase * TAU)
	var in_zone: bool = pos >= (1.0 - _zone_width)

	if not in_zone:
		_register_mistake()
		_visual.flash_wrong(hand)
		return

	if hand == "left":
		_left_ready = true
		_left_ready_time_ms = Time.get_ticks_msec()
	else:
		_right_ready = true
		_right_ready_time_ms = Time.get_ticks_msec()

	_visual.flash_ready(hand)
	_check_sync()


func _check_sync() -> void:
	if not (_left_ready and _right_ready):
		return
	var diff_sec: float = abs(_left_ready_time_ms - _right_ready_time_ms) / 1000.0
	if diff_sec <= _SYNC_WINDOW:
		_on_sync_success()


func _on_sync_success() -> void:
	_left_ready = false
	_right_ready = false
	_register_progress()
	_visual.flash_correct()
	_successes += 1
	_period_mult = max(_MIN_PERIOD_MULT, _period_mult - _PERIOD_STEP)

	if _successes >= _target:
		_active = false
		if _target == _MAIN_TARGET:
			_finish_challenge()
		else:
			_finish_bonus_challenge()


func _has_bonus_challenge() -> bool:
	return true


func _start_bonus_challenge() -> void:
	_reset_round(_BONUS_TARGET, 0.8, _BONUS_ZONE_WIDTH)


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

	_visual = BoredomVisual.new()
	_layer.add_child(_visual)
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	_visual.position = screen_size / 2.0


class BoredomVisual extends Node2D:
	const GAME_FONT: Font = preload("res://fonts/Unutterable-Regular.ttf")
	
	var _left_pos: float = 0.0
	var _right_pos: float = 0.0
	var _left_in_zone: bool = false
	var _right_in_zone: bool = false
	var _flash_left_timer: float = 0.0
	var _flash_right_timer: float = 0.0
	var _flash_left_color: Color = Color(0, 0, 0, 0)
	var _flash_right_color: Color = Color(0, 0, 0, 0)
	var _center_flash_timer: float = 0.0

	func _process(delta: float) -> void:
		if _flash_left_timer > 0.0:
			_flash_left_timer = max(0.0, _flash_left_timer - delta)
		if _flash_right_timer > 0.0:
			_flash_right_timer = max(0.0, _flash_right_timer - delta)
		if _center_flash_timer > 0.0:
			_center_flash_timer = max(0.0, _center_flash_timer - delta)
		queue_redraw()

	func update_arms(left_pos: float, right_pos: float, left_in_zone: bool, right_in_zone: bool) -> void:
		_left_pos = left_pos
		_right_pos = right_pos
		_left_in_zone = left_in_zone
		_right_in_zone = right_in_zone
		queue_redraw()

	func flash_ready(hand: String) -> void:
		if hand == "left":
			_flash_left_color = Color(0.4, 0.75, 1.0, 0.7)
			_flash_left_timer = 0.2
		else:
			_flash_right_color = Color(0.4, 0.75, 1.0, 0.7)
			_flash_right_timer = 0.2

	func flash_wrong(hand: String) -> void:
		if hand == "left":
			_flash_left_color = Color(1.0, 0.15, 0.15, 0.7)
			_flash_left_timer = 0.25
		else:
			_flash_right_color = Color(1.0, 0.15, 0.15, 0.7)
			_flash_right_timer = 0.25

	func flash_correct() -> void:
		_center_flash_timer = 0.3

	func _draw() -> void:
		_draw_arm(Vector2(-90, 0), _left_pos, _left_in_zone, _flash_left_color, _flash_left_timer, "L")
		_draw_arm(Vector2(90, 0), _right_pos, _right_in_zone, _flash_right_color, _flash_right_timer, "R")

		if _center_flash_timer > 0.0:
			var a: float = _center_flash_timer / 0.3
			draw_circle(Vector2.ZERO, 160.0, Color(0.35, 1.0, 0.5, 0.45 * a))

	func _draw_arm(base_pos: Vector2, pos_pct: float, in_zone: bool, flash_color: Color, flash_timer: float, label: String) -> void:
		var track_h: float = 160.0
		var track_w: float = 22.0
		var top: Vector2 = base_pos + Vector2(0, -track_h / 2.0)
		draw_rect(Rect2(top - Vector2(track_w / 2.0, 0), Vector2(track_w, track_h)), Color(0, 0, 0, 0.45))

		var zone_h: float = track_h * 0.28
		var zone_color: Color = Color(0.4, 0.9, 0.5, 0.55) if in_zone else Color(0.9, 0.75, 0.3, 0.35)
		draw_rect(Rect2(top - Vector2(track_w / 2.0, 0), Vector2(track_w, zone_h)), zone_color)

		var marker_y: float = top.y + track_h * (1.0 - pos_pct)
		var marker_color: Color = flash_color if flash_timer > 0.0 else Color(0.9, 0.9, 0.9, 0.95)
		draw_circle(Vector2(base_pos.x, marker_y), 14.0, marker_color)

		draw_string(GAME_FONT, base_pos + Vector2(-8, track_h / 2.0 + 26), label, HORIZONTAL_ALIGNMENT_CENTER, 40, 22, Color(1, 1, 1, 0.85))
