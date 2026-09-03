class_name DistractionStage
extends StageBase
## مرحلة المشتتات: تنبيهات بتظهر في جهتين (شمال/يمين) لازم يتعامل معاها صح.
## تنبيه "مشتت" (أحمر) - يضغط مفتاح جهته بسرعة قبل ما يختفي. تنبيه "مهم"
## (أخضر) - يسيبه يختفي لوحده من غير ما يضغط، عشان مش كل حاجة تستاهل يتجاهلها.
## ضغط على جهة فاضية أو على تنبيه مهم = غلطة. تسريع تدريجي مع كل نجاح.

const _MAIN_TARGET: int = 10
const _BONUS_TARGET: int = 5

const _CUE_MIN: float = 0.75
const _CUE_MAX: float = 1.3
const _GAP_MIN: float = 0.25
const _GAP_MAX: float = 0.55

const _SPEED_STEP: float = 0.06
const _MIN_SPEED_MULT: float = 0.5
const _BONUS_START_SPEED_MULT: float = 0.7

var _layer: CanvasLayer
var _visual: Node2D

var _lane_cue: Dictionary = {"left": "", "right": ""}
var _lane_time_left: Dictionary = {"left": 0.0, "right": 0.0}
var _lane_duration: Dictionary = {"left": 1.0, "right": 1.0}
var _lane_responded: Dictionary = {"left": false, "right": false}
var _lane_gap_left: Dictionary = {"left": 0.0, "right": 0.0}

var _successes: int = 0
var _target: int = 0
var _speed_mult: float = 1.0
var _active: bool = false


func _init() -> void:
	stage_name = "Distraction"
	narration_text = "Notifications pull at him from every side. Some are just noise - he needs to let them pass. But some matter, and dismissing everything blindly is its own kind of running away."
	key_hints = ["left", "right"]

func _start_challenge() -> void:
	_build_visual()
	_successes = 0
	_target = _MAIN_TARGET
	_speed_mult = 1.0
	_active = true
	for lane in ["left", "right"]:
		_lane_cue[lane] = ""
		_lane_gap_left[lane] = randf_range(_GAP_MIN, _GAP_MAX)
	set_process(true)
	set_process_unhandled_input(true)


func _process(delta: float) -> void:
	if not _active:
		return
	for lane in ["left", "right"]:
		_process_lane(lane, delta)


func _process_lane(lane: String, delta: float) -> void:
	if _lane_cue[lane] == "":
		_lane_gap_left[lane] -= delta
		if _lane_gap_left[lane] <= 0.0:
			_spawn_lane_cue(lane)
		return

	_lane_time_left[lane] -= delta
	var progress: float = clamp(_lane_time_left[lane] / _lane_duration[lane], 0.0, 1.0)
	_visual.set_lane_progress(lane, progress)

	if _lane_time_left[lane] <= 0.0:
		if _lane_cue[lane] == "distract" and not _lane_responded[lane]:
			_register_mistake()
			_visual.flash_lane_wrong(lane)
		elif _lane_cue[lane] == "focus" and not _lane_responded[lane]:
			_on_success()
		_end_lane_cue(lane)


func _spawn_lane_cue(lane: String) -> void:
	_lane_cue[lane] = "distract" if randf() < 0.6 else "focus"
	_lane_responded[lane] = false
	_lane_duration[lane] = randf_range(_CUE_MIN, _CUE_MAX) * _speed_mult
	_lane_time_left[lane] = _lane_duration[lane]
	_visual.show_lane_cue(lane, _lane_cue[lane])


func _end_lane_cue(lane: String) -> void:
	_lane_cue[lane] = ""
	_lane_gap_left[lane] = randf_range(_GAP_MIN, _GAP_MAX) * _speed_mult
	_visual.hide_lane_cue(lane)


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_left"):
		_try_lane("left")
	elif event.is_action_pressed("ui_right"):
		_try_lane("right")


func _try_lane(lane: String) -> void:
	if _lane_cue[lane] == "" or _lane_responded[lane]:
		_register_mistake()
		_visual.flash_lane_wrong(lane)
		return

	_lane_responded[lane] = true
	if _lane_cue[lane] == "distract":
		_on_success()
		_visual.flash_lane_correct(lane)
	else:
		_register_mistake()
		_visual.flash_lane_wrong(lane)
	_end_lane_cue(lane)


func _on_success() -> void:
	_register_progress()
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
	for lane in ["left", "right"]:
		_lane_cue[lane] = ""
		_lane_gap_left[lane] = randf_range(_GAP_MIN, _GAP_MAX) * _speed_mult


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

	_visual = DistractionVisual.new()
	_layer.add_child(_visual)
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	_visual.position = screen_size / 2.0


class DistractionVisual extends Node2D:
	const GAME_FONT: Font = preload("res://fonts/Unutterable-Regular.ttf")
	
	var _lane_progress: Dictionary = {"left": 0.0, "right": 0.0}
	var _lane_type: Dictionary = {"left": "", "right": ""}
	var _lane_flash_timer: Dictionary = {"left": 0.0, "right": 0.0}
	var _lane_flash_color: Dictionary = {"left": Color(0, 0, 0, 0), "right": Color(0, 0, 0, 0)}

	func _process(delta: float) -> void:
		for lane in ["left", "right"]:
			if _lane_flash_timer[lane] > 0.0:
				_lane_flash_timer[lane] = max(0.0, _lane_flash_timer[lane] - delta)
		queue_redraw()

	func show_lane_cue(lane: String, cue_type: String) -> void:
		_lane_type[lane] = cue_type
		_lane_progress[lane] = 1.0

	func hide_lane_cue(lane: String) -> void:
		_lane_type[lane] = ""

	func set_lane_progress(lane: String, p: float) -> void:
		_lane_progress[lane] = p

	func flash_lane_correct(lane: String) -> void:
		_lane_flash_color[lane] = Color(0.35, 1.0, 0.5, 0.6)
		_lane_flash_timer[lane] = 0.25

	func flash_lane_wrong(lane: String) -> void:
		_lane_flash_color[lane] = Color(1.0, 0.15, 0.15, 0.6)
		_lane_flash_timer[lane] = 0.25

	func _draw() -> void:
		_draw_lane(Vector2(-140, 0), "left", "L")
		_draw_lane(Vector2(140, 0), "right", "R")

	func _draw_lane(pos: Vector2, lane: String, label: String) -> void:
		if _lane_flash_timer[lane] > 0.0:
			var a: float = _lane_flash_timer[lane] / 0.25
			var c: Color = _lane_flash_color[lane]
			draw_circle(pos, 100.0, Color(c.r, c.g, c.b, c.a * a))

		if _lane_type[lane] != "":
			var base_color: Color = Color(0.85, 0.25, 0.25, 0.9) if _lane_type[lane] == "distract" else Color(0.35, 0.85, 0.55, 0.9)
			var pulse: float = 46.0 + 8.0 * sin(Time.get_ticks_msec() / 90.0)
			draw_circle(pos, pulse, base_color)
			draw_arc(pos, pulse + 14.0, 0.0, TAU * _lane_progress[lane], 32, Color(1, 1, 1, 0.85), 4.0, true)

		draw_string(GAME_FONT, pos + Vector2(-8, 110), label, HORIZONTAL_ALIGNMENT_CENTER, 40, 22, Color(1, 1, 1, 0.85))
