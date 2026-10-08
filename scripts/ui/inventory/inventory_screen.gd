class_name InventoryScreen
extends Control
## 인벤토리 화면 (터치 + 마우스). 규칙:
##  - 상태 변경은 항상 GameAuthority.execute(command)로만 한다 (판정은 DropResolver).
##  - 화면 갱신은 authority.events_emitted를 받았을 때만 한다 (여기서는 전체 다시 그리기).
## 조작: 마우스는 누른 채 움직이면 집기, 터치는 약 0.25초 롱프레스로 집기. 짧게 탭하면 정보 패널.
## 드래그 중 R키 / 회전 버튼 / 두 번째 손가락 탭으로 회전, ESC나 바깥에 놓기는 취소.

const CELL: int = InventoryItemPainter.CELL_SIZE
const LONG_PRESS_SEC: float = 0.25
const MOUSE_SLOP: float = 6.0
const TOUCH_SLOP: float = 10.0
const EDGE_SCROLL_ZONE: float = 56.0
const EDGE_SCROLL_SPEED: float = 700.0

const SLOT_LABELS: Dictionary[EquipmentSlots.Slot, String] = {
	EquipmentSlots.Slot.PRIMARY_1: "주무기 1",
	EquipmentSlots.Slot.PRIMARY_2: "주무기 2",
	EquipmentSlots.Slot.SECONDARY: "보조무기",
	EquipmentSlots.Slot.HELMET: "헬멧",
	EquipmentSlots.Slot.ARMOR: "방탄복",
	EquipmentSlots.Slot.RIG: "전술 조끼",
	EquipmentSlots.Slot.BACKPACK: "배낭",
	EquipmentSlots.Slot.SECURE_CONTAINER: "보안 컨테이너",
}
## 내부 그리드를 보여 줄 장비 슬롯 (표시 순서).
const CONTAINER_SLOTS: Array[EquipmentSlots.Slot] = [
	EquipmentSlots.Slot.RIG,
	EquipmentSlots.Slot.BACKPACK,
	EquipmentSlots.Slot.SECURE_CONTAINER,
]
const ERROR_TEXT: Dictionary[StringName, String] = {
	CommandResult.NO_SPACE: "자리가 없습니다",
	CommandResult.NESTING_NOT_ALLOWED: "컨테이너 안에 컨테이너를 넣을 수 없습니다",
	CommandResult.SLOT_NOT_ALLOWED: "이 슬롯에 장착할 수 없습니다",
	CommandResult.SLOT_OCCUPIED: "슬롯이 이미 차 있습니다",
	CommandResult.STASH_LOCKED: "스태시는 잠겨 있습니다",
	CommandResult.NOT_STACKABLE: "합칠 수 없습니다",
}

enum State { IDLE, PENDING, DRAGGING }

var _authority: GameAuthority
var _inventory: Inventory
var _state: State = State.IDLE

var _slot_views: Array[InventorySlotView] = []
var _fixed_grid_views: Array[InventoryGridView] = []
var _container_views: Array[InventoryGridView] = []
var _container_signature: Array[int] = []
var _stash_view: InventoryGridView = null

var _press_item_id: int = 0
var _press_pos: Vector2 = Vector2.ZERO
var _press_from_touch: bool = false
var _press_msec: int = 0
var _pointer: Vector2 = Vector2.ZERO
var _grab_offset: Vector2 = Vector2.ZERO
var _drag_rotated: bool = false
var _resolution: DropResolver.Resolution = null
var _target_view: Control = null
var _info_item_id: int = 0
var _toast_tween: Tween = null
## 드래그 중 스태시 스크롤 위치 고정값 (터치 스크롤·휠이 끼어들지 못하게 매 프레임 되돌린다).
var _scroll_lock: int = 0

@onready var _slots_box: VBoxContainer = %SlotsBox
@onready var _pockets_row: HBoxContainer = %PocketsRow
@onready var _containers_box: VBoxContainer = %ContainersBox
@onready var _stash_column: VBoxContainer = %StashColumn
@onready var _stash_scroll: ScrollContainer = %StashScroll
@onready var _rotate_button: Button = %RotateButton
@onready var _ghost: InventoryDragGhost = %Ghost
@onready var _info_panel: PanelContainer = %InfoPanel
@onready var _name_label: Label = %NameLabel
@onready var _size_label: Label = %SizeLabel
@onready var _stack_label: Label = %StackLabel
@onready var _split_button: Button = %SplitButton
@onready var _close_button: Button = %CloseButton
@onready var _toast: Label = %Toast


