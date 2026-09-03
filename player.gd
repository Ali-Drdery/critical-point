extends CharacterBody2D

const SPEED = 200.0
const JUMP_VELOCITY = -400.0
const SPRITE_SCALE: float = 2.0   ## غيّر الرقم ده لو عايز الشخصية أكبر/أصغر
const CLIMB_SPEED: float = 140.0  ## سرعة الصعود/النزول على السلم
const CLIMB_HORIZONTAL_MULT: float = 0.6   ## الحركة الجانبية أبطأ شوية وهو ماسك السلم

const FRAME_SIZE: int = 200

## أصوات الحركة - placeholder حاليًا، سهل تستبدلها بأصوات تانية من نفس المسار.
@export var jump_sound: AudioStream = preload("res://audio/sfx/jofae-swing-whoosh-110410.mp3")
@export var run_sound: AudioStream = preload("res://audio/sfx/freesound_community-running-sounds-6003.mp3")

var camera: Camera2D
var is_being_pulled = false
var is_in_challenge = false
var is_climbing: bool = false

var _sprite: Sprite2D
var _animations: Dictionary = {}   ## name -> {texture, frame_count, fps}
var _current_anim: String = ""
var _frame_index: int = 0
var _frame_timer: float = 0.0

var _run_audio: AudioStreamPlayer


func _ready() -> void:
	_build_camera()
	_build_collision()
	_build_visuals()
	_build_audio()


func _build_camera() -> void:
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)
	camera.make_current()


func _load_anim(anim_id: String, path: String, fps: float) -> void:
	if not ResourceLoader.exists(path):
		print("مش لاقي ملف الأنيميشن: ", path)
		return
	var tex: Texture2D = load(path)
	if tex == null:
		print("الملف موجود بس مش قادر يتحمّل: ", path)
		return
	var frame_count: int = max(1, tex.get_width() / FRAME_SIZE)
	_animations[anim_id] = {"texture": tex, "frame_count": frame_count, "fps": fps}


func _build_visuals() -> void:
	_load_anim("idle", "res://character/Idle.png", 6.0)
	_load_anim("run", "res://character/Run.png", 12.0)
	_load_anim("jump", "res://character/Jump.png", 8.0)
	_load_anim("fall", "res://character/Fall.png", 8.0)
	_load_anim("take_hit", "res://character/TakeHit.png", 10.0)
	_load_anim("death", "res://character/Death.png", 8.0)
	_load_anim("attack1", "res://character/Attack1.png", 10.0)

	_sprite = Sprite2D.new()
	_sprite.centered = true
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_sprite.position = Vector2(0, -27 * SPRITE_SCALE)   ## يظبط رجل الشخصية على مستوى الأرض
	add_child(_sprite)

	_play("idle")


## بتبني مشغّل صوت الجري - AudioStreamPlayer منفصل (مش GameAudio.play_sfx العادي)
## عشان نقدر نتحكم فيه (play/stop) حسب حالة الحركة، بدل صوت لحظي بيتشغل مرة
## واحدة وخلاص. بنعمل duplicate() للـ stream عشان نظبط خاصية loop من غير ما
## نأثر على أي استخدام تاني لنفس الملف preload في مكان تاني.
func _build_audio() -> void:
	_run_audio = AudioStreamPlayer.new()
	add_child(_run_audio)
	if run_sound:
		var stream: AudioStream = run_sound.duplicate()
		if stream is AudioStreamMP3:
			stream.loop = true
		_run_audio.stream = stream
	_run_audio.volume_db = -8.0


func _play(anim_name: String) -> void:
	if _animations == null or not _animations.has(anim_name):
		return
	if _current_anim == anim_name:
		return
	_current_anim = anim_name
	_frame_index = 0
	_frame_timer = 0.0
	_update_sprite_frame()


func _update_sprite_frame() -> void:
	var data: Dictionary = _animations[_current_anim]
	var tex: Texture2D = data["texture"]
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(_frame_index * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
	_sprite.texture = atlas


func _build_collision() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32 * SPRITE_SCALE * 0.8, 55 * SPRITE_SCALE)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -shape.size.y / 2.0)
	add_child(col)


