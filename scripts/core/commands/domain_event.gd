class_name DomainEvent
extends RefCounted
## 상태 변경 결과 알림. UI·사운드·네트워크 동기화가 구독한다. data는 직렬화 가능한 값만 담는다.

const ITEM_ADDED := &"item_added"
const ITEM_MOVED := &"item_moved"
const ITEM_REMOVED := &"item_removed"
const STACK_CHANGED := &"stack_changed"
const MAGAZINE_CHANGED := &"magazine_changed"
const WEAPON_CHANGED := &"weapon_changed"
## 외부 컨테이너(시체·상자)를 열었다/닫았다. data: container (+ 닫을 때 removed_ids = 등록이 풀린 아이템).
const CONTAINER_OPENED := &"container_opened"
const CONTAINER_CLOSED := &"container_closed"

var type: StringName
var data: Dictionary


func _init(p_type: StringName, p_data: Dictionary = {}) -> void:
	type = p_type
	data = p_data
