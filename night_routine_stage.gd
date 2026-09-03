class_name NightRoutineStage
extends StageBase
## مرحلة المهام المسائية: تسلسل حركات (Simon Says) لازم يتنفذ بالترتيب الصح.
## كل جولة بتوّري تسلسل قصير من الأسهم، وبعدها يدخل يكرره بنفس الترتيب.
## غلطة في أي خطوة = يرجع للأول في نفس الجولة. طول التسلسل بيزيد مع كل نجاح.

const _MAIN_TARGET_ROUNDS: int = 4
const _BONUS_TARGET_ROUNDS: int = 3
const _START_LENGTH: int = 3
const _BONUS_START_LENGTH: int = 4
const _MAX_LENGTH: int = 7

const _SHOW_STEP_TIME: float = 0.55
const _SHOW_GAP_TIME: float = 0.18

const _DIRECTIONS: Array[String] = ["up", "down", "left", "right"]

var _layer: CanvasLayer
var _visual: Node2D

var _sequence: Array[String] = []
var _input_index: int = 0
var _sequence_length: int = 3
var _rounds_done: int = 0
var _target_rounds: int = 0

var _accepting_input: bool = false
var _active: bool = false


func _init() -> void:
	stage_name = "NightRoutine"
	narration_text = "One last thing before sleep - the same small steps, in the same order, every night. Losing the order means losing the routine that's supposed to hold him together."
	key_hints = ["up", "down", "left", "right"]

func _start_challenge() -> void:
	_build_visual()
	_sequence_length = _START_LENGTH
	_rounds_done = 0
	_target_rounds = _MAIN_TARGET_ROUNDS
	_active = true
	_start_round()


func _start_round() -> void:
	_input_index = 0
	_sequence.clear()
	for i in range(_sequence_length):
		_sequence.append(_DIRECTIONS[randi() % _DIRECTIONS.size()])
	_show_sequence()


func _show_sequence() -> void:
	_accepting_input = false
	set_process_unhandled_input(false)
	_visual.set_hint("Watch...")
	_show_next_step(0)


func _show_next_step(i: int) -> void:
	if not _active:
		return
	if i >= _sequence.size():
		_accepting_input = true
		set_process_unhandled_input(true)
		_visual.set_hint("Your turn (0/%d)" % _sequence.size())
		return

	_visual.flash_direction(_sequence[i], true)
	get_tree().create_timer(_SHOW_STEP_TIME).timeout.connect(func():
		if not _active:
			return
		_visual.clear_flash()
		get_tree().create_timer(_SHOW_GAP_TIME).timeout.connect(func():
			if not _active:
				return
			_show_next_step(i + 1)
		)
	)


func _unhandled_input(event: InputEvent) -> void:
	if not _active or not _accepting_input:
		return
	var pressed_dir: String = ""
	if event.is_action_pressed("ui_up"):
		pressed_dir = "up"
	elif event.is_action_pressed("ui_down"):
		pressed_dir = "down"
	elif event.is_action_pressed("ui_left"):
		pressed_dir = "left"
	elif event.is_action_pressed("ui_right"):
		pressed_dir = "right"
	else:
		return

	_visual.flash_direction(pressed_dir, pressed_dir == _sequence[_input_index])

	if pressed_dir == _sequence[_input_index]:
		_input_index += 1
		if _input_index >= _sequence.size():
			_on_round_success()
		else:
			_visual.set_hint("Your turn (%d/%d)" % [_input_index, _sequence.size()])
	else:
		_register_mistake()
		_accepting_input = false
		get_tree().create_timer(0.4).timeout.connect(func():
			if not _active:
				return
			_visual.clear_flash()
			_input_index = 0
			_accepting_input = true
			_visual.set_hint("Your turn (0/%d)" % _sequence.size())
		)


func _on_round_success() -> void:
	_register_progress()
	_accepting_input = false
	set_process_unhandled_input(false)
	_rounds_done += 1
	_sequence_length = min(_MAX_LENGTH, _sequence_length + 1)

	if _rounds_done >= _target_rounds:
		_active = false
		if _target_rounds == _MAIN_TARGET_ROUNDS:
			_finish_challenge()
		else:
			_finish_bonus_challenge()
		return

	get_tree().create_timer(0.5).timeout.connect(func():
		if not _active:
			return
		_start_round()
	)


func _has_bonus_challenge() -> bool:
	return true


func _start_bonus_challenge() -> void:
	_sequence_length = _BONUS_START_LENGTH
	_rounds_done = 0
	_target_rounds = _BONUS_TARGET_ROUNDS
	_active = true
	_start_round()


func interrupt() -> void:
	super()
	_active = false
	_accepting_input = false


func _cleanup_visual() -> void:
	if _layer:
		_layer.queue_free()
		_layer = null


func _build_visual() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)

	_visual = NightRoutineVisual.new()
	_layer.add_child(_visual)
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	_visual.position = screen_size / 2.0


class NightRoutineVisual extends Node2D:
	const GAME_FONT: Font = preload("res://fonts/Unutterable-Regular.ttf")
	
	var _active_dir: String = ""
	var _active_correct: bool = true
	var _hint: String = ""

	func set_hint(text: String) -> void:
		_hint = text
		queue_redraw()

	func flash_direction(dir: String, correct: bool) -> void:
		_active_dir = dir
		_active_correct = correct
		queue_redraw()

	func clear_flash() -> void:
		_active_dir = ""
		queue_redraw()

	func _draw() -> void:
		var positions: Dictionary = {
			"up": Vector2(0, -80),
			"down": Vector2(0, 80),
			"left": Vector2(-80, 0),
			"right": Vector2(80, 0),
		}
		for dir in positions.keys():
			var pos: Vector2 = positions[dir]
			var is_active: bool = dir == _active_dir
			var color: Color = Color(0.3, 0.3, 0.35, 0.6)
			if is_active:
				color = Color(0.35, 1.0, 0.5, 0.9) if _active_correct else Color(1.0, 0.15, 0.15, 0.9)
			draw_circle(pos, 34.0, color)

		draw_string(GAME_FONT, Vector2(-150, 150), _hint, HORIZONTAL_ALIGNMENT_CENTER, 300, 20, Color(1, 1, 1, 0.85))
