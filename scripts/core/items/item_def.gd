class_name ItemDef
extends Resource
## 아이템 종류의 정적 정의. 데이터(.tres)로 작성하고, 인스턴스(ItemInstance)가 참조한다.

@export var id: StringName = &""
@export var display_name: String = ""
## 회전하지 않은 상태의 그리드 크기 (칸).
@export_range(1, 20) var width: int = 1
@export_range(1, 20) var height: int = 1
## 1이면 쌓이지 않는다.
@export_range(1, 9999) var max_stack: int = 1
@export var can_rotate: bool = true


static func create(p_id: StringName, p_width: int, p_height: int,
		p_max_stack: int = 1, p_can_rotate: bool = true) -> ItemDef:
	var def := ItemDef.new()
	def.id = p_id
	def.display_name = String(p_id)
	def.width = p_width
	def.height = p_height
	def.max_stack = p_max_stack
	def.can_rotate = p_can_rotate
	return def
