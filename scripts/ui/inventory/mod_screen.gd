class_name ModScreen
extends Control
## 총기 모딩 화면 (가로 레이아웃). 인벤토리 액션 바의 "모딩"에서 열리고, 닫으면 인벤토리로 돌아간다.
##   왼쪽: 조립된 무기의 3D 미리보기(천천히 회전, 끌어서 돌리기) + 스탯 표 (부품을 고르면 변화량: 초록 좋아짐 / 빨강 나빠짐)
##   가운데: 소켓 트리 (들여쓰기) — 소켓을 누르면 오른쪽에 후보가 나온다
##   오른쪽: 그 소켓에 달 수 있는 부품 아이템(인벤토리에서 찾음). 안 되는 것은 이유와 함께 흐리게.
##          후보를 한 번 누르면 변화량 미리보기, 한 번 더 누르거나 [장착]을 누르면 AttachPartCommand.
##          부품이 달린 소켓은 [분리] → DetachPartCommand (아래에 부품이 있으면 먼저 떼라는 안내).
## 상태 변경은 전부 authority.execute로만 한다. 판정·목록·글자는 ModTree/ModCandidates/ModStats (순수 로직).
## 스모크 테스트가 읽는 로그:
##   "MOD_SCREEN: open <weapon_id>"
##   "MOD_SCREEN: attach <part_id> -> <socket 경로> ok|<오류>"   "MOD_SCREEN: detach <socket 경로> ok|<오류>"
##   "MOD_SCREEN: stats recoil=<v> ergo=<v>"   "MOD_SCREEN: close"
##   "MOD_SCREEN: socket|part|button ... at x,y size WxH"   (창 픽셀 좌표, 화면이 바뀔 때마다)

signal closed

const PREFIX: String = "MOD_SCREEN: "
const BG := Color(0.055, 0.063, 0.078, 1.0)
const ACCENT := Color(0.45, 0.62, 0.95)
const SELECT_ACCENT := Color(1.0, 0.86, 0.15)
const WARN_COLOR := Color(1.0, 0.62, 0.3)
const LEFT_WIDTH: float = 440.0
const TREE_WIDTH: float = 318.0
const PREVIEW_HEIGHT: float = 290.0
const ROW_HEIGHT: float = 42.0
const CANDIDATE_HEIGHT: float = 56.0
const SPIN_SPEED: float = 0.5
const DRAG_SENS: float = 0.012
const DRAG_PAUSE: float = 1.6
const TOAST_SEC: float = 1.9

var _authority: GameAuthority
var _inventory: Inventory
var _content: ContentDatabase
var _weapon: ItemInstance = null
var _weapon_id: int = 0
var _selected_path: String = ""
var _highlight: ModCandidates.Candidate = null
var _rows: Array[ModTree.Row] = []
var _candidates: Array[ModCandidates.Candidate] = []
var _executing: bool = false
var _layout_serial: int = 0

# 3D 미리보기
var _viewport: SubViewport
var _camera: Camera3D
var _pivot: Node3D
var _model_holder: Node3D
var _marker_dot: MeshInstance3D
var _yaw: float = -1.2
var _spin_pause: float = 0.0
var _dragging: bool = false
var _view_extent: Vector2 = Vector2(0.9, 0.3)

# UI
var _title: Label
var _size_label: Label
var _warn_label: Label
var _close_button: Button
var _stat_title: Label
var _stat_rows: Array[ModStats.Row] = []
var _stat_values: Array[Label] = []
var _stat_changes: Array[Label] = []
var _tree_box: VBoxContainer
var _cand_title: Label
var _cand_note: Label
var _cand_box: VBoxContainer
var _attach_button: Button
var _detach_button: Button
var _toast: Label
var _toast_tween: Tween = null
var _tree_buttons: Dictionary[String, Button] = {}
var _cand_buttons: Array[Button] = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


