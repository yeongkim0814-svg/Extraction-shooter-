class_name WeaponPartNode
extends RefCounted
## 조립된 무기 트리의 노드: 부품 하나와 소켓별 자식 노드.

var def: WeaponPartDef
var children: Dictionary[StringName, WeaponPartNode] = {}


func _init(p_def: WeaponPartDef) -> void:
	def = p_def


## 이 노드와 모든 자손 (깊이 우선, 소켓 정의 순서).
func collect(out: Array[WeaponPartNode]) -> void:
	out.append(self)
	for socket: WeaponSocket in def.sockets:
		var child: WeaponPartNode = children.get(socket.name)
		if child != null:
			child.collect(out)
