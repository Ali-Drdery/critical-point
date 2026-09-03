extends Node
## Autoload باسم: GameAudio
## بيدير 3 حاجات بس:
##   1) عرض نص السرد/الـ voice-over في بداية كل مرحلة (بيتكتب حرف حرف وبيختفي لوحده)
##   2) تشغيل صوت الشخصية وقت نجاح الفعل (استغفار/دعاء/تنهيدة راحة... إلخ)
##   3) تشغيل مؤثرات صوتية عامة قصيرة
##
## التسجيل (خطوة واحدة يدوية لازم تتعمل):
##   Project > Project Settings > Autoload
##   Path: res://audio_manager.gd   |   Node Name: GameAudio   -> Add
## أو تفتح project.godot بأي محرر نصوص وتضيف تحت قسم [autoload]:
##   GameAudio="*res://audio_manager.gd"

signal narration_finished

## سرعة الكتابة القصوى (ثانية بين كل حرف) - لو الصوت/المدة أقصر من كده، السرعة
## بتزيد تلقائي عشان النص يخلص كتابة قبل ما يختفي (شوف _start_typing).
@export var typing_char_interval: float = 0.035
## صوت كتابة مستمر (لوب) - بيبدأ لحظة ما الكتابة تبدأ ويوقف لما تخلص.
@export var typing_sound: AudioStream = preload("res://audio/sfx/dragon-studio-keyboard-typing-sound-effect-335503.mp3")

var _narration_player: AudioStreamPlayer
var _voice_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _checkpoint_player: AudioStreamPlayer
var _typing_player: AudioStreamPlayer

var _canvas: CanvasLayer
var _narration_panel: ColorRect
var _narration_label: Label
var _fallback_timer: Timer
var _fade_tween: Tween
var _typing_tween: Tween
var _typing_full_text: String = ""
var _typing_char_index: int = 0


func _ready() -> void:
	_narration_player = AudioStreamPlayer.new()
	_voice_player = AudioStreamPlayer.new()
	_sfx_player = AudioStreamPlayer.new()
	_checkpoint_player = AudioStreamPlayer.new()
	_typing_player = AudioStreamPlayer.new()
	add_child(_narration_player)
	add_child(_voice_player)
	add_child(_sfx_player)
	add_child(_checkpoint_player)
	add_child(_typing_player)

	_fallback_timer = Timer.new()
	_fallback_timer.one_shot = true
	add_child(_fallback_timer)

	_build_narration_ui()


func _build_narration_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 50  # فوق أي حاجة تانية على الشاشة
	add_child(_canvas)

	_narration_panel = ColorRect.new()
	_narration_panel.color = Color(0, 0, 0, 0.65)
	_narration_panel.visible = false
	_narration_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_narration_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_narration_panel.offset_top = -160
	_narration_panel.offset_bottom = -20
	_narration_panel.offset_left = 40
	_narration_panel.offset_right = -40
	_canvas.add_child(_narration_panel)

	_narration_label = Label.new()
	_narration_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_narration_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_narration_label.offset_left = 20
	_narration_label.offset_top = 12
	_narration_label.offset_right = -20
	_narration_label.offset_bottom = -12
	_narration_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_narration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_narration_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_narration_label.add_theme_font_size_override("font_size", 22)
	_narration_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_narration_label.add_theme_font_override("font", load("res://fonts/Unutterable-Regular.ttf"))
	_narration_panel.add_child(_narration_label)


## بيعرض نص السرد (بيتكتب حرف حرف) + يشغل صوت الأداء الصوتي (لو موجود)، ولما
## يخلص بيختفي النص لوحده ويبعت narration_finished. لو audio_stream = null
## (لسه معملتش تسجيل) هيحسب مدة تقريبية من طول النص عشان اللاعب يقدر يقرا.
func play_narration(text: String, audio_stream: AudioStream = null, min_seconds: float = 2.0) -> void:
	_narration_label.text = ""
	_narration_label.modulate.a = 0.0
	_narration_panel.visible = true

	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_narration_label, "modulate:a", 1.0, 0.35)

	var total_duration: float
	if audio_stream:
		_narration_player.stream = audio_stream
		_narration_player.play()
		if not _narration_player.finished.is_connected(_on_narration_source_finished):
			_narration_player.finished.connect(_on_narration_source_finished, CONNECT_ONE_SHOT)
		var audio_len: float = audio_stream.get_length()
		total_duration = audio_len if audio_len > 0.0 else max(min_seconds, text.length() * 0.06)
	else:
		total_duration = max(min_seconds, text.length() * 0.06)
		if not _fallback_timer.timeout.is_connected(_on_narration_source_finished):
			_fallback_timer.timeout.connect(_on_narration_source_finished, CONNECT_ONE_SHOT)
		_fallback_timer.start(total_duration)

	_start_typing(text, total_duration)