## 무기 아이템의 모딩 화면을 연다.
func open(authority: GameAuthority, weapon_item_id: int) -> void:
	if _authority != null and _authority != authority:
		_authority.events_emitted.disconnect(_on_events)
		_authority = null
	if _authority == null:
		_authority = authority
		_authority.events_emitted.connect(_on_events)
	_inventory = authority.inventory
	_content = authority.content
	_weapon_id = weapon_item_id
	_weapon = _inventory.get_item(weapon_item_id)
	if _weapon == null or _weapon.weapon == null:
		return
	_selected_path = ""
	_highlight = null
	visible = true
	print(PREFIX + "open " + String(_weapon.def.id))
	_pick_default_socket()
	_refresh()
	_print_stats()


func is_open() -> bool:
	return visible


func close() -> void:
	if not visible:
		return
	visible = false
	_highlight = null
	print(PREFIX + "close")
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible or _pivot == null:
		return
	if _dragging:
		_spin_pause = DRAG_PAUSE
	elif _spin_pause > 0.0:
		_spin_pause -= delta
	else:
		_yaw -= SPIN_SPEED * delta
	_pivot.rotation = Vector3(0.0, _yaw, 0.0)


# --- 화면 구성 ---

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	column.add_child(header)
	_title = _label("", 24, InventoryStyle.TEXT)
	header.add_child(_title)
	_size_label = _label("", 16, InventoryStyle.TEXT_DIM)
	header.add_child(_size_label)
	_warn_label = _label("", 16, WARN_COLOR)
	_warn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_warn_label.clip_text = true
	header.add_child(_warn_label)
	_close_button = _button("닫기", ACCENT)
	_close_button.custom_minimum_size.x = 104
	_close_button.pressed.connect(close)
	header.add_child(_close_button)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	# 왼쪽: 미리보기 + 스탯
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = LEFT_WIDTH
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	left.add_child(_build_preview())
	left.add_child(_build_stats())

	# 가운데: 소켓 트리
	var tree_panel := _panel()
	tree_panel.custom_minimum_size.x = TREE_WIDTH
	body.add_child(tree_panel)
	var tree_col := VBoxContainer.new()
	tree_col.add_theme_constant_override("separation", 6)
	tree_panel.add_child(tree_col)
	tree_col.add_child(_label("소켓", 15, InventoryStyle.TEXT_DIM))
	_tree_box = _scroll_list(tree_col, 4)

	# 오른쪽: 후보
	var cand_panel := _panel()
	cand_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(cand_panel)
	var cand_col := VBoxContainer.new()
	cand_col.add_theme_constant_override("separation", 6)
	cand_panel.add_child(cand_col)
	var cand_header := HBoxContainer.new()
	cand_header.add_theme_constant_override("separation", 8)
	cand_col.add_child(cand_header)
	_cand_title = _label("", 18, InventoryStyle.TEXT)
	_cand_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cand_title.clip_text = true
	cand_header.add_child(_cand_title)
	_attach_button = _button("장착", Color(0.4, 0.8, 0.5))
	_attach_button.custom_minimum_size = Vector2(92, 44)
	_attach_button.pressed.connect(_on_attach_pressed)
	cand_header.add_child(_attach_button)
	_detach_button = _button("분리", Color(0.9, 0.4, 0.4))
	_detach_button.custom_minimum_size = Vector2(92, 44)
	_detach_button.pressed.connect(_on_detach_pressed)
	cand_header.add_child(_detach_button)
	_cand_note = _label("", 15, InventoryStyle.TEXT_DIM)
	_cand_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cand_col.add_child(_cand_note)
	_cand_box = _scroll_list(cand_col, 6)

	_toast = _label("", 20, Color(1.0, 0.85, 0.6))
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	add_child(_toast)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.offset_left = -300.0
	_toast.offset_right = 300.0
	_toast.offset_top = -80.0
	_toast.offset_bottom = -34.0


