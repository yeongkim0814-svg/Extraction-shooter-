class_name WeaponPartDef
extends Resource
## 무기 부품 정의 (리시버·총열·핸드가드·개머리판·탄창·조준경·소음기·손잡이 …).
## 무기 = 리시버를 뿌리로 한 부품 트리. 부품은 다시 소켓을 가질 수 있다.

@export var id: StringName = &""
@export var part_type: StringName = &""
@export var sockets: Array[WeaponSocket] = []
@export var modifiers: StatModifiers = StatModifiers.new()
## 리시버만 사용: 무기의 기본 스탯.
@export var base_stats: Dictionary[StringName, float] = {}
## 장착 시 인벤토리 크기 변화 (긴 총열 +1 가로 등).
@export var size_delta: Vector2i = Vector2i.ZERO
## 함께 장착할 수 없는 부품 id (양방향으로 검사한다).
@export var conflicts: Array[StringName] = []


static func create(p_id: StringName, p_part_type: StringName) -> WeaponPartDef:
	var def := WeaponPartDef.new()
	def.id = p_id
	def.part_type = p_part_type
	return def


func find_socket(socket_name: StringName) -> WeaponSocket:
	for socket: WeaponSocket in sockets:
		if socket.name == socket_name:
			return socket
	return null
