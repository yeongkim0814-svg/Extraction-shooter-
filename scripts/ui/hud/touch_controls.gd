class_name TouchControls
extends Control
## 터치 컨트롤: 왼쪽 40% 어디든 닿는 곳에 뜨는 가상 조이스틱, 나머지 영역 드래그 = 시점,
## 오른쪽 버튼(사격·조준·재장전·앉기·점프·무기 교체). 손가락 index별로 역할을 추적하므로 멀티터치가 된다.
## Control 노드(Button)는 단일 터치만 받으므로 직접 그리고 직접 히트 테스트한다.
## 키보드/마우스가 쓰이면 숨기고, 터치가 다시 오면 보인다 (데스크톱 웹 대응).

const STICK_ZONE_RATIO: float = 0.4
const MARGIN: float = 28.0
const BUTTON_PAD: float = 10.0   # 버튼 주변 여유 히트 영역
const MIN_BUTTON_SIZE: float = 64.0
const LABEL_FONT_SIZE: int = 20
## 마지막 터치 후 이 시간 안의 키보드/마우스 입력은 컨트롤을 숨기지 않는다.
const MOUSE_HIDE_GRACE_MSEC: int = 1500

enum Role { NONE = -1, FIRE, ADS, RELOAD, CROUCH, JUMP, SWITCH, STICK = 100, LOOK = 101 }

const BUTTON_ROLES: Array[Role] = [Role.FIRE, Role.ADS, Role.RELOAD, Role.CROUCH, Role.JUMP, Role.SWITCH]
const LABELS: Array[String] = ["사격", "조준", "재장전", "앉기", "점프", "무기"]
## 버튼 지름 (px). 모두 64 이상.
const DIAMETERS: Array[float] = [124.0, 88.0, 88.0, 80.0, 88.0, 76.0]

const SRC: InputState.Source = InputState.Source.TOUCH

const FILL := Color(0.09, 0.1, 0.13, 0.5)
const FILL_PRESSED := Color(0.45, 0.62, 0.95, 0.7)
const FILL_FIRE_PRESSED := Color(0.85, 0.3, 0.25, 0.75)
const FILL_ACTIVE := Color(0.3, 0.45, 0.7, 0.6)

signal visibility_toggled(shown: bool)

var look_sens: float = InputState.TOUCH_LOOK_SENS

var _state: InputState
var _player: PlayerController
var _stick := FloatingStick.new()
var _touch_roles: Dictionary[int, int] = {}
var _centers: PackedVector2Array = PackedVector2Array()
var _pressed_count: Array[int] = [0, 0, 0, 0, 0, 0]
var _active: bool = false
var _last_touch_msec: int = -100000
var _toggle_on: Array[bool] = [false, false, false, false, false, false]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_centers.resize(BUTTON_ROLES.size())
	resized.connect(_layout)
	_layout()
	set_active(DisplayServer.is_touchscreen_available())


func bind(state: InputState, player: PlayerController) -> void:
	_state = state
	_player = player


func is_active() -> bool:
	return _active


func set_active(on: bool) -> void:
	if on == _active and visible == on:
		return
	_active = on
	visible = on
	if not on:
		_release_all()
	visibility_toggled.emit(on)


## 버튼 index의 화면 사각형 (스모크·테스트용).
func button_rect(index: int) -> Rect2:
	var r: float = DIAMETERS[index] * 0.5
	return Rect2(_centers[index] - Vector2(r, r), Vector2(r, r) * 2.0)


func button_index(role: Role) -> int:
	return BUTTON_ROLES.find(role)


func _layout() -> void:
	if _centers.size() != BUTTON_ROLES.size():
		return
	var w: float = size.x
	var h: float = size.y
	# 사격이 엄지 기준점. 나머지는 그 주변에 호 모양으로 배치
	var fire := Vector2(w - MARGIN - 62.0 - 14.0, h - MARGIN - 62.0 - 14.0)
	_centers[0] = fire
	_centers[1] = fire + Vector2(-142.0, 22.0)      # 조준: 왼쪽
	_centers[2] = fire + Vector2(0.0, -140.0)        # 재장전: 위
	_centers[3] = fire + Vector2(-258.0, 28.0)      # 앉기: 조준 왼쪽
	_centers[4] = fire + Vector2(-122.0, -118.0)    # 점프: 왼쪽 위
	_centers[5] = fire + Vector2(0.0, -246.0)        # 무기 교체: 재장전 위
	_stick.radius = clampf(h * 0.13, 70.0, 100.0)
	queue_redraw()


func _process(_delta: float) -> void:
	if _player == null:
		return
	var ads: bool = _player.is_ads()
	var crouch: bool = _player.is_crouching()
	if ads != _toggle_on[1] or crouch != _toggle_on[3]:
		_toggle_on[1] = ads
		_toggle_on[3] = crouch
		queue_redraw()


# --- 입력 ---