func _build_preview() -> Control:
	var panel := _panel()
	panel.custom_minimum_size.y = PREVIEW_HEIGHT
	panel.add_theme_stylebox_override("panel", _panel_style(3))
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.gui_input.connect(_on_preview_input)
	container.resized.connect(_fit_camera)
	panel.add_child(container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(_viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.075, 0.085, 0.105)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.85, 0.92)
	env.ambient_light_energy = 0.85
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.7, 0.5, 0.0)
	light.light_energy = 0.9
	_viewport.add_child(light)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 0.7
	_viewport.add_child(_camera)
	_camera.look_at_from_position(Vector3(0.0, 0.3, 3.0), Vector3.ZERO)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	_model_holder = Node3D.new()
	_pivot.add_child(_model_holder)
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.014
	dot_mesh.height = 0.028
	dot_mesh.radial_segments = 10
	dot_mesh.rings = 5
	var dot_mat := StandardMaterial3D.new()
	dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_mat.albedo_color = SELECT_ACCENT
	dot_mat.no_depth_test = true
	dot_mat.render_priority = 5
	dot_mesh.material = dot_mat
	_marker_dot = MeshInstance3D.new()
	_marker_dot.mesh = dot_mesh
	_marker_dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker_dot.visible = false
	_pivot.add_child(_marker_dot)
	return panel


func _build_stats() -> Control:
	var panel := _panel()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	_stat_title = _label("스탯", 15, InventoryStyle.TEXT_DIM)
	box.add_child(_stat_title)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 3)
	box.add_child(grid)
	_stat_rows = ModStats.rows()
	for row: ModStats.Row in _stat_rows:
		var name_label: Label = _label(row.label, 18, InventoryStyle.TEXT_DIM)
		name_label.custom_minimum_size.x = 76
		grid.add_child(name_label)
		var value_label: Label = _label("", 18, InventoryStyle.TEXT)
		value_label.custom_minimum_size.x = 96
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(value_label)
		_stat_values.append(value_label)
		var change_label: Label = _label("", 18, InventoryStyle.TEXT)
		change_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(change_label)
		_stat_changes.append(change_label)
	return panel


func _scroll_list(parent: Control, separation: int) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", separation)
	scroll.add_child(list)
	return list


static func _panel_style(margin: int = 10) -> StyleBoxFlat:
	var style: StyleBoxFlat = InventoryStyle.panel_style()
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin if margin < 10 else 8
	style.content_margin_bottom = margin if margin < 10 else 8
	return style


static func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	return panel


static func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func _button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	InventoryStyle.style_button(button, accent)
	return button


static func _row_box(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(6)
	box.content_margin_left = 12
	box.content_margin_right = 10
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box


## 목록 줄 버튼의 모양. selected면 노란 테두리, 비활성이면 어둡게.
static func _style_row(button: Button, selected: bool, accent: Color) -> void:
	var border: Color = SELECT_ACCENT if selected else Color(0.3, 0.33, 0.41)
	var fill: Color = Color(0.2, 0.25, 0.36) if selected else Color(0.14, 0.155, 0.2)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _row_box(fill, border, 3 if selected else 1))
	button.add_theme_stylebox_override("hover", _row_box(fill.lightened(0.08), border.lightened(0.15), 2 if not selected else 3))
	button.add_theme_stylebox_override("pressed", _row_box(accent.darkened(0.5), accent, 2))
	button.add_theme_stylebox_override("disabled", _row_box(Color(0.1, 0.11, 0.14), Color(0.2, 0.22, 0.27), 1))


# --- 갱신 ---

func _pick_default_socket() -> void:
	var rows: Array[ModTree.Row] = ModTree.rows(_weapon.weapon, _content)
	for row: ModTree.Row in rows:
		if row.is_empty() and row.required:
			_selected_path = row.path_text()
			return
	for row: ModTree.Row in rows:
		if row.is_empty():
			_selected_path = row.path_text()
			return
	if not rows.is_empty():
		_selected_path = rows[0].path_text()


func _on_events(_events: Array[DomainEvent]) -> void:
	if not visible or _executing:
		return
	_weapon = _inventory.get_item(_weapon_id)
	if _weapon == null or _weapon.weapon == null:
		close()
		return
	_refresh()