## بيكتب النص تدريجيًا حرف حرف - السرعة بتتحسب عشان النص يخلص كتابة في وقت
## أقصاه total_duration (تفيد لما يكون الصوت قصير أو النص طويل)، وبيشغل صوت
## الكتابة (لوب) طول مدة الكتابة نفسها بس.
func _start_typing(text: String, total_duration: float) -> void:
	if _typing_tween:
		_typing_tween.kill()
		_typing_tween = null

	_typing_full_text = text
	_typing_char_index = 0
	var char_count: int = text.length()

	if char_count == 0:
		_stop_typing_sound()
		return

	var interval: float = min(typing_char_interval, total_duration / float(char_count))

	_start_typing_sound()

	_typing_tween = create_tween()
	for i in range(char_count):
		_typing_tween.tween_callback(_reveal_next_char).set_delay(interval)
	_typing_tween.tween_callback(_stop_typing_sound)


func _reveal_next_char() -> void:
	_typing_char_index += 1
	_narration_label.text = _typing_full_text.substr(0, _typing_char_index)


func _start_typing_sound() -> void:
	if typing_sound == null:
		return
	var stream: AudioStream = typing_sound.duplicate()
	if stream is AudioStreamMP3:
		stream.loop = true
	_typing_player.stream = stream
	_typing_player.play()


func _stop_typing_sound() -> void:
	if _typing_player.playing:
		_typing_player.stop()


## بتكمّل النص فورًا (snap) وتوقف صوت الكتابة - بتتنادى قبل أي اختفاء للنص عشان
## نضمن إن النص كامل دايمًا لما يفضى، حتى لو الصوت/المؤقت خلص قبل ما الكتابة تخلص.
func _finish_typing_immediately() -> void:
	if _typing_tween:
		_typing_tween.kill()
		_typing_tween = null
	_narration_label.text = _typing_full_text
	_stop_typing_sound()


func _on_narration_source_finished() -> void:
	_finish_typing_immediately()
	var fade: Tween = create_tween()
	fade.tween_property(_narration_label, "modulate:a", 0.0, 0.35)
	await fade.finished
	_narration_panel.visible = false
	narration_finished.emit()


## صوت الشخصية وقت نجاح الفعل. سيب الملف null لحد ما تسجل الصوت -> مش هيعمل كراش، هيتجاهله بس.
func play_success_voice(stream: AudioStream) -> void:
	if stream == null:
		return
	_voice_player.stream = stream
	_voice_player.play()


## مؤثرات صوتية عامة قصيرة (كليك، جرس، سلاسل، أذان الـ checkpoint...)
func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	_sfx_player.stream = stream
	_sfx_player.volume_db = volume_db
	_sfx_player.play()

## صوت الأذان (checkpoint) - على قناة منفصلة عن play_sfx() عشان صوت الأذان
## مايتقطعش لو صوت تاني (نجاح جزئي، شياطين بتتحرق...) اتشغل في نفس اللحظة تقريبًا.
func play_checkpoint(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	_checkpoint_player.stream = stream
	_checkpoint_player.volume_db = volume_db
	_checkpoint_player.play()

## بتوقف كل الأصوات الشغالة فورًا (سرد + صوت نجاح + مؤثرات + أذان + كتابة) -
## بتتنادى أول ما تحدي جديد يبدأ عشان مايفضلش أي صوت قديم شغال يتداخل مع التحدي الجديد.
func stop_all() -> void:
	_narration_player.stop()
	_voice_player.stop()
	_sfx_player.stop()
	_checkpoint_player.stop()
	_fallback_timer.stop()
	if _fade_tween:
		_fade_tween.kill()
	_finish_typing_immediately()
	_narration_panel.visible = false
