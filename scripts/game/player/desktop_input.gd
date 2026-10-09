class_name DesktopInput
extends Node
## 키보드/마우스 → InputState. WASD, Shift 달리기, Ctrl/C 앉기, Space 점프, 마우스 시점(포인터 잠금),
## 좌클릭 사격, 우클릭 ADS(누르는 동안), R 재장전, 1/2/3 무기 선택, Q 무기 교체, Esc 마우스 해제.
## 웹에서는 사용자 클릭 이벤트 안에서만 포인터 잠금을 요청한다. 잠겨 있지 않아도 좌클릭 사격은 된다.

const SRC: InputState.Source = InputState.Source.KEYBOARD

signal used   # 키보드·마우스가 쓰였다 (터치 컨트롤을 숨기는 신호)

var state: InputState


func bind(p_state: InputState) -> void:
	state = p_state


func is_mouse_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	if state == null:
		return
	var x: float = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var y: float = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	state.set_move(SRC, Vector2(x, y))
	state.set_sprint(SRC, Input.is_physical_key_pressed(KEY_SHIFT))
	state.set_crouch_held(SRC, Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_C))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and state != null:
		state.release_source(SRC)


func _input(event: InputEvent) -> void:
	if state == null:
		return
	# 터치에서 합성된 마우스 이벤트는 TouchControls가 직접 처리하므로 무시한다
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseMotion:
		if is_mouse_captured():
			state.add_look((event as InputEventMouseMotion).relative * InputState.MOUSE_LOOK_SENS)
		used.emit()
	elif event is InputEventMouseButton:
		_on_mouse_button(event as InputEventMouseButton)
	elif event is InputEventKey:
		_on_key(event as InputEventKey)


func _on_mouse_button(event: InputEventMouseButton) -> void:
	used.emit()
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not is_mouse_captured():
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			state.press_fire()
		state.set_fire_held(SRC, event.pressed)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		state.set_ads_held(SRC, event.pressed)


func _on_key(event: InputEventKey) -> void:
	if event.echo:
		return
	used.emit()
	if not event.pressed:
		return
	match event.physical_keycode:
		KEY_SPACE:
			state.press_jump()
		KEY_R:
			state.press_reload()
		KEY_Q:
			state.press_switch()
		KEY_1:
			state.select_slot(0)
		KEY_2:
			state.select_slot(1)
		KEY_3:
			state.select_slot(2)
		KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
