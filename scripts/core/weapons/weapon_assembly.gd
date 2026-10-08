class_name WeaponAssembly
extends RefCounted
## 리시버를 뿌리로 한 무기 부품 트리. 호환성 검사·스탯 합산·인벤토리 크기 계산을 담당한다.
## 노드는 뿌리부터의 소켓 이름 경로(Array[StringName])로 가리킨다 → 명령·저장에 그대로 쓸 수 있다.

const OK := &""
const UNKNOWN_PATH := &"unknown_path"
const UNKNOWN_SOCKET := &"unknown_socket"
const SOCKET_OCCUPIED := &"socket_occupied"
const WRONG_PART_TYPE := &"wrong_part_type"
const PART_NOT_ALLOWED := &"part_not_allowed"
const CONFLICT := &"conflict"

var root: WeaponPartNode


func _init(receiver: WeaponPartDef) -> void:
	root = WeaponPartNode.new(receiver)


func find_node(path: Array[StringName]) -> WeaponPartNode:
	var node: WeaponPartNode = root
	for socket_name: StringName in path:
		node = node.children.get(socket_name)
		if node == null:
			return null
	return node


func get_parts() -> Array[WeaponPartNode]:
	var result: Array[WeaponPartNode] = []
	root.collect(result)
	return result


## 부품 하나를 parent_path 노드의 소켓에 장착. 성공하면 OK(&""), 아니면 이유 코드.
func attach(parent_path: Array[StringName], socket_name: StringName, part: WeaponPartDef) -> StringName:
	return attach_node(parent_path, socket_name, WeaponPartNode.new(part))


## 이미 조립된 하위 트리(예: 손잡이가 달린 핸드가드)를 통째로 장착.
func attach_node(parent_path: Array[StringName], socket_name: StringName,
		node: WeaponPartNode) -> StringName:
	var error: StringName = can_attach_node(parent_path, socket_name, node)
	if error == OK:
		find_node(parent_path).children[socket_name] = node
	return error


func can_attach(parent_path: Array[StringName], socket_name: StringName, part: WeaponPartDef) -> StringName:
	return can_attach_node(parent_path, socket_name, WeaponPartNode.new(part))


func can_attach_node(parent_path: Array[StringName], socket_name: StringName,
		node: WeaponPartNode) -> StringName:
	var parent: WeaponPartNode = find_node(parent_path)
	if parent == null:
		return UNKNOWN_PATH
	var socket: WeaponSocket = parent.def.find_socket(socket_name)
	if socket == null:
		return UNKNOWN_SOCKET
	if parent.children.has(socket_name):
		return SOCKET_OCCUPIED
	if node.def.part_type != socket.part_type:
		return WRONG_PART_TYPE
	if not socket.allowed_parts.is_empty() and not socket.allowed_parts.has(node.def.id):
		return PART_NOT_ALLOWED
	var incoming: Array[WeaponPartNode] = []
	node.collect(incoming)
	for existing: WeaponPartNode in get_parts():
		for added: WeaponPartNode in incoming:
			if existing.def.conflicts.has(added.def.id) or added.def.conflicts.has(existing.def.id):
				return CONFLICT
	return OK


## 소켓의 부품(과 그 아래 하위 트리)을 떼어 돌려준다. 비어 있거나 경로가 틀리면 null.
func detach(parent_path: Array[StringName], socket_name: StringName) -> WeaponPartNode:
	var parent: WeaponPartNode = find_node(parent_path)
	if parent == null or not parent.children.has(socket_name):
		return null
	var node: WeaponPartNode = parent.children[socket_name]
	parent.children.erase(socket_name)
	return node


## 비어 있는 필수 소켓의 경로 ("handguard/grip" 형식). 비어 있지 않으면 사격 불가.
func missing_required() -> Array[String]:
	var missing: Array[String] = []
	_collect_missing(root, "", missing)
	return missing


func is_operational() -> bool:
	return missing_required().is_empty()


## 최종 스탯 = (리시버 기본 + 모든 부품 가산 합) × 모든 부품 배율 곱, 스탯별 하한 적용.
func compute_stats() -> Dictionary[StringName, float]:
	var stats: Dictionary[StringName, float] = {}
	for key: StringName in root.def.base_stats:
		stats[key] = root.def.base_stats[key]
	var multipliers: Dictionary[StringName, float] = {}
	for node: WeaponPartNode in get_parts():
		var mods: StatModifiers = node.def.modifiers
		if mods == null:
			continue
		for key: StringName in mods.additive:
			stats[key] = stats.get(key, 0.0) + mods.additive[key]
		for key: StringName in mods.multiplier:
			multipliers[key] = multipliers.get(key, 1.0) * mods.multiplier[key]
	for key: StringName in multipliers:
		stats[key] = stats.get(key, 0.0) * multipliers[key]
	for key: StringName in stats:
		if WeaponStats.MIN_VALUES.has(key):
			stats[key] = maxf(stats[key], WeaponStats.MIN_VALUES[key])
	return stats


## 부품 구성에 따른 인벤토리 크기: 기본 크기 + 모든 부품의 size_delta (각 축 최소 1).
func compute_size(base_size: Vector2i) -> Vector2i:
	var size: Vector2i = base_size
	for node: WeaponPartNode in get_parts():
		size += node.def.size_delta
	return Vector2i(maxi(size.x, 1), maxi(size.y, 1))


func _collect_missing(node: WeaponPartNode, prefix: String, out: Array[String]) -> void:
	for socket: WeaponSocket in node.def.sockets:
		var path: String = String(socket.name) if prefix.is_empty() else prefix + "/" + String(socket.name)
		var child: WeaponPartNode = node.children.get(socket.name)
		if child == null:
			if socket.required:
				out.append(path)
		else:
			_collect_missing(child, path, out)