## 무기 상태가 바뀌었거나 소켓을 고른 뒤 화면 전체를 다시 채운다.
func _refresh() -> void:
	_weapon = _inventory.get_item(_weapon_id)
	if _weapon == null or _weapon.weapon == null:
		close()
		return
	_title.text = "모딩  ·  " + _weapon.def.display_name
	var size: Vector2i = _weapon.size_for(false)
	_size_label.text = "인벤토리 크기 %d×%d" % [size.x, size.y]
	var missing: String = ModTree.missing_required_text(_weapon.weapon)
	_warn_label.text = "" if missing.is_empty() else "필수 부품 없음 (%s) · 사격 불가" % missing
	_rows = ModTree.rows(_weapon.weapon, _content)
	if _find_row(_selected_path) == null:
		_selected_path = ""
		_highlight = null
	_rebuild_tree()
	_rebuild_model()
	_rebuild_candidates()
	_update_stats()
	_schedule_layout_log()


func _find_row(path_text: String) -> ModTree.Row:
	for row: ModTree.Row in _rows:
		if row.path_text() == path_text:
			return row
	return null


func _rebuild_tree() -> void:
	for child: Node in _tree_box.get_children():
		_tree_box.remove_child(child)
		child.queue_free()
	_tree_buttons.clear()
	for row: ModTree.Row in _rows:
		var button := Button.new()
		button.text = row.label
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.custom_minimum_size.y = ROW_HEIGHT
		button.add_theme_font_size_override("font_size", 18)
		var color: Color = InventoryStyle.TEXT
		if row.is_empty():
			color = WARN_COLOR if row.required else InventoryStyle.TEXT_DIM
		for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(color_name, color)
		_style_row(button, row.path_text() == _selected_path, ACCENT)
		button.pressed.connect(_on_row_pressed.bind(row.path_text()))
		_tree_box.add_child(button)
		_tree_buttons[row.path_text()] = button


func _rebuild_model() -> void:
	if _marker_dot.get_parent() != null:
		_marker_dot.get_parent().remove_child(_marker_dot)
	for child: Node in _model_holder.get_children():
		_model_holder.remove_child(child)
		child.queue_free()
	var built: WeaponAssembler.Built = WeaponAssembler.build(_weapon.weapon)
	var center: Vector3 = built.bounds.get_center()
	_model_holder.add_child(built.root)
	built.root.position = -center
	_view_extent = Vector2(built.bounds.size.z, built.bounds.size.y)
	var marker: Marker3D = built.sockets.get(_selected_path)
	_marker_dot.visible = marker != null
	(marker if marker != null else _pivot).add_child(_marker_dot)
	_fit_camera()


## 무기가 어느 각도에서도 들어오도록 직교 카메라 크기를 맞춘다.
func _fit_camera() -> void:
	if _camera == null or _viewport == null:
		return
	var view: Vector2 = Vector2(_viewport.size)
	if view.y < 1.0:
		return
	var aspect: float = view.x / view.y
	var need_h: float = maxf(_view_extent.x / aspect, _view_extent.y + 0.1) * 1.08
	_camera.size = maxf(need_h, 0.35)


func _rebuild_candidates() -> void:
	for child: Node in _cand_box.get_children():
		_cand_box.remove_child(child)
		child.queue_free()
	_cand_buttons.clear()
	_candidates.clear()
	_attach_button.visible = false
	_detach_button.visible = false
	_cand_note.text = ""
	var row: ModTree.Row = _find_row(_selected_path)
	if row == null:
		_cand_title.text = "소켓을 선택하세요"
		_cand_note.text = "가운데 목록에서 소켓을 누르면 달 수 있는 부품이 나옵니다."
		return
	var socket_ko: String = ModTree.socket_name_ko(row.socket)
	if not row.is_empty():
		_cand_title.text = "%s: %s" % [socket_ko, ModTree.part_name(row.node.def, _content)]
		_detach_button.visible = true
		var blocked: bool = not row.node.children.is_empty()
		_detach_button.disabled = blocked
		_cand_note.text = "하위 부품을 먼저 분리하세요" if blocked else \
				"효과: " + ModStats.part_summary(row.node.def)
		return
	_cand_title.text = "%s에 장착" % socket_ko
	_attach_button.visible = true
	_candidates = ModCandidates.collect(_inventory, _content, _weapon, row.parent_path, row.socket)
	if _candidates.is_empty():
		_cand_note.text = "인벤토리에 달 수 있는 부품이 없습니다."
	elif _highlight == null:
		_cand_note.text = "부품을 누르면 변화를 미리 보고, 한 번 더 누르면 장착합니다."
	for candidate: ModCandidates.Candidate in _candidates:
		_cand_box.add_child(_candidate_button(candidate))
	_attach_button.disabled = _highlight == null or not _highlight.enabled()


