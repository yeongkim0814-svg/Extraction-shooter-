class_name InventoryScreen
extends Control
## 인벤토리 화면 (터치 + 마우스 동일). 규칙:
##  - 상태 변경은 항상 GameAuthority.execute(command)로만 한다 (판정은 DropResolver, 버튼 목록은 InventoryActions).
##  - 화면 갱신은 authority.events_emitted를 받았을 때만 한다 (여기서는 전체 다시 그리기).
## 레이아웃: 왼쪽 절반 = 장비 슬롯 페이지(세로 스크롤), 오른쪽 절반 = 스태시(세로 스크롤). 선택하면 아래에 액션 바.
## 조작 (롱프레스 없음, PressTracker가 판정):
##  - 아이템을 누른 채 10px 넘게 움직이면 즉시 드래그, 빈 곳을 누른 채 움직이면 그 쪽 절반이 스크롤
##  - 아이템을 짧게 탭하면 선택 (윤곽선 + 액션 바). 선택 중 빈 칸 탭 = 가장 가까운 자리로 이동,
##    같은 종류 스택 탭 = 합치기, 빈 슬롯 탭 = 장착, 선택한 아이템 다시 탭 / 그리드 바깥 탭 = 선택 해제
##  - R = 회전, ESC = 취소·선택 해제. 드래그 중에는 두 번째 손가락 탭도 회전.

signal selection_changed(item_id: int)
## 모딩 화면이 열리거나 닫혔다.
signal mod_screen_toggled(open: bool)
## 닫기 버튼을 눌렀다 (set_close_button_visible(true)일 때만 보인다). 실제로 숨기는 건 화면을 띄운 쪽이 한다.
signal close_requested

const MOD_SCENE: PackedScene = preload("res://scenes/ui/mod_screen.tscn")

const EDGE_SCROLL_ZONE: float = 56.0
const EDGE_SCROLL_SPEED: float = 700.0
const FLASH_SEC: float = 0.45
const GAP: int = 8
const SCREEN_MARGIN: int = 12
const COLUMN_GAP: int = 16
const SCROLLBAR_ALLOWANCE: float = 20.0
## 스크롤 컨테이너의 자체 터치 스크롤을 끄기 위한 값 (스크롤은 화면이 직접 처리한다. 마우스 휠은 그대로 동작).
const NATIVE_TOUCH_DEADZONE: int = 100000
## 선택한 아이템이 액션 바에 가리지 않게 올릴 때의 여유.
const BAR_CLEARANCE: float = 16.0
const CLOSE_SIZE := Vector2(112.0, 40.0)
## 컨테이너 구역: 슬롯 네모 여백(픽셀), 네모와 그리드 영역 사이 간격, 그리드 그룹 사이 간격, 구역 아래 여백.
const SQUARE_PAD: int = 8
const SQUARE_GRID_GAP: int = 8
const GROUP_GAP: int = 7
const SECTION_BOTTOM_PAD: int = 6

const SLOT_KO: Dictionary[EquipmentSlots.Slot, String] = {
	EquipmentSlots.Slot.PRIMARY_1: "슬링",
	EquipmentSlots.Slot.PRIMARY_2: "등",
	EquipmentSlots.Slot.SECONDARY: "권총집",
	EquipmentSlots.Slot.HELMET: "머리",
	EquipmentSlots.Slot.ARMOR: "방탄복",
	EquipmentSlots.Slot.RIG: "조끼",
	EquipmentSlots.Slot.BACKPACK: "가방",
	EquipmentSlots.Slot.SECURE_CONTAINER: "보안",
	EquipmentSlots.Slot.MELEE: "칼집",
	EquipmentSlots.Slot.FACE: "얼굴",
	EquipmentSlots.Slot.EAR: "귀",
	EquipmentSlots.Slot.EYE: "눈",
}
const SLOT_EN: Dictionary[EquipmentSlots.Slot, String] = {
	EquipmentSlots.Slot.PRIMARY_1: "ON SLING",
	EquipmentSlots.Slot.PRIMARY_2: "ON BACK",
	EquipmentSlots.Slot.SECONDARY: "HOLSTER",
	EquipmentSlots.Slot.HELMET: "HEAD",
	EquipmentSlots.Slot.ARMOR: "BODY ARMOR",
	EquipmentSlots.Slot.RIG: "RIG",
	EquipmentSlots.Slot.BACKPACK: "BAG",
	EquipmentSlots.Slot.SECURE_CONTAINER: "SAFE",
	EquipmentSlots.Slot.MELEE: "SHEATH",
	EquipmentSlots.Slot.FACE: "FACE",
	EquipmentSlots.Slot.EAR: "EAR",
	EquipmentSlots.Slot.EYE: "EYE",
}
## 내부 그리드를 보여 줄 장비 슬롯 (표시 순서).
const CONTAINER_SLOTS: Array[EquipmentSlots.Slot] = [
	EquipmentSlots.Slot.RIG,
	EquipmentSlots.Slot.BACKPACK,
	EquipmentSlots.Slot.SECURE_CONTAINER,
]
const SECTION_TITLE: Dictionary[EquipmentSlots.Slot, String] = {
	EquipmentSlots.Slot.RIG: "군장",
	EquipmentSlots.Slot.BACKPACK: "배낭",
	EquipmentSlots.Slot.SECURE_CONTAINER: "보안 컨테이너",
}
## 빈 슬롯 네모 안에 흐리게 보이는 안내 이름.
const SECTION_PLACEHOLDER: Dictionary[EquipmentSlots.Slot, String] = {
	EquipmentSlots.Slot.RIG: "전술 조끼",
	EquipmentSlots.Slot.BACKPACK: "배낭",
	EquipmentSlots.Slot.SECURE_CONTAINER: "보안 컨테이너",
}
const ERROR_TEXT: Dictionary[StringName, String] = {
	CommandResult.NO_SPACE: "자리가 없습니다",
	CommandResult.NESTING_NOT_ALLOWED: "컨테이너 안에 컨테이너를 넣을 수 없습니다",
	CommandResult.SLOT_NOT_ALLOWED: "이 슬롯에 장착할 수 없습니다",
	CommandResult.SLOT_OCCUPIED: "슬롯이 이미 차 있습니다",
	CommandResult.STASH_LOCKED: "스태시는 잠겨 있습니다",
	CommandResult.NOT_STACKABLE: "합칠 수 없습니다",
	CommandResult.NOT_REVEALED: "수색해야 볼 수 있습니다",
}
const SEARCH_BUTTON_SIZE := Vector2(130.0, 44.0)


