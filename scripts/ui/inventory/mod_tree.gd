class_name ModTree
extends RefCounted
## 모딩 화면 오른쪽 위의 소켓 트리 목록 (순수 로직): 부품 트리를 깊이 우선으로 펼쳐
## "총열: 롱 배럴" / "  └ 총구: (비어 있음)" 같은 줄 목록으로 만든다.

const SOCKET_KO: Dictionary[StringName, String] = {
	&"barrel": "총열",
	&"handguard": "핸드가드",
	&"stock": "개머리판",
	&"optic": "조준경",
	&"magazine": "탄창",
	&"muzzle": "총구",
	&"grip": "손잡이",
}
const EMPTY_TEXT := "(비어 있음)"


## 소켓 한 줄.
class Row:
	## 소켓이 달린 부품까지의 경로 (루트 부품이면 빈 배열).
	var parent_path: Array[StringName] = []
	var socket: StringName = &""
	var depth: int = 0
	var part_type: StringName = &""
	var required: bool = false
	## 이 소켓에 꽂힌 부품 노드. 비었으면 null.
	var node: WeaponPartNode = null
	var label: String = ""

	func path() -> Array[StringName]:
		var result: Array[StringName] = parent_path.duplicate()
		result.append(socket)
		return result

	func path_text() -> String:
		var parts: PackedStringArray = PackedStringArray()
		for part: StringName in path():
			parts.append(String(part))
		return "/".join(parts)

	func is_empty() -> bool:
		return node == null


static func socket_name_ko(socket_name: StringName) -> String:
	return SOCKET_KO.get(socket_name, String(socket_name))


## 부품 이름: 같은 id의 아이템 정의 표시 이름, 없으면 id.
static func part_name(def: WeaponPartDef, content: ContentDatabase) -> String:
	var item_def: ItemDef = content.get_item(def.id) if content != null else null
	return item_def.display_name if item_def != null and not item_def.display_name.is_empty() else String(def.id)


static func rows(assembly: WeaponAssembly, content: ContentDatabase) -> Array[Row]:
	var result: Array[Row] = []
	var path: Array[StringName] = []
	_walk(assembly.root, path, 0, content, result)
	return result


static func _walk(node: WeaponPartNode, path: Array[StringName], depth: int, content: ContentDatabase,
		out: Array[Row]) -> void:
	for socket: WeaponSocket in node.def.sockets:
		var row := Row.new()
		row.parent_path = path.duplicate()
		row.socket = socket.name
		row.depth = depth
		row.part_type = socket.part_type
		row.required = socket.required
		row.node = node.children.get(socket.name)
		row.label = _label(row, content)
		out.append(row)
		if row.node != null:
			var child_path: Array[StringName] = path.duplicate()
			child_path.append(socket.name)
			_walk(row.node, child_path, depth + 1, content, out)


static func _label(row: Row, content: ContentDatabase) -> String:
	var prefix: String = "  ".repeat(row.depth) + "└ " if row.depth > 0 else ""
	var value: String = part_name(row.node.def, content) if row.node != null else EMPTY_TEXT
	var text: String = "%s%s: %s" % [prefix, socket_name_ko(row.socket), value]
	if row.node == null and row.required:
		text += "  (필수)"
	return text


## 비어 있는 필수 소켓 이름 목록 글자 ("총열, 탄창"). 사격 가능하면 빈 문자열.
static func missing_required_text(assembly: WeaponAssembly) -> String:
	var names: PackedStringArray = PackedStringArray()
	for path_text: String in assembly.missing_required():
		names.append(socket_name_ko(StringName(path_text.get_slice("/", path_text.count("/")))))
	return ", ".join(names)
