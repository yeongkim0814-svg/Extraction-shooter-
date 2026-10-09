class_name ExtractionZone
extends Area3D
## 탈출 지점: 반투명 기둥 + 이름/상태 글자. 플레이어가 들어오면 player_entered, 나가면 player_exited.
## 대기 시간·조건(required_flag) 판정은 ExtractionPoint 데이터와 ExtractionTracker가 한다.

signal player_entered(zone: ExtractionZone)
signal player_exited(zone: ExtractionZone)

const FONT: Font = preload("res://assets/fonts/NotoSansKR.ttf")
const SIZE := Vector3(4.0, 3.0, 4.0)
const OPEN_COLOR := Color(0.2, 0.9, 0.4, 0.28)
const CLOSED_COLOR := Color(0.9, 0.25, 0.2, 0.28)

var point: ExtractionPoint
var display_name: String = ""
var player_inside: bool = false

var _column_mat: StandardMaterial3D
var _label: Label3D
var _open: bool = true


## 노드를 만든다. required_flag가 비어 있으면 항상 열린 지점.
static func create(p_id: StringName, p_name: String, wait_time: float, required_flag: StringName = &"") -> ExtractionZone:
	var zone := ExtractionZone.new()
	zone.name = "Extract_%s" % String(p_id)
	zone.display_name = p_name
	zone.point = ExtractionPoint.new()
	zone.point.id = p_id
	zone.point.wait_time = wait_time
	zone.point.required_flag = required_flag
	return zone


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4   # 플레이어 몸 (레이어 4)
	monitoring = true
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	shape_node.shape = box
	shape_node.position.y = SIZE.y * 0.5
	add_child(shape_node)
	var column := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.8
	mesh.bottom_radius = 1.8
	mesh.height = 4.0
	mesh.radial_segments = 16
	mesh.rings = 1
	column.mesh = mesh
	column.position.y = 2.0
	_column_mat = StandardMaterial3D.new()
	_column_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_column_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_column_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_column_mat.albedo_color = OPEN_COLOR
	column.material_override = _column_mat
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(column)
	_label = Label3D.new()
	_label.font = FONT
	_label.font_size = 48
	_label.pixel_size = 0.008
	_label.outline_size = 12
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position.y = 4.6
	add_child(_label)
	set_status("")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## 조건이 충족돼 열려 있는지에 따라 기둥 색을 바꾼다.
func set_open(open: bool) -> void:
	_open = open
	if _column_mat != null:
		_column_mat.albedo_color = OPEN_COLOR if open else CLOSED_COLOR
	set_status("")


## 이름 아래 한 줄 상태 (카운트다운 등). 비우면 열림/닫힘 기본 문구.
func set_status(status: String) -> void:
	if _label == null:
		return
	var extra: String = status
	if extra.is_empty():
		extra = "" if _open else "전원 필요"
	_label.text = display_name if extra.is_empty() else "%s\n%s" % [display_name, extra]


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		player_inside = true
		player_entered.emit(self)


func _on_body_exited(body: Node3D) -> void:
	if body is PlayerController:
		player_inside = false
		player_exited.emit(self)
