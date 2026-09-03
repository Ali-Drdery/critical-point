extends Node2D
## سلسلة بصرية بتتبع اللاعب بتأخير بسيط وهي ملاصقة للأرض دايمًا — بتدي إحساس
## إنها بتتجرجر وراه وهو ماشي. main.gd هو اللي بيربطها بالـ target والـ floor_y
## تلقائيًا في _ready() بتاعه، فمش محتاج تظبط حاجة من الـ Inspector يدويًا.

var target: Node2D = null
var floor_y: float = 0.0
@export var link_count: int = 10
@export var link_spacing_px: float = 22.0
@export var sample_distance: float = 8.0

var _history: Array[Vector2] = []
var _last_sample_pos: Vector2 = Vector2.ZERO


func setup(p_target: Node2D, p_floor_y: float) -> void:
	target = p_target
	floor_y = p_floor_y
	_last_sample_pos = target.global_position
	_history = [Vector2(_last_sample_pos.x, floor_y)]


func _process(_delta: float) -> void:
	if target == null:
		return
	var current: Vector2 = target.global_position
	if current.distance_to(_last_sample_pos) >= sample_distance:
		_history.push_front(Vector2(current.x, floor_y))
		_last_sample_pos = current
		var max_points: int = link_count + 2
		if _history.size() > max_points:
			_history.resize(max_points)
	queue_redraw()


func _draw() -> void:
	if _history.is_empty() or target == null:
		return
	var anchor: Vector2 = to_local(Vector2(target.global_position.x, floor_y))
	var points: Array[Vector2] = [anchor]
	for p in _history:
		points.append(to_local(p))

	var drawn: int = 0
	var accumulated: float = 0.0
	var prev: Vector2 = points[0]
	for i in range(1, points.size()):
		var seg: Vector2 = points[i]
		accumulated += prev.distance_to(seg)
		if accumulated >= link_spacing_px:
			draw_circle(seg, 7.0, Color(0.12, 0.12, 0.12, 0.9))
			draw_arc(seg, 7.0, 0.0, TAU, 10, Color(0.45, 0.45, 0.45, 0.6), 2.0, true)
			accumulated = 0.0
			drawn += 1
			if drawn >= link_count:
				break
		prev = seg
