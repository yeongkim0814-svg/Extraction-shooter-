class_name WeaponSocket
extends Resource
## 부품이 가진 장착 구멍. 3D 모델의 Marker3D 이름(SOCKET_<name>)과 대응한다.

@export var name: StringName = &""
## 이 소켓에 꽂을 수 있는 부품 종류 (예: &"muzzle").
@export var part_type: StringName = &""
## 비어 있으면 같은 종류 아무 부품이나, 아니면 이 목록의 부품 id만 허용.
@export var allowed_parts: Array[StringName] = []
## true면 비어 있을 때 사격 불가 (예: 탄창, 총열).
@export var required: bool = false


static func create(p_name: StringName, p_part_type: StringName, p_required: bool = false) -> WeaponSocket:
	var socket := WeaponSocket.new()
	socket.name = p_name
	socket.part_type = p_part_type
	socket.required = p_required
	return socket
