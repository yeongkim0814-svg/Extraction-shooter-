class_name TargetDummy
extends StaticBody3D
## 사격 연습용 표적. 코어 Health(방탄 등급 설정 가능)를 HitTarget 컴포넌트로 노출하고,
## 머리 위에 HP를 표시한다. 죽으면 RESPAWN_TIME초 뒤 되살아난다.

signal killed(dummy: TargetDummy)

const RESPAWN_TIME: float = 3.0
const FONT: Font = preload("res://assets/fonts/NotoSansKR.ttf")

@export var target_name: String = "dummy"
@export var max_hp: float = 100.0
@export_range(0, 6) var armor_class: int = 0
@export var armor_durability: float = 100.0
@export var body_color: Color = Color(0.9, 0.55, 0.2)

var hit_target: HitTarget
var _mesh: MeshInstance3D
var _label: Label3D
var _material: StandardMaterial3D
var _flash_left: float = 0.0


func _ready() -> void:
	collision_layer = 3   # 월드 + 사격 대상
	collision_mask = 0
	var shape_node := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	shape_node.shape = capsule
	shape_node.position.y = 0.9
	add_child(shape_node)

	_mesh = MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.3
	mesh.height = 1.8
	_mesh.mesh = mesh
	_mesh.position.y = 0.9
	_material = StandardMaterial3D.new()
	_material.albedo_color = body_color
	_mesh.material_override = _material
	add_child(_mesh)

	_label = Label3D.new()
	_label.font = FONT
	_label.font_size = 40
	_label.pixel_size = 0.008
	_label.outline_size = 10
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position.y = 2.25
	add_child(_label)

	hit_target = HitTarget.new()
	hit_target.display_name = target_name
	add_child(hit_target)
	hit_target.damaged.connect(_on_damaged)
	hit_target.died.connect(_on_died)
	reset()


func reset() -> void:
	var health := Health.new(max_hp)
	if armor_class > 0:
		health.set_armor(armor_class, armor_durability)
	hit_target.health = health
	hit_target.display_name = target_name
	_mesh.visible = true
	collision_layer = 3
	_material.albedo_color = body_color
	_update_label()


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_material.albedo_color = body_color


func _on_damaged(_result: DamageModel.HitResult) -> void:
	_material.albedo_color = Color(1.0, 1.0, 1.0)
	_flash_left = 0.06
	_update_label()


func _on_died() -> void:
	_mesh.visible = false
	collision_layer = 0
	_label.text = "%s\n처치 (%d초 뒤 부활)" % [target_name, int(RESPAWN_TIME)]
	killed.emit(self)
	get_tree().create_timer(RESPAWN_TIME).timeout.connect(reset)


func _update_label() -> void:
	var health: Health = hit_target.health
	var armor_text: String = ""
	if armor_class > 0:
		armor_text = "  방탄 %d급 %d%%" % [armor_class, roundi(health.armor_ratio() * 100.0)]
	_label.text = "%s\nHP %d/%d%s" % [target_name, ceili(health.hp), int(health.max_hp), armor_text]