## 화면 좌표 아래에서 찾은 뷰와 그 안의 아이템.
class Hit:
	var view: Control = null
	var item: ItemInstance = null
	## 수색 전이라 선택·드래그할 수 없는 아이템 (있으면 item은 null).
	var hidden_item: ItemInstance = null


var _authority: GameAuthority
var _inventory: Inventory
var _cell: int = InventoryItemPainter.CELL_SIZE

var _slot_views: Array[InventorySlotView] = []
var _fixed_grid_views: Array[InventoryGridView] = []
var _container_views: Array[InventoryGridView] = []
var _container_bodies: Dictionary[EquipmentSlots.Slot, Control] = {}
var _container_groups: Dictionary[EquipmentSlots.Slot, Array] = {}
var _container_signature: Array[int] = []
var _stash_view: InventoryGridView = null
## 열린 월드 컨테이너(시체·상자)의 그리드 뷰. 스태시가 없을 때 오른쪽 절반에 그린다.
var _loot_views: Array[InventoryGridView] = []
## 월드 컨테이너 키 → 머리글의 수색 버튼.
var _search_buttons: Dictionary[StringName, Button] = {}

var _tracker := PressTracker.new()
var _press_hit: Hit = null
var _scroll_target: ScrollContainer = null
var _scroll_start: int = 0

var _pointer: Vector2 = Vector2.ZERO
var _grab_offset: Vector2 = Vector2.ZERO
var _drag_item_id: int = 0
var _drag_rotated: bool = false
var _resolution: DropResolver.Resolution = null
var _target_view: Control = null

var _selected_id: int = 0
## 선택한 아이템을 다음에 옮기거나 놓을 때 쓸 회전 상태.
var _sel_rotated: bool = false

var _toast_tween: Tween = null
var _flash_serial: int = 0

var _action_bar: InventoryActionBar
var _dialog: InventoryItemDialog
var _mod_screen: ModScreen
var _close_button: Button

@onready var _left_scroll: ScrollContainer = %LeftScroll
@onready var _right_scroll: ScrollContainer = %RightScroll
@onready var _slot_page: VBoxContainer = %SlotPage
@onready var _stash_content: VBoxContainer = %StashContent
@onready var _overlay: Control = %Overlay
@onready var _ghost: InventoryDragGhost = %Ghost
@onready var _toast: Label = %Toast


## 노드가 트리에 들어온 뒤에 호출한다.
func setup(p_authority: GameAuthority) -> void:
	if _authority != null:
		_authority.events_emitted.disconnect(_on_events)
	_authority = p_authority
	_inventory = p_authority.inventory
	_authority.events_emitted.connect(_on_events)
	_cell = _compute_cell()
	_apply_half_widths()
	_build_slot_page()
	_build_stash()
	_rebuild_containers()
	_redraw_all()


## 아이템이 지금 화면에 그려진 전역 영역. 화면에 없으면 빈 Rect2.
func item_global_rect(item_id: int) -> Rect2:
	var item: ItemInstance = _inventory.get_item(item_id)
	if item == null:
		return Rect2()
	for view: InventorySlotView in _slot_views:
		if view.equipped_item() == item:
			return view.item_global_rect()
	for view: InventoryGridView in _all_grid_views():
		var grid: ItemGrid = _inventory.get_grid(view.key)
		if grid != null and grid.has_item(item):
			return view.item_global_rect(item)
	return Rect2()


## 화면에 띄운 토스트 한 줄 (HUD가 가려져 있는 동안 게임 쪽 알림도 여기로 보낸다).
func show_toast(text: String) -> void:
	_show_toast(text)


## 월드 컨테이너 머리글의 수색 버튼 전역 영역 (스모크·테스트용). 없으면 빈 Rect2.
func search_button_rect(key: StringName) -> Rect2:
	var button: Button = _search_buttons.get(key)
	return button.get_global_rect() if button != null and button.is_visible_in_tree() else Rect2()


func search_button_text(key: StringName) -> String:
	var button: Button = _search_buttons.get(key)
	return button.text if button != null else ""


