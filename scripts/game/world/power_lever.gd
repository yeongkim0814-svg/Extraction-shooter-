class_name PowerLever
extends StaticBody3D
## 사무동에 있는 전원 레버. F(또는 HUD 버튼)로 켜면 화물 엘리베이터 탈출이 열린다. 도형은 임시 상자.

const FONT: Font = preload("res://assets/fonts/NotoSansKR.ttf")
const OFF_COLOR := Color(0.75, 0.2, 0.15)
const ON_COLOR := Color(0.25, 0.85, 0.35)

var activated: bool = false

var _lamp_mat: StandardMaterial3D
var _label: Label3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var panel_mesh := BoxMesh.new()
	panel_mesh.size = Vector3(0.7, 1.2, 0.25)
	var panel := MeshInstance3D.new()
	panel.mesh = panel_mesh
	panel.position.y = 0.6
	var panel_mat := StandardMaterial3D.new()
	panel_mat.albedo_color = Color(0.2, 0.22, 0.25)
	panel.material_override = panel_mat
	add_child(panel)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = panel_mesh.size
	shape.shape = box
	shape.position.y = 0.6
	add_child(shape)
	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = Vector3(0.2, 0.2, 0.08)
	var lamp := MeshInstance3D.new()
	lamp.mesh = lamp_mesh
	lamp.position = Vector3(0.0, 0.9, 0.15)
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_color = OFF_COLOR
	_lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp.material_override = _lamp_mat
	add_child(lamp)
	_label = Label3D.new()
	_label.text = "전원 레버"
	_label.font = FONT
	_label.font_size = 36
	_label.pixel_size = 0.006
	_label.outline_size = 10
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 1.6
	_label.visibility_range_end = LootContainer.LABEL_RANGE
	add_child(_label)


func interact_position() -> Vector3:
	return global_position + Vector3.UP * 0.6


## 전원을 켠다. 이미 켜져 있으면 false.
func activate() -> bool:
	if activated:
		return false
	activated = true
	_lamp_mat.albedo_color = ON_COLOR
	_label.text = "전원 ON"
	return true