func _candidate_button(candidate: ModCandidates.Candidate) -> Button:
	var button := Button.new()
	button.custom_minimum_size.y = CANDIDATE_HEIGHT
	button.disabled = not candidate.enabled()
	button.clip_contents = true
	var selected: bool = _highlight != null and _highlight.item == candidate.item
	_style_row(button, selected, Color(0.4, 0.8, 0.5))
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.offset_left = 12.0
	text.offset_right = -10.0
	button.add_child(text)
	var name_color: Color = InventoryStyle.TEXT if candidate.enabled() else Color(0.5, 0.53, 0.6)
	var title: String = "%s   %d×%d · %s" % [ModTree.part_name(candidate.part, _content),
			candidate.item.def.width, candidate.item.def.height, candidate.source]
	text.add_child(_label(title, 18, name_color))
	var detail: String = ModStats.part_summary(candidate.part) if candidate.enabled() else candidate.reason
	var detail_color: Color = InventoryStyle.TEXT_DIM if candidate.enabled() else WARN_COLOR.darkened(0.15)
	var detail_label: Label = _label(detail, 14, detail_color)
	detail_label.clip_text = true
	text.add_child(detail_label)
	button.pressed.connect(_on_candidate_pressed.bind(candidate))
	_cand_buttons.append(button)
	return button


## 스탯 표: 현재 값, 그리고 고른 후보(장착 시)나 선택한 소켓의 부품(분리 시)의 변화.
func _update_stats() -> void:
	var current: Dictionary[StringName, float] = ModStats.current(_weapon.weapon)
	var preview: ModStats.Preview = null
	var title: String = "스탯"
	var row: ModTree.Row = _find_row(_selected_path)
	if _highlight != null and row != null and row.is_empty():
		preview = ModStats.preview_attach(_weapon, row.parent_path, row.socket, _highlight.part)
		title = "스탯  ·  장착하면"
	elif row != null and not row.is_empty() and row.node.children.is_empty():
		preview = ModStats.preview_detach(_weapon, row.parent_path, row.socket)
		title = "스탯  ·  분리하면"
	if preview != null and preview.error != &"":
		preview = null
		title = "스탯"
	_stat_title.text = title
	for i: int in range(_stat_rows.size()):
		var stat: ModStats.Row = _stat_rows[i]
		var old_value: float = current[stat.key]
		_stat_values[i].text = ModStats.format_value(stat, old_value)
		var change: Label = _stat_changes[i]
		change.text = ""
		if preview == null:
			continue
		var new_value: float = preview.stats.get(stat.key, old_value)
		var verdict: ModStats.Verdict = ModStats.verdict(stat, old_value, new_value)
		if verdict == ModStats.Verdict.SAME:
			continue
		change.text = "→ %s   (%s)" % [ModStats.format_value(stat, new_value), ModStats.format_delta(stat, old_value, new_value)]
		change.add_theme_color_override("font_color", ModStats.verdict_color(verdict))
	if preview != null:
		var now: Vector2i = _weapon.size_for(false)
		var after: Vector2i = preview.size if not _weapon.rotated else Vector2i(preview.size.y, preview.size.x)
		if after != now:
			_stat_title.text += "   (크기 %d×%d → %d×%d)" % [now.x, now.y, after.x, after.y]


# --- 입력 ---

func _on_row_pressed(path_text: String) -> void:
	if _selected_path == path_text:
		return
	_selected_path = path_text
	_highlight = null
	print(PREFIX + "select " + path_text)
	_refresh()


func _on_candidate_pressed(candidate: ModCandidates.Candidate) -> void:
	if not candidate.enabled():
		return
	if _highlight != null and _highlight.item == candidate.item:
		_attach(candidate)
		return
	_highlight = candidate
	_rebuild_candidates()
	_update_stats()
	_schedule_layout_log()


func _on_attach_pressed() -> void:
	if _highlight != null and _highlight.enabled():
		_attach(_highlight)