## 그리드(key)의 cell 칸에서 size 칸 크기 영역이 화면에 완전히 보이는 전역 영역. 안 보이면 빈 Rect2.
func visible_cell_rect(key: StringName, cell: Vector2i, size: Vector2i) -> Rect2:
	for view: InventoryGridView in _all_grid_views():
		if view.key != key or not view.is_visible_in_tree():
			continue
		var rect := Rect2(view.global_position + Vector2(cell * _cell), Vector2(size * _cell))
		var visible: Rect2 = view.visible_global_rect()
		if visible.encloses(rect) and get_viewport_rect().encloses(rect):
			return rect
	return Rect2()


func stash_view() -> InventoryGridView:
	return _stash_view


func cell_size() -> int:
	return _cell


func selected_item_id() -> int:
	return _selected_id


## 슬롯 박스의 전역 영역 (스모크 테스트용).
func slot_global_rect(slot: EquipmentSlots.Slot) -> Rect2:
	for view: InventorySlotView in _slot_views:
		if view.slot == slot:
			return view.get_global_rect()
	return Rect2()


## (왼쪽 슬롯 페이지, 오른쪽 스태시)의 세로 스크롤 위치.
func scroll_positions() -> Vector2i:
	return Vector2i(_left_scroll.scroll_vertical, _right_scroll.scroll_vertical)


func all_slots() -> Array[EquipmentSlots.Slot]:
	var slots: Array[EquipmentSlots.Slot] = []
	for view: InventorySlotView in _slot_views:
		slots.append(view.slot)
	return slots


func is_mod_screen_open() -> bool:
	return _mod_screen != null and _mod_screen.is_open()


func mod_screen() -> ModScreen:
	return _mod_screen


## 오른쪽 위 닫기 버튼 표시 여부 (레이드·전투 중 가방으로 쓸 때 켠다).
func set_close_button_visible(on: bool) -> void:
	_close_button.visible = on


func close_button_rect() -> Rect2:
	return _close_button.get_global_rect()


func action_button_rects() -> Dictionary[String, Rect2]:
	return _action_bar.button_rects()


func dialog_button_rects() -> Dictionary[String, Rect2]:
	return _dialog.button_rects()


func _ready() -> void:
	_left_scroll.scroll_deadzone = NATIVE_TOUCH_DEADZONE
	_right_scroll.scroll_deadzone = NATIVE_TOUCH_DEADZONE
	_action_bar = InventoryActionBar.new()
	_overlay.add_child(_action_bar)
	_action_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_action_bar.offset_top = -InventoryActionBar.BAR_HEIGHT - 8.0
	_action_bar.offset_bottom = -8.0
	_action_bar.offset_left = SCREEN_MARGIN
	_action_bar.offset_right = -SCREEN_MARGIN
	_action_bar.action_pressed.connect(_on_action_pressed)
	_dialog = InventoryItemDialog.new()
	_overlay.add_child(_dialog)
	_dialog.discard_confirmed.connect(_on_discard_confirmed)
	_close_button = Button.new()
	_close_button.text = "닫기"
	_close_button.focus_mode = Control.FOCUS_NONE
	InventoryStyle.style_button(_close_button)
	_close_button.add_theme_font_size_override("font_size", 16)
	_overlay.add_child(_close_button)
	_close_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_close_button.offset_left = -CLOSE_SIZE.x - SCREEN_MARGIN
	_close_button.offset_right = -SCREEN_MARGIN
	_close_button.offset_top = 6.0
	_close_button.offset_bottom = 6.0 + CLOSE_SIZE.y
	_close_button.visible = false
	_close_button.pressed.connect(func() -> void: close_requested.emit())
	_mod_screen = MOD_SCENE.instantiate() as ModScreen
	add_child(_mod_screen)
	_mod_screen.closed.connect(func() -> void: mod_screen_toggled.emit(false))
	get_viewport().size_changed.connect(_on_viewport_resized)


# --- 구성 ---

## 오른쪽 스태시 한 열이 가용 너비에 들어가도록 칸 크기를 정한다 (MIN~MAX로 제한).
func _compute_cell() -> int:
	var stash: ItemGrid = _inventory.get_grid(Inventory.STASH) if _inventory != null else null
	var columns: int = stash.width if stash != null else 10
	var available: float = _half_width() - SCROLLBAR_ALLOWANCE
	return clampi(floori(available / float(columns)), InventoryItemPainter.MIN_CELL_SIZE,
			InventoryItemPainter.MAX_CELL_SIZE)


func _half_width() -> float:
	var total: float = get_viewport_rect().size.x - 2.0 * SCREEN_MARGIN - COLUMN_GAP
	return floorf(total / 2.0)


## 두 절반의 너비를 같게 맞춘다 (스크롤 컨테이너의 최소 너비가 내용에 끌려가지 않게).
func _apply_half_widths() -> void:
	var half: float = _half_width()
	_left_scroll.custom_minimum_size.x = half
	_right_scroll.custom_minimum_size.x = half


func _on_viewport_resized() -> void:
	if _inventory == null:
		return
	_apply_half_widths()
	var new_cell: int = _compute_cell()
	if new_cell == _cell:
		_layout_containers()
		return
	_cell = new_cell
	for view: InventoryGridView in _all_grid_views():
		view.set_cell_size(_cell)
	for view: InventorySlotView in _slot_views:
		view.set_cell_size(_cell)
	_layout_containers()