## 노드가 트리에 들어온 뒤에 호출한다.
func setup(p_authority: GameAuthority) -> void:
	if _authority != null:
		_authority.events_emitted.disconnect(_on_events)
	_authority = p_authority
	_inventory = p_authority.inventory
	_authority.events_emitted.connect(_on_events)
	_build_fixed_views()
	_rebuild_containers()
	_redraw_all()


## 아이템이 지금 화면에 그려진 전역 영역. 화면에 없으면 빈 Rect2.
func item_global_rect(item_id: int) -> Rect2:
	var item: ItemInstance = _inventory.get_item(item_id)
	if item == null:
		return Rect2()
	for view: InventoryGridView in _all_grid_views():
		var grid: ItemGrid = _inventory.get_grid(view.key)
		if grid != null and grid.has_item(item):
			return view.item_global_rect(item)
	return Rect2()


func stash_view() -> InventoryGridView:
	return _stash_view


func _ready() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.11, 0.12, 0.15, 1.0)
	panel_style.border_color = Color(0.45, 0.5, 0.6, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	_info_panel.add_theme_stylebox_override("panel", panel_style)
	_rotate_button.pressed.connect(_rotate_drag)
	_split_button.pressed.connect(_on_split_pressed)
	_close_button.pressed.connect(_hide_info)


# --- 구성 ---

func _build_fixed_views() -> void:
	for child: Node in _slots_box.get_children():
		child.queue_free()
	for child: Node in _pockets_row.get_children():
		child.queue_free()
	_slot_views.clear()
	_fixed_grid_views.clear()
	for slot: EquipmentSlots.Slot in SLOT_LABELS:
		var view := InventorySlotView.new()
		_slots_box.add_child(view)
		view.setup(_inventory, slot, SLOT_LABELS[slot])
		view.item_pressed.connect(_on_item_pressed)
		_slot_views.append(view)
	for i: int in range(Inventory.POCKET_COUNT):
		_fixed_grid_views.append(_make_grid_view(_pockets_row, Inventory.pocket_key(i)))
	_stash_view = null
	for child: Node in _stash_scroll.get_children():
		child.queue_free()
	var has_stash: bool = _inventory.get_grid(Inventory.STASH) != null
	_stash_column.visible = has_stash
	if has_stash:
		_stash_view = _make_grid_view(_stash_scroll, Inventory.STASH)
		_stash_view.clip_control = _stash_scroll
		_fixed_grid_views.append(_stash_view)


func _make_grid_view(parent: Node, key: StringName) -> InventoryGridView:
	var view := InventoryGridView.new()
	parent.add_child(view)
	view.setup(_inventory, key)
	view.item_pressed.connect(_on_item_pressed)
	return view


## 장착된 컨테이너(리그·배낭·보안 컨테이너)의 내부 그리드 뷰. 장착 상태가 바뀐 경우에만 다시 만든다.
func _rebuild_containers() -> void:
	var signature: Array[int] = []
	for slot: EquipmentSlots.Slot in CONTAINER_SLOTS:
		var item: ItemInstance = _inventory.equipment.get_item(slot)
		signature.append(item.id if item != null and not item.grids.is_empty() else 0)
	if signature == _container_signature:
		return
	_container_signature = signature
	for child: Node in _containers_box.get_children():
		child.queue_free()
		_containers_box.remove_child(child)
	_container_views.clear()
	for slot: EquipmentSlots.Slot in CONTAINER_SLOTS:
		var item: ItemInstance = _inventory.equipment.get_item(slot)
		if item == null or item.grids.is_empty():
			continue
		var title := Label.new()
		title.text = "%s: %s" % [SLOT_LABELS[slot], item.def.display_name]
		_containers_box.add_child(title)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_containers_box.add_child(row)
		for i: int in range(item.grids.size()):
			_container_views.append(_make_grid_view(row, Inventory.item_grid_key(item.id, i)))


func _all_grid_views() -> Array[InventoryGridView]:
	var all: Array[InventoryGridView] = []
	all.append_array(_fixed_grid_views)
	all.append_array(_container_views)
	return all


func _redraw_all() -> void:
	for view: InventoryGridView in _all_grid_views():
		view.queue_redraw()
	for view: InventorySlotView in _slot_views:
		view.queue_redraw()


# --- 권한자 이벤트 → 화면 갱신 ---

func _on_events(_events: Array[DomainEvent]) -> void:
	if _state != State.IDLE:
		_end_drag()
	_hide_info()
	_rebuild_containers()
	_redraw_all()


# --- 입력 ---

func _on_item_pressed(view: Control, item: ItemInstance, local_pos: Vector2, from_touch: bool) -> void:
	if _state != State.IDLE:
		return
	_hide_info()
	_press_item_id = item.id
	_press_from_touch = from_touch
	_press_pos = view.get_global_transform() * local_pos
	_pointer = _press_pos
	_press_msec = Time.get_ticks_msec()
	if view is InventoryGridView:
		_grab_offset = local_pos - Vector2(item.position * CELL)
	else:
		_grab_offset = Vector2(item.size() * CELL) * 0.5
	_state = State.PENDING


func _process(delta: float) -> void:
	if _state == State.PENDING and _press_from_touch:
		if (Time.get_ticks_msec() - _press_msec) / 1000.0 >= LONG_PRESS_SEC:
			_begin_drag()
	elif _state == State.DRAGGING:
		_auto_scroll(delta)
		if _stash_scroll.scroll_vertical != _scroll_lock:
			_stash_scroll.scroll_vertical = _scroll_lock


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null:
		if key.pressed and not key.echo:
			if key.keycode == KEY_R and _state == State.DRAGGING:
				_rotate_drag()
				get_viewport().set_input_as_handled()
			elif key.keycode == KEY_ESCAPE and (_state != State.IDLE or _info_panel.visible):
				_end_drag()
				_hide_info()
				get_viewport().set_input_as_handled()
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		# 한 손가락으로 끌고 있는 동안 두 번째 손가락 탭 = 회전
		if touch.pressed and touch.index > 0 and _state == State.DRAGGING:
			_rotate_drag()
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		_on_pointer_moved(motion.position)
		return
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed:
		if _info_panel.visible and not _info_panel.get_global_rect().has_point(button.position):
			_hide_info()
	else:
		_on_pointer_released(button.position)


func _on_pointer_moved(pos: Vector2) -> void:
	_pointer = pos
	if _state == State.PENDING:
		var slop: float = TOUCH_SLOP if _press_from_touch else MOUSE_SLOP
		if pos.distance_to(_press_pos) > slop:
			if _press_from_touch:
				_state = State.IDLE   # 롱프레스 전에 움직임 = 스크롤 의도
			else:
				_begin_drag()
	elif _state == State.DRAGGING:
		_update_drag()


func _on_pointer_released(pos: Vector2) -> void:
	_pointer = pos
	if _state == State.PENDING:
		var item_id: int = _press_item_id
		_state = State.IDLE
		_show_info(item_id, _press_pos)
	elif _state == State.DRAGGING:
		_finish_drag()


# --- 드래그 ---

func _begin_drag() -> void:
	var item: ItemInstance = _inventory.get_item(_press_item_id)
	if item == null:
		_state = State.IDLE
		return
	_state = State.DRAGGING
	_drag_rotated = item.rotated
	_ghost.show_item(item, _drag_rotated)
	_set_dragging_id(item.id)
	_rotate_button.disabled = false
	# 드래그 중에는 스태시가 손가락·휠을 따라 스크롤되지 않게 고정한다 (끝 근처 자동 스크롤은 직접 처리).
	# SCROLL_MODE_DISABLED는 컨테이너 최소 높이를 내용 전체로 키워 레이아웃이 깨지므로 쓰지 않는다.
	_scroll_lock = _stash_scroll.scroll_vertical
	_update_drag()


func _update_drag() -> void:
	if _stash_scroll.scroll_vertical != _scroll_lock:
		_stash_scroll.scroll_vertical = _scroll_lock
	_ghost.global_position = _pointer - _grab_offset
	var item: ItemInstance = _inventory.get_item(_press_item_id)
	if item == null:
		_end_drag()
		return
	_clear_highlights()
	_resolution = null
	_target_view = _view_at(_pointer)
	if _target_view == null:
		return
	var footprint: Vector2i = item.size_for(_drag_rotated)
	if _target_view is InventoryGridView:
		var grid_view := _target_view as InventoryGridView
		var topleft: Vector2 = (_ghost.global_position - grid_view.global_position) / float(CELL)
		var cell := Vector2i((topleft + Vector2(0.5, 0.5)).floor())
		_resolution = DropResolver.resolve_grid(_inventory, item.id, grid_view.key, cell, _drag_rotated)
		grid_view.set_highlight(cell, footprint, _resolution.valid)
	else:
		var slot_view := _target_view as InventorySlotView
		_resolution = DropResolver.resolve_slot(_inventory, item.id, slot_view.slot)
		slot_view.set_highlight(_resolution.valid)


func _view_at(pos: Vector2) -> Control:
	for view: InventoryGridView in _all_grid_views():
		if view.is_visible_in_tree() and view.visible_global_rect().has_point(pos):
			return view
	for view: InventorySlotView in _slot_views:
		if view.is_visible_in_tree() and view.visible_global_rect().has_point(pos):
			return view
	return null


func _rotate_drag() -> void:
	if _state != State.DRAGGING:
		return
	var item: ItemInstance = _inventory.get_item(_press_item_id)
	if item == null:
		return
	if not item.def.can_rotate or item.def.width == item.def.height:
		_show_toast("이 아이템은 회전할 수 없습니다" if not item.def.can_rotate else "정사각형 아이템입니다")
		return
	_drag_rotated = not _drag_rotated
	_ghost.set_rotated(_drag_rotated)
	var new_size: Vector2 = Vector2(item.size_for(_drag_rotated) * CELL)
	_grab_offset = Vector2(_grab_offset.y, _grab_offset.x).clamp(Vector2.ZERO, new_size)
	_update_drag()


func _finish_drag() -> void:
	var resolution: DropResolver.Resolution = _resolution
	_end_drag()
	if resolution == null:
		return   # 바깥에 놓음 = 취소
	if not resolution.valid:
		_show_toast(ERROR_TEXT.get(resolution.error, String(resolution.error)))
	elif resolution.command != null:
		var result: CommandResult = _authority.execute(resolution.command)
		if not result.ok:
			_show_toast(ERROR_TEXT.get(result.error, String(result.error)))


func _end_drag() -> void:
	var was_active: bool = _state != State.IDLE
	_state = State.IDLE
	_resolution = null
	_target_view = null
	_press_item_id = 0
	if not was_active:
		return
	_ghost.hide_ghost()
	_clear_highlights()
	_set_dragging_id(0)
	_rotate_button.disabled = true


func _set_dragging_id(item_id: int) -> void:
	for view: InventoryGridView in _all_grid_views():
		view.dragging_item_id = item_id
		view.queue_redraw()
	for view: InventorySlotView in _slot_views:
		view.dragging_item_id = item_id
		view.queue_redraw()


func _clear_highlights() -> void:
	for view: InventoryGridView in _all_grid_views():
		view.clear_highlight()
	for view: InventorySlotView in _slot_views:
		view.clear_highlight()


func _auto_scroll(delta: float) -> void:
	if _stash_view == null or not _stash_view.is_visible_in_tree():
		return
	var rect: Rect2 = _stash_scroll.get_global_rect()
	if _pointer.x < rect.position.x or _pointer.x > rect.end.x:
		return
	var direction: float = 0.0
	if _pointer.y < rect.position.y + EDGE_SCROLL_ZONE:
		direction = -1.0
	elif _pointer.y > rect.end.y - EDGE_SCROLL_ZONE:
		direction = 1.0
	if direction != 0.0:
		_scroll_lock = maxi(0, _scroll_lock + int(direction * EDGE_SCROLL_SPEED * delta))
		_stash_scroll.scroll_vertical = _scroll_lock
		_update_drag()


# --- 정보 패널 ---

func _show_info(item_id: int, anchor: Vector2) -> void:
	var item: ItemInstance = _inventory.get_item(item_id)
	if item == null:
		return
	_info_item_id = item_id
	_name_label.text = item.def.display_name
	_size_label.text = "크기: %d×%d" % [item.def.width, item.def.height]
	_stack_label.visible = item.def.max_stack > 1
	_stack_label.text = "수량: %d / %d" % [item.stack_count, item.def.max_stack]
	_split_button.visible = item.stack_count >= 2
	var can_split: bool = DropResolver.plan_split(_inventory, item_id) != null
	_split_button.disabled = not can_split
	_split_button.text = "반으로 나누기" if can_split or item.stack_count < 2 else "반으로 나누기 (자리 없음)"
	_info_panel.visible = true
	_info_panel.reset_size()
	var panel_size: Vector2 = _info_panel.get_combined_minimum_size()
	var pos: Vector2 = anchor + Vector2(12, 12)
	var limit: Vector2 = get_viewport_rect().size - panel_size - Vector2(8, 8)
	_info_panel.position = Vector2(clampf(pos.x, 8.0, maxf(8.0, limit.x)), clampf(pos.y, 8.0, maxf(8.0, limit.y)))


func _hide_info() -> void:
	_info_panel.visible = false
	_info_item_id = 0


func _on_split_pressed() -> void:
	var command: SplitStackCommand = DropResolver.plan_split(_inventory, _info_item_id)
	_hide_info()
	if command == null:
		_show_toast(ERROR_TEXT[CommandResult.NO_SPACE])
		return
	var result: CommandResult = _authority.execute(command)
	if not result.ok:
		_show_toast(ERROR_TEXT.get(result.error, String(result.error)))


# --- 알림 ---

func _show_toast(text: String) -> void:
	_toast.text = text
	if _toast_tween != null:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.4)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
