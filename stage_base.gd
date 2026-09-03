class_name StageBase
extends Node
## الكلاس الأساسي لأي مرحلة من مراحل الليل (Act 2).

signal stage_completed
signal mistake_made
signal progress_made
signal main_challenge_finished
signal challenge_started

var stage_name: String = ""
var narration_text: String = ""
var narration_audio: AudioStream = null
var success_voice: AudioStream = null
var fast_completion_seconds: float = 6.0

## أسماء المفاتيح اللي المرحلة دي بتستخدمها (زي "space", "left", "right",
## "up", "down") - كل مرحلة فرعية تحطها في _init() بتاعتها. بتتحط بالترتيب
## اللي هتظهر بيه الأيقونات على الشاشة.
var key_hints: Array[String] = []

var _challenge_started_at_ms: int = 0
var _hint_layer: CanvasLayer


func run() -> void:
	if not GameAudio.narration_finished.is_connected(_on_narration_finished):
		GameAudio.narration_finished.connect(_on_narration_finished, CONNECT_ONE_SHOT)
	GameAudio.play_narration(narration_text, narration_audio)


func _on_narration_finished() -> void:
	_challenge_started_at_ms = Time.get_ticks_msec()
	challenge_started.emit()
	_show_key_hints()
	_start_challenge()


## بتعرض أيقونات المفاتيح المطلوبة في نص الشاشة لثانيتين ونص وقت ما التحدي
## يبدأ فعليًا، وبعدين تختفي لوحدها.
func _show_key_hints() -> void:
	if key_hints.is_empty():
		return

	_hint_layer = CanvasLayer.new()
	_hint_layer.layer = 15
	add_child(_hint_layer)

	var container := HBoxContainer.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_preset(Control.PRESET_CENTER)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 10)
	container.modulate.a = 0.0
	_hint_layer.add_child(container)

	for key_name in key_hints:
		var path: String = "res://ui/keys/key_%s.png" % key_name
		if not ResourceLoader.exists(path):
			continue
		var icon := TextureRect.new()
		icon.texture = load(path)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.custom_minimum_size = Vector2(48, 48)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		container.add_child(icon)

	var tw: Tween = create_tween()
	tw.tween_property(container, "modulate:a", 1.0, 0.25)
	tw.tween_interval(1.6)
	tw.tween_property(container, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func():
		if is_instance_valid(_hint_layer):
			_hint_layer.queue_free()
		_hint_layer = null
	)


func _start_challenge() -> void:
	push_warning("StageBase._start_challenge() needs override in: " + stage_name)
	_finish_challenge()


func _finish_challenge() -> void:
	main_challenge_finished.emit()

	if _has_bonus_challenge():
		_start_bonus_challenge()
		return

	_cleanup_visual()
	GameAudio.play_success_voice(success_voice)
	await get_tree().create_timer(0.9).timeout
	stage_completed.emit()


func _has_bonus_challenge() -> bool:
	return false


func _start_bonus_challenge() -> void:
	_finish_bonus_challenge()


func _finish_bonus_challenge() -> void:
	_cleanup_visual()
	GameAudio.play_success_voice(success_voice)
	await get_tree().create_timer(0.9).timeout
	stage_completed.emit()


func _register_progress() -> void:
	progress_made.emit()


func _register_mistake() -> void:
	mistake_made.emit()


func _shake_layer(layer: CanvasLayer, amount: float = 6.0, duration: float = 0.3) -> void:
	if layer == null:
		return
	var tw: Tween = create_tween()
	var steps: int = 6
	for i in range(steps):
		var offset: Vector2 = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
		tw.tween_property(layer, "offset", offset, duration / steps)
	tw.tween_property(layer, "offset", Vector2.ZERO, duration / steps)


func _cleanup_visual() -> void:
	pass


func interrupt() -> void:
	set_process(false)
	set_process_unhandled_input(false)
	if is_instance_valid(_hint_layer):
		_hint_layer.queue_free()
	_hint_layer = null
	_cleanup_visual()