func _attach(candidate: ModCandidates.Candidate) -> void:
	var row: ModTree.Row = _find_row(_selected_path)
	if row == null or not row.is_empty():
		return
	var command := AttachPartCommand.new(_weapon.id, row.parent_path, row.socket, candidate.item.id)
	_executing = true
	var result: CommandResult = _authority.execute(command)
	_executing = false
	print(PREFIX + "attach %s -> %s %s" % [candidate.part.id, row.path_text(), "ok" if result.ok else String(result.error)])
	if not result.ok:
		_show_toast(ModCandidates.reason_text(result.error))
		_highlight = null
		_refresh()
		return
	_highlight = null
	_print_stats()
	_refresh()
	# 부품에 자식 소켓이 있으면 다음 작업을 위해 그 자리를 고른다 (예: 총열 → 총구)
	var after: ModTree.Row = _find_row(row.path_text() + "/" + _first_child_socket(row.path_text()))
	if after != null and after.is_empty():
		_on_row_pressed(after.path_text())


func _first_child_socket(path_text: String) -> String:
	var row: ModTree.Row = _find_row(path_text)
	if row == null or row.node == null or row.node.def.sockets.is_empty():
		return "_"
	return String(row.node.def.sockets[0].name)


func _on_detach_pressed() -> void:
	var row: ModTree.Row = _find_row(_selected_path)
	if row == null or row.is_empty():
		return
	var command := DetachPartCommand.new(_weapon.id, row.parent_path, row.socket)
	_executing = true
	var result: CommandResult = _authority.execute(command)
	_executing = false
	print(PREFIX + "detach %s %s" % [row.path_text(), "ok" if result.ok else String(result.error)])
	if not result.ok:
		_show_toast(_detach_error_text(result.error))
	else:
		_print_stats()
	_highlight = null
	_refresh()


static func _detach_error_text(error: StringName) -> String:
	if error == CommandResult.HAS_ATTACHMENTS:
		return "하위 부품을 먼저 분리하세요"
	return ModCandidates.reason_text(error)


func _on_preview_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		_dragging = button.pressed
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		_yaw += motion.relative.x * DRAG_SENS


# --- 알림·로그 ---

func _show_toast(text: String) -> void:
	_toast.text = text
	if _toast_tween != null:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_SEC)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


func toast_text() -> String:
	return _toast.text if _toast.modulate.a > 0.0 else ""


func _print_stats() -> void:
	var stats: Dictionary[StringName, float] = ModStats.current(_weapon.weapon)
	print(PREFIX + "stats recoil=%.1f ergo=%.1f" % [stats[WeaponStats.RECOIL], stats[WeaponStats.ERGONOMICS]])


## 스모크 테스트용: 레이아웃이 확정된 뒤 소켓 줄·후보·버튼의 창 픽셀 좌표를 출력한다.
func _schedule_layout_log() -> void:
	_layout_serial += 1
	var serial: int = _layout_serial
	await get_tree().process_frame
	await get_tree().process_frame
	if serial != _layout_serial or not visible:
		return
	for path_text: String in _tree_buttons:
		print(PREFIX + "socket %s at %s" % [path_text, _window_rect(_tree_buttons[path_text])])
	for i: int in range(_cand_buttons.size()):
		var candidate: ModCandidates.Candidate = _candidates[i]
		print(PREFIX + "part %s at %s enabled=%d" % [candidate.part.id, _window_rect(_cand_buttons[i]),
				1 if candidate.enabled() else 0])
	for entry: Array in [["attach", _attach_button], ["detach", _detach_button], ["close", _close_button]]:
		var button: Button = entry[1]
		if button.is_visible_in_tree():
			print(PREFIX + "button %s at %s enabled=%d" % [entry[0], _window_rect(button), 0 if button.disabled else 1])


func _window_rect(control: Control) -> String:
	var rect: Rect2 = control.get_global_rect()
	var to_window: Transform2D = get_viewport().get_screen_transform()
	var top_left: Vector2 = to_window * rect.position
	var win_size: Vector2 = rect.size * to_window.get_scale()
	return "%d,%d size %dx%d" % [top_left.x, top_left.y, win_size.x, win_size.y]
