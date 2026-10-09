class_name DomainEvent
extends RefCounted
## 상태 변경 결과 알림. UI·사운드·네트워크 동기화가 구독한다. data는 직렬화 가능한 값만 담는다.

const ITEM_ADDED := &"item_added"
const ITEM_MOVED := &"item_moved"
const ITEM_REMOVED := &"item_removed"
const STACK_CHANGED := &"stack_changed"
const MAGAZINE_CHANGED := &"magazine_changed"
const WEAPON_CHANGED := &"weapon_changed"

var type: StringName
var data: Dictionary


func _init(p_type: StringName, p_data: Dictionary = {}) -> void:
	type = p_type
	data = p_data