func set_camera_limits(left: int, right: int, top: int, bottom: int) -> void:
	camera.limit_left = left
	camera.limit_right = right
	camera.limit_top = top
	camera.limit_bottom = bottom


## بتتنادى من LadderZone (main.gd) لحظة الدخول/الخروج من منطقة السلم - بتفصل
## الفيزيكا عن وضع الجاذبية العادي (شوف _physics_process_climbing).
func set_climbing(value: bool) -> void:
	if is_climbing == value:
		return
	is_climbing = value
	if is_climbing:
		velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if is_being_pulled or is_in_challenge:
		velocity = Vector2.ZERO
		_stop_run_sound()
		return

	if is_climbing:
		_stop_run_sound()   # مفيش صوت جري وهو ماسك السلم
		_physics_process_climbing(delta)
	else:
		_physics_process_normal(delta)

	move_and_slide()


func _physics_process_normal(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		GameAudio.play_sfx(jump_sound)

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	if direction > 0:
		_sprite.flip_h = false
	elif direction < 0:
		_sprite.flip_h = true

	_update_run_sound(direction)
	_update_animation_state(direction)
	_advance_frame(delta)


## وهو ماسك السلم: مفيش جاذبية خالص، ui_up/ui_down بيتحكموا في الصعود/النزول،
## ui_left/ui_right لسه شغالة (أبطأ شوية) عشان يقدر يسيب السلم من الجنب. مفيش
## قفز وهو على السلم.
func _physics_process_climbing(delta: float) -> void:
	var vertical: float = Input.get_axis("ui_up", "ui_down")
	velocity.y = vertical * CLIMB_SPEED

	var horizontal := Input.get_axis("ui_left", "ui_right")
	velocity.x = horizontal * SPEED * CLIMB_HORIZONTAL_MULT

	if horizontal > 0:
		_sprite.flip_h = false
	elif horizontal < 0:
		_sprite.flip_h = true

	if vertical != 0.0 or horizontal != 0.0:
		_play("run")
	else:
		_play("idle")

	_advance_frame(delta)


## بيشغل صوت الجري لوب طول ما اللاعب بيتحرك على الأرض، ويوقفه فورًا لما يقف
## أو يبقى في الهوا (قفزة/سقوط) عشان الصوت ميكملش وهو طاير.
func _update_run_sound(direction: float) -> void:
	var should_run: bool = direction != 0.0 and is_on_floor()
	if should_run and not _run_audio.playing:
		_run_audio.play()
	elif not should_run and _run_audio.playing:
		_run_audio.stop()


func _stop_run_sound() -> void:
	if _run_audio and _run_audio.playing:
		_run_audio.stop()


func _update_animation_state(direction: float) -> void:
	if not is_on_floor():
		if velocity.y < 0:
			_play("jump")
		else:
			_play("fall")
	elif direction != 0:
		_play("run")
	else:
		_play("idle")


func _advance_frame(delta: float) -> void:
	if _current_anim == "":
		return
	var data: Dictionary = _animations[_current_anim]
	_frame_timer += delta
	var frame_duration: float = 1.0 / data["fps"]
	if _frame_timer >= frame_duration:
		_frame_timer -= frame_duration
		_frame_index = (_frame_index + 1) % data["frame_count"]
		_update_sprite_frame()


func shake_camera(duration: float = 0.3, strength: float = 8.0) -> void:
	var elapsed := 0.0
	while elapsed < duration:
		camera.offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		await get_tree().create_timer(0.02).timeout
		elapsed += 0.02
	camera.offset = Vector2.ZERO


## بتتنادى لحظة سحب السلاسل — استخدام حركة "Take Hit" بدل ما اللاعب يقف عادي
func play_pulled_animation() -> void:
	_play("take_hit")

## بتتنادى لحظة أي غلطة داخل تحدي - فلاش سريع لحركة "TakeHit" ورجوع لـ idle.
## بنعملها كده (مش بس _play) لأن _physics_process بيتجمد أثناء التحدي
## (is_in_challenge = true)، يعني مفيش حد تاني هيرجّع الأنيميشن لوضعها العادي.
func flash_hurt(duration: float = 0.25) -> void:
	_play("take_hit")
	await get_tree().create_timer(duration).timeout
	if _current_anim == "take_hit":
		_play("idle")