func _input(event: InputEvent) -> void:
	if event is InputEventKey or (event is InputEventMouse and event.device != InputEvent.DEVICE_ID_EMULATION):
		# 터치 직후에 브라우저가 흘려보내는 가짜 마우스 이동은 무시한다
		var since_touch: int = Time.get_ticks_msec() - _last_touch_msec
		if _active and since_touch > MOUSE_HIDE_GRACE_MSEC:
			set_active(false)
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_last_touch_msec = Time.get_ticks_msec()
		if touch.pressed:
			if not _active:
				set_active(true)
			_touch_down(touch.index, touch.position)
		else:
			_touch_up(touch.index)
	elif event is InputEventScreenDrag and _active:
		var drag := event as InputEventScreenDrag
		_last_touch_msec = Time.get_ticks_msec()
		_touch_move(drag.index, drag.position, drag.relative)


func _touch_down(index: int, pos: Vector2) -> void:
	if _state == null:
		return
	var hit: int = _button_at(pos)
	if hit >= 0:
		_touch_roles[index] = BUTTON_ROLES[hit]
		_pressed_count[hit] += 1
		_button_pressed(BUTTON_ROLES[hit])
	elif pos.x < size.x * STICK_ZONE_RATIO and not _stick.active:
		_touch_roles[index] = Role.STICK
		_stick.begin(pos)
		_apply_stick()
	else:
		_touch_roles[index] = Role.LOOK
	queue_redraw()


func _touch_up(index: int) -> void:
	if not _touch_roles.has(index):
		return
	var role: int = _touch_roles[index]
	_touch_roles.erase(index)
	if role == Role.STICK:
		_stick.end()
		_apply_stick()
	elif role == Role.LOOK:
		pass
	else:
		var button: int = BUTTON_ROLES.find(role as Role)
		_pressed_count[button] = maxi(_pressed_count[button] - 1, 0)
		if role == Role.FIRE and _pressed_count[button] == 0:
			_state.set_fire_held(SRC, false)
	queue_redraw()


func _touch_move(index: int, pos: Vector2, relative: Vector2) -> void:
	if _state == null or not _touch_roles.has(index):
		return
	var role: int = _touch_roles[index]
	if role == Role.STICK:
		_stick.update(pos)
		_apply_stick()
		queue_redraw()
	elif role == Role.LOOK or role == Role.FIRE:
		# 사격 버튼을 누른 채 드래그해도 시점이 움직인다 (엄지 하나로 사격 + 조준)
		_state.add_look(relative * look_sens)


func _apply_stick() -> void:
	_state.set_move(SRC, _stick.vector)
	_state.set_sprint(SRC, _stick.is_sprint())


func _button_pressed(role: Role) -> void:
	match role:
		Role.FIRE:
			_state.press_fire()
			_state.set_fire_held(SRC, true)
		Role.ADS:
			_state.press_ads_toggle()
		Role.RELOAD:
			_state.press_reload()
		Role.CROUCH:
			_state.press_crouch_toggle()
		Role.JUMP:
			_state.press_jump()
		Role.SWITCH:
			_state.press_switch()


func _button_at(pos: Vector2) -> int:
	for i: int in range(BUTTON_ROLES.size()):
		if pos.distance_to(_centers[i]) <= DIAMETERS[i] * 0.5 + BUTTON_PAD:
			return i
	return -1


func _release_all() -> void:
	_touch_roles.clear()
	_stick.end()
	for i: int in range(_pressed_count.size()):
		_pressed_count[i] = 0
	if _state != null:
		_state.release_source(SRC)
	queue_redraw()


# --- 그리기 ---

func _draw() -> void:
	var font: Font = get_theme_default_font()
	# 조이스틱: 닿으면 그 자리에, 아니면 희미한 안내 원
	if _stick.active:
		draw_circle(_stick.origin, _stick.radius, Color(0.09, 0.1, 0.13, 0.35))
		draw_arc(_stick.origin, _stick.radius, 0.0, TAU, 48, InventoryStyle.PANEL_BORDER, 2.0, true)
		draw_circle(_stick.knob_position(), _stick.radius * 0.42, Color(0.55, 0.68, 0.95, 0.6))
	else:
		var hint := Vector2(size.x * 0.12 + _stick.radius, size.y - MARGIN - _stick.radius - 20.0)
		draw_arc(hint, _stick.radius, 0.0, TAU, 48, Color(0.45, 0.5, 0.62, 0.35), 2.0, true)
	for i: int in range(BUTTON_ROLES.size()):
		var radius: float = DIAMETERS[i] * 0.5
		var fill: Color = FILL
		if _pressed_count[i] > 0:
			fill = FILL_FIRE_PRESSED if BUTTON_ROLES[i] == Role.FIRE else FILL_PRESSED
		elif _toggle_on[i]:
			fill = FILL_ACTIVE
		draw_circle(_centers[i], radius, fill)
		draw_arc(_centers[i], radius, 0.0, TAU, 40, Color(InventoryStyle.PANEL_BORDER, 0.85), 2.5, true)
		var text: String = LABELS[i]
		var text_pos := Vector2(_centers[i].x - radius, _centers[i].y + LABEL_FONT_SIZE * 0.35)
		draw_string_outline(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0,
				LABEL_FONT_SIZE, 5, Color(0, 0, 0, 0.7))
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0,
				LABEL_FONT_SIZE, InventoryStyle.TEXT)