func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", InventoryStyle.TEXT_DIM)
	return label


func _make_slot(parent: Control, slot: EquipmentSlots.Slot, cells: Vector2,
		extra_px: Vector2 = Vector2.ZERO) -> InventorySlotView:
	var view := InventorySlotView.new()
	parent.add_child(view)
	view.setup(_inventory, slot, SLOT_KO[slot], SLOT_EN[slot], cells, _cell, extra_px)
	view.clip_control = _left_scroll
	_slot_views.append(view)
	return view


func _hbox(parent: Control) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", GAP)
	parent.add_child(box)
	return box


func _vbox(parent: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", GAP)
	parent.add_child(box)
	return box


## 슬롯 페이지: 머리/귀 | 방탄복 | 얼굴/눈 → 슬링+권총집 → 등+칼집 → 주머니 4칸 → 조끼·가방·보안 (슬롯 박스 + 내부 그리드).
func _build_slot_page() -> void:
	_clear_children(_slot_page)
	_slot_views.clear()
	_fixed_grid_views.clear()
	_container_bodies.clear()
	_container_groups.clear()
	_container_signature = []
	var block := _hbox(_slot_page)
	var left_col := _vbox(block)
	_make_slot(left_col, EquipmentSlots.Slot.HELMET, Vector2(2, 2))
	_make_slot(left_col, EquipmentSlots.Slot.EAR, Vector2(2, 2))
	_make_slot(block, EquipmentSlots.Slot.ARMOR, Vector2(3, 4), Vector2(0, GAP))
	var right_col := _vbox(block)
	_make_slot(right_col, EquipmentSlots.Slot.FACE, Vector2(2, 2))
	_make_slot(right_col, EquipmentSlots.Slot.EYE, Vector2(2, 2))
	var sling := _hbox(_slot_page)
	_make_slot(sling, EquipmentSlots.Slot.PRIMARY_1, Vector2(5, 2), Vector2(GAP, 0))
	_make_slot(sling, EquipmentSlots.Slot.SECONDARY, Vector2(2, 2))
	var back := _hbox(_slot_page)
	_make_slot(back, EquipmentSlots.Slot.PRIMARY_2, Vector2(5, 2), Vector2(GAP, 0))
	_make_slot(back, EquipmentSlots.Slot.MELEE, Vector2(2, 2))
	_slot_page.add_child(_section_title("주머니  POCKETS"))
	var pockets := _hbox(_slot_page)
	for i: int in range(Inventory.POCKET_COUNT):
		_fixed_grid_views.append(_make_grid_view(pockets, Inventory.pocket_key(i), _left_scroll))
	for slot: EquipmentSlots.Slot in CONTAINER_SLOTS:
		_build_section(slot)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = InventoryActionBar.BAR_HEIGHT + 24.0
	_slot_page.add_child(spacer)


## 컨테이너 구역 하나: 구분선 + 머리글 띠 + 본문(고정 크기 슬롯 네모 + 오른쪽에 내부 그리드 그룹).
func _build_section(slot: EquipmentSlots.Slot) -> void:
	var divider := ColorRect.new()
	divider.color = InventoryStyle.SECTION_DIVIDER
	divider.custom_minimum_size.y = 1.0
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_page.add_child(divider)
	var header := Label.new()
	header.text = SECTION_TITLE[slot]
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", InventoryStyle.TEXT_DIM)
	header.add_theme_stylebox_override("normal", InventoryStyle.section_header_style())
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_page.add_child(header)
	var body := Control.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_page.add_child(body)
	var view: InventorySlotView = _make_slot(body, slot, Vector2(2, 2), Vector2(SQUARE_PAD, SQUARE_PAD))
	view.corner_name = SECTION_PLACEHOLDER[slot]
	view.position = Vector2.ZERO
	view.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_container_bodies[slot] = body
	_container_groups[slot] = []


func _body_width() -> float:
	return _half_width() - SCROLLBAR_ALLOWANCE


## 각 구역의 그리드 그룹을 배치하고 본문 높이를 정한다. 높이 = max(슬롯 네모, 그리드 영역) + 여백.
func _layout_containers() -> void:
	for slot: EquipmentSlots.Slot in CONTAINER_SLOTS:
		var body: Control = _container_bodies.get(slot)
		if body == null:
			continue
		var square: float = 2.0 * float(_cell) + float(SQUARE_PAD)
		var origin_x: float = square + float(SQUARE_GRID_GAP)
		var views: Array = _container_groups[slot]
		var sizes: Array[Vector2i] = []
		var offsets: Array[Vector2i] = []
		var item: ItemInstance = _inventory.equipment.get_item(slot)
		if item != null:
			sizes.assign(item.def.grids)
			offsets.assign(item.def.grid_offsets)
		var layout: ContainerLayout = ContainerLayout.compute(sizes, offsets, _cell,
				maxf(_body_width() - origin_x, 0.0), GROUP_GAP)
		for i: int in range(mini(views.size(), layout.rects.size())):
			var group := views[i] as InventoryGridView
			group.position = Vector2(origin_x, 0.0) + layout.rects[i].position
		body.custom_minimum_size = Vector2(_body_width(),
				maxf(square, layout.size.y) + float(SECTION_BOTTOM_PAD))


func _build_stash() -> void:
	_clear_children(_stash_content)
	_stash_view = null
	_loot_views.clear()
	var has_stash: bool = _inventory.get_grid(Inventory.STASH) != null
	var loot_keys: Array[StringName] = _inventory.external_keys()
	_right_scroll.visible = has_stash or not loot_keys.is_empty()
	if not has_stash:
		_build_loot(loot_keys)
		return
	_stash_content.add_child(_section_title("스태시  STASH"))
	_stash_view = _make_grid_view(_stash_content, Inventory.STASH, _right_scroll)
	_fixed_grid_views.append(_stash_view)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = InventoryActionBar.BAR_HEIGHT + 24.0
	_stash_content.add_child(spacer)


## 스태시가 없을 때 열려 있는 월드 컨테이너(시체·상자)를 오른쪽 절반에 보여 준다. 이름은 권한자의 container_titles.
func _build_loot(keys: Array[StringName]) -> void:
	_search_buttons.clear()
	if keys.is_empty():
		return
	_right_scroll.scroll_vertical = 0
	for key: StringName in keys:
		var title: String = _authority.container_titles.get(key, "컨테이너")
		_stash_content.add_child(_loot_header(key, title))
		var view: InventoryGridView = _make_grid_view(_stash_content, key, _right_scroll)
		view.search = _authority.searches.get(key)
		_loot_views.append(view)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = InventoryActionBar.BAR_HEIGHT + 24.0
	_stash_content.add_child(spacer)


## 월드 컨테이너 머리글: 이름 + (수색이 필요하면) 수색/중단/수색 완료 버튼.
func _loot_header(key: StringName, title: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	var label := _section_title("%s  LOOT" % title)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)   # 버튼은 제목 바로 옆에 둔다 (오른쪽 끝은 닫기 버튼이 가린다)
	if _authority.searches.has(key):
		var button := Button.new()
		InventoryStyle.style_button(button)
		button.custom_minimum_size = SEARCH_BUTTON_SIZE
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(_on_search_pressed.bind(key))
		row.add_child(button)
		_search_buttons[key] = button
		_refresh_search_button(key)
	return row


func _refresh_search_buttons() -> void:
	for key: StringName in _search_buttons:
		_refresh_search_button(key)


func _refresh_search_button(key: StringName) -> void:
	var button: Button = _search_buttons.get(key)
	var search: SearchState = _authority.searches.get(key)
	if button == null or search == null:
		return
	if search.is_complete():
		button.text = "수색 완료"
		button.disabled = true
	elif search.searching:
		button.text = "중단"
		button.disabled = false
	else:
		button.text = "수색"
		button.disabled = false


func _on_search_pressed(key: StringName) -> void:
	var search: SearchState = _authority.searches.get(key)
	if search == null or search.is_complete():
		return
	_authority.execute(SearchContainerCommand.new(key, not search.searching))


## 열자마자 수색을 시작한다 (끝나지 않은 컨테이너만). 이벤트 처리 중이 아니라 프레임 끝에 실행한다.
func _auto_start_search(key: StringName) -> void:
	var search: SearchState = _authority.searches.get(key)
	if search == null or search.searching or search.is_complete() or _inventory.get_grid(key) == null:
		return
	_authority.execute(SearchContainerCommand.new(key, true))


func _make_grid_view(parent: Node, key: StringName, clip: Control) -> InventoryGridView:
	var view := InventoryGridView.new()
	parent.add_child(view)
	view.setup(_inventory, key, _cell)
	view.clip_control = clip
	view.selected_item_id = _selected_id
	return view


## 장착된 컨테이너(리그·가방·보안 컨테이너)의 내부 그리드 뷰. 장착 상태가 바뀐 경우에만 다시 만든다.
func _rebuild_containers() -> void:
	var signature: Array[int] = []
	for slot: EquipmentSlots.Slot in CONTAINER_SLOTS:
		var item: ItemInstance = _inventory.equipment.get_item(slot)
		signature.append(item.id if item != null and not item.grids.is_empty() else 0)
	if signature == _container_signature:
		return
	_container_signature = signature
	_container_views.clear()
	for slot: EquipmentSlots.Slot in CONTAINER_SLOTS:
		var body: Control = _container_bodies[slot]
		var groups: Array = _container_groups[slot]
		for old: Variant in groups:
			var old_view := old as InventoryGridView
			body.remove_child(old_view)
			old_view.queue_free()
		groups.clear()
		var item: ItemInstance = _inventory.equipment.get_item(slot)
		if item == null:
			continue
		for i: int in range(item.grids.size()):
			var group: InventoryGridView = _make_grid_view(body, Inventory.item_grid_key(item.id, i), _left_scroll)
			group.bordered = true
			groups.append(group)
			_container_views.append(group)
	_layout_containers()


func _all_grid_views() -> Array[InventoryGridView]:
	var all: Array[InventoryGridView] = []
	all.append_array(_fixed_grid_views)
	all.append_array(_loot_views)
	all.append_array(_container_views)
	return all


func _redraw_all() -> void:
	for view: InventoryGridView in _all_grid_views():
		view.queue_redraw()
	for view: InventorySlotView in _slot_views:
		view.queue_redraw()


# --- 권한자 이벤트 → 화면 갱신 ---

func _on_events(events: Array[DomainEvent]) -> void:
	var structural: bool = false   # 수색 진행(공개·시작·중단)만 있는 이벤트는 드래그를 끊지 않는다
	for event: DomainEvent in events:
		if event.type != DomainEvent.ITEM_REVEALED and event.type != DomainEvent.SEARCH_CHANGED:
			structural = true
	if structural and _tracker.is_dragging():
		_end_drag()
	for event: DomainEvent in events:
		if event.type == DomainEvent.CONTAINER_OPENED or event.type == DomainEvent.CONTAINER_CLOSED:
			_deselect()
			_build_stash()
			break
	for event: DomainEvent in events:
		if event.type == DomainEvent.CONTAINER_OPENED:
			_auto_start_search.call_deferred(event.data["container"] as StringName)
	_refresh_search_buttons()
	_rebuild_containers()
	if _selected_id != 0:
		var item: ItemInstance = _inventory.get_item(_selected_id)
		if item == null:
			_dialog.close()
			_deselect()
		else:
			_action_bar.show_for(item, InventoryActions.for_item(_inventory, _selected_id), _sel_rotated)
	_redraw_all()


# --- 입력 ---

func _input(event: InputEvent) -> void:
	if is_mod_screen_open():
		return   # 모딩 화면이 입력을 가져간다
	var key := event as InputEventKey
	if key != null:
		if key.pressed and not key.echo:
			_on_key(key)
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		# 한 손가락으로 끌고 있는 동안 두 번째 손가락 탭 = 회전
		if touch.pressed and touch.index > 0 and _tracker.is_dragging():
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
		_on_pointer_pressed(button.position)
	else:
		_on_pointer_released(button.position)


func _on_key(key: InputEventKey) -> void:
	if key.keycode == KEY_R:
		if _tracker.is_dragging():
			_rotate_drag()
			get_viewport().set_input_as_handled()
		elif _selected_id != 0 and not _dialog.visible:
			_rotate_selected()
			get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE:
		if _dialog.visible:
			_dialog.close()
		elif _tracker.is_dragging():
			_end_drag()
		elif _selected_id != 0:
			_deselect()
		else:
			return
		get_viewport().set_input_as_handled()


func _on_pointer_pressed(pos: Vector2) -> void:
	_pointer = pos
	if _dialog.visible:
		return
	if _action_bar.visible and _action_bar.get_global_rect().has_point(pos):
		return   # 액션 바 버튼이 직접 처리한다
	var hit: Hit = _pick(pos)
	_press_hit = hit
	_scroll_target = null
	if hit.hidden_item != null:
		_show_toast(ERROR_TEXT[CommandResult.NOT_REVEALED])
	if hit.item != null:
		_grab_offset = _grab_offset_for(hit, pos)
	else:
		_scroll_target = _scroll_at(pos)
		if _scroll_target != null:
			_scroll_start = _scroll_target.scroll_vertical
	_tracker.press(pos, hit.item != null)


func _on_pointer_moved(pos: Vector2) -> void:
	_pointer = pos
	if _tracker.is_idle():
		return
	var outcome: PressTracker.Outcome = _tracker.move(pos)
	if outcome == PressTracker.Outcome.DRAG_STARTED:
		_begin_drag()
	if _tracker.is_dragging():
		_update_drag()
	elif _tracker.is_scrolling() and _scroll_target != null:
		_scroll_target.scroll_vertical = _scroll_start - roundi(pos.y - _tracker.origin.y)


func _on_pointer_released(pos: Vector2) -> void:
	_pointer = pos
	var origin: Vector2 = _tracker.origin
	var outcome: PressTracker.Outcome = _tracker.release(pos)
	match outcome:
		PressTracker.Outcome.TAP_ITEM, PressTracker.Outcome.TAP_EMPTY:
			_handle_tap(origin)
		PressTracker.Outcome.DRAG_ENDED:
			_finish_drag()
	_press_hit = null
	_scroll_target = null


## 전역 좌표 아래의 뷰와 아이템. 장착된 슬롯은 박스 전체가 아이템 영역이다.
func _pick(pos: Vector2) -> Hit:
	var hit := Hit.new()
	for view: InventoryGridView in _all_grid_views():
		if view.is_visible_in_tree() and view.visible_global_rect().has_point(pos):
			hit.view = view
			var found: ItemInstance = view.item_at_global(pos)
			if found != null and _inventory.is_hidden(found):
				hit.hidden_item = found
			else:
				hit.item = found
			return hit
	for view: InventorySlotView in _slot_views:
		if view.is_visible_in_tree() and view.visible_global_rect().has_point(pos):
			hit.view = view
			hit.item = view.equipped_item()
			return hit
	return hit


func _grab_offset_for(hit: Hit, pos: Vector2) -> Vector2:
	if hit.view is InventoryGridView:
		return pos - (hit.view as InventoryGridView).item_global_rect(hit.item).position
	return Vector2(hit.item.size() * _cell) * 0.5


func _scroll_at(pos: Vector2) -> ScrollContainer:
	for scroll: ScrollContainer in [_left_scroll, _right_scroll]:
		if scroll.is_visible_in_tree() and scroll.get_global_rect().has_point(pos):
			return scroll
	return null


# --- 탭: 선택 / 이동 / 장착 ---

func _handle_tap(pos: Vector2) -> void:
	var hit: Hit = _pick(pos)
	if hit.hidden_item != null:
		return   # 수색 전 아이템: 누를 때 이미 안내했고, 선택은 그대로 둔다
	if _selected_id == 0:
		if hit.item != null:
			_select(hit.item.id)
		return
	var selected: ItemInstance = _inventory.get_item(_selected_id)
	if selected == null:
		_deselect()
		return
	if hit.view == null or hit.item == selected:
		_deselect()   # 그리드·슬롯 바깥 또는 선택한 아이템을 다시 탭
		return
	if hit.view is InventoryGridView:
		var grid_view := hit.view as InventoryGridView
		if hit.item != null and not selected.can_stack_with(hit.item):
			_select(hit.item.id)   # 합칠 수 없는 다른 아이템 = 선택 전환
			return
		_tap_move(grid_view, grid_view.cell_at_global(pos), selected)
	else:
		var slot_view := hit.view as InventorySlotView
		if hit.item != null:
			_select(hit.item.id)
			return
		_tap_equip(slot_view)


func _tap_move(view: InventoryGridView, tapped: Vector2i, selected: ItemInstance) -> void:
	var resolution: DropResolver.Resolution = DropResolver.resolve_tap_grid(
			_inventory, selected.id, view.key, tapped, _sel_rotated)
	if not resolution.valid:
		view.set_highlight(tapped, selected.size_for(_sel_rotated), false)
		_schedule_flash_clear()
		_show_toast(ERROR_TEXT.get(resolution.error, String(resolution.error)))
		return
	if resolution.command == null:
		return   # 이미 그 자리
	_run_command(resolution.command, false)


func _tap_equip(view: InventorySlotView) -> void:
	var resolution: DropResolver.Resolution = DropResolver.resolve_slot(_inventory, _selected_id, view.slot)
	if not resolution.valid:
		view.set_highlight(false)
		_schedule_flash_clear()
		_show_toast(ERROR_TEXT.get(resolution.error, String(resolution.error)))
		return
	_run_command(resolution.command, false)


## 명령을 실행하고 실패하면 알림. 성공하면 keep_selection이 아닌 한 선택을 푼다.
func _run_command(command: GameCommand, keep_selection: bool) -> bool:
	var result: CommandResult = _authority.execute(command)
	if not result.ok:
		_show_toast(ERROR_TEXT.get(result.error, String(result.error)))
		return false
	if not keep_selection:
		_deselect()
	return true


func _schedule_flash_clear() -> void:
	_flash_serial += 1
	var serial: int = _flash_serial
	get_tree().create_timer(FLASH_SEC).timeout.connect(func() -> void:
		if serial == _flash_serial and not _tracker.is_dragging():
			_clear_highlights())


func _select(item_id: int) -> void:
	var item: ItemInstance = _inventory.get_item(item_id)
	if item == null or _inventory.is_hidden(item):
		return
	_dialog.close()
	_selected_id = item_id
	_sel_rotated = item.rotated
	_set_selected_views(item_id)
	_action_bar.show_for(item, InventoryActions.for_item(_inventory, item_id), _sel_rotated)
	_reveal_above_bar(item_id)
	selection_changed.emit(item_id)


func _deselect() -> void:
	if _selected_id == 0:
		return
	_selected_id = 0
	_set_selected_views(0)
	_action_bar.hide_bar()
	_clear_highlights()
	selection_changed.emit(0)


func _set_selected_views(item_id: int) -> void:
	for view: InventoryGridView in _all_grid_views():
		view.selected_item_id = item_id
		view.queue_redraw()
	for view: InventorySlotView in _slot_views:
		view.selected_item_id = item_id
		view.queue_redraw()


## 선택한 아이템이 액션 바 뒤에 가려지면 그 쪽 스크롤을 올려 보이게 한다.
func _reveal_above_bar(item_id: int) -> void:
	var rect: Rect2 = item_global_rect(item_id)
	if not rect.has_area():
		return
	var bar_top: float = get_viewport_rect().size.y - InventoryActionBar.BAR_HEIGHT - 8.0 - BAR_CLEARANCE
	var overlap: float = rect.end.y - bar_top
	if overlap <= 0.0:
		return
	var scroll: ScrollContainer = _scroll_at(rect.get_center())
	if scroll == null:
		return
	var room: float = rect.position.y - scroll.get_global_rect().position.y - 4.0
	scroll.scroll_vertical += roundi(minf(overlap, maxf(room, 0.0)))


# --- 액션 바 ---

func _on_action_pressed(action: InventoryActions.Action) -> void:
	var item: ItemInstance = _inventory.get_item(_selected_id)
	if item == null:
		return
	match action:
		InventoryActions.Action.ROTATE:
			_rotate_selected()
		InventoryActions.Action.INFO:
			_dialog.show_info(item)
		InventoryActions.Action.SPLIT:
			var split: SplitStackCommand = DropResolver.plan_split(_inventory, item.id)
			if split == null:
				_show_toast(ERROR_TEXT[CommandResult.NO_SPACE])
			else:
				_run_command(split, true)
		InventoryActions.Action.EQUIP:
			var equip: DropResolver.Resolution = DropResolver.plan_equip(_inventory, item.id)
			if equip.valid:
				_run_command(equip.command, false)
			else:
				_show_toast(ERROR_TEXT.get(equip.error, String(equip.error)))
		InventoryActions.Action.UNEQUIP:
			var unequip: DropResolver.Resolution = DropResolver.plan_unequip(_inventory, item.id)
			if unequip.valid and unequip.command != null:
				_run_command(unequip.command, false)
			else:
				_show_toast(ERROR_TEXT.get(unequip.error, String(unequip.error)))
		InventoryActions.Action.MOD:
			_mod_screen.open(_authority, item.id)
			mod_screen_toggled.emit(true)
		InventoryActions.Action.DISCARD:
			_dialog.show_discard_confirm(item)
		InventoryActions.Action.SELL:
			# 판매 훅: InventoryActions.SELL_ENABLED를 true로 바꾸고 여기서 판매 명령(M6 이후)을 실행한다.
			pass


func _on_discard_confirmed(item_id: int) -> void:
	_run_command(DiscardItemCommand.new(item_id), false)


## 회전 버튼 / R키. 다음 이동·놓기에 쓸 회전 상태를 뒤집고, 제자리에 들어가면 바로 돌린다.
func _rotate_selected() -> void:
	var item: ItemInstance = _inventory.get_item(_selected_id)
	if item == null:
		return
	if not DropResolver.can_rotate(item):
		_show_toast("이 아이템은 회전할 수 없습니다" if not item.def.can_rotate else "정사각형 아이템입니다")
		return
	_sel_rotated = not _sel_rotated
	_action_bar.update_rotation(item, _sel_rotated)
	var in_place: MoveItemCommand = DropResolver.plan_rotate_in_place(_inventory, item.id, _sel_rotated)
	if in_place != null:
		_run_command(in_place, true)
	else:
		_show_toast("제자리에는 안 들어갑니다. 다음 이동에 회전이 적용됩니다")


# --- 드래그 ---

func _begin_drag() -> void:
	var item: ItemInstance = _press_hit.item if _press_hit != null else null
	if item == null:
		_tracker.cancel()
		return
	_deselect()
	_drag_item_id = item.id
	_drag_rotated = item.rotated
	_ghost.show_item(item, _drag_rotated, _cell)
	_set_dragging_id(item.id)


func _update_drag() -> void:
	_ghost.global_position = _pointer - _grab_offset
	var item: ItemInstance = _inventory.get_item(_drag_item_id)
	if item == null:
		_end_drag()
		return
	_clear_highlights()
	_resolution = null
	_target_view = _pick(_pointer).view
	if _target_view == null:
		return
	var footprint: Vector2i = item.size_for(_drag_rotated)
	if _target_view is InventoryGridView:
		var grid_view := _target_view as InventoryGridView
		var topleft: Vector2 = (_ghost.global_position - grid_view.global_position) / float(_cell)
		var cell := Vector2i((topleft + Vector2(0.5, 0.5)).floor())
		_resolution = DropResolver.resolve_grid(_inventory, item.id, grid_view.key, cell, _drag_rotated)
		grid_view.set_highlight(cell, footprint, _resolution.valid)
	else:
		var slot_view := _target_view as InventorySlotView
		_resolution = DropResolver.resolve_slot(_inventory, item.id, slot_view.slot)
		slot_view.set_highlight(_resolution.valid)


func _rotate_drag() -> void:
	if not _tracker.is_dragging():
		return
	var item: ItemInstance = _inventory.get_item(_drag_item_id)
	if item == null:
		return
	if not DropResolver.can_rotate(item):
		_show_toast("이 아이템은 회전할 수 없습니다" if not item.def.can_rotate else "정사각형 아이템입니다")
		return
	_drag_rotated = not _drag_rotated
	_ghost.set_rotated(_drag_rotated)
	var new_size: Vector2 = Vector2(item.size_for(_drag_rotated) * _cell)
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
		_run_command(resolution.command, false)


func _end_drag() -> void:
	var was_dragging: bool = _drag_item_id != 0
	_tracker.cancel()
	_resolution = null
	_target_view = null
	_drag_item_id = 0
	if not was_dragging:
		return
	_ghost.hide_ghost()
	_clear_highlights()
	_set_dragging_id(0)


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


func _process(delta: float) -> void:
	if _tracker.is_dragging():
		_auto_scroll(delta)
	# 수색 진행 고리는 매 프레임 다시 그린다
	for view: InventoryGridView in _loot_views:
		if view.search != null and view.search.searching:
			view.queue_redraw()


## 드래그 중 포인터가 스크롤 영역의 위/아래 끝 근처에 있으면 그 영역을 자동으로 스크롤한다.
func _auto_scroll(delta: float) -> void:
	var scroll: ScrollContainer = _scroll_at(_pointer)
	if scroll == null:
		return
	var rect: Rect2 = scroll.get_global_rect()
	var direction: float = 0.0
	if _pointer.y < rect.position.y + EDGE_SCROLL_ZONE:
		direction = -1.0
	elif _pointer.y > rect.end.y - EDGE_SCROLL_ZONE:
		direction = 1.0
	if direction != 0.0:
		var step: int = maxi(1, roundi(EDGE_SCROLL_SPEED * delta))
		scroll.scroll_vertical += int(direction) * step
		_update_drag()


# --- 알림 ---

func _show_toast(text: String) -> void:
	_toast.text = text
	if _toast_tween != null:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
