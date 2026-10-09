class_name WeaponAssembler
extends RefCounted
## WeaponAssembly(부품 트리)로 눈에 보이는 무기를 런타임에 조립한다.
## 부품마다 노드 하나(WeaponLook의 플레이스홀더 조각 또는 씬 오버라이드), 소켓마다 Marker3D "SOCKET_<소켓 이름>"을 만들고
## 자식 부품은 그 Marker3D의 자식으로 꽂는다 → 트리 구조가 노드 구조와 같다.

const SOCKET_PREFIX := "SOCKET_"

static var _materials: Dictionary[int, StandardMaterial3D] = {}


## 조립 결과와 부가 정보.
class Built:
	var root: Node3D
	## 가장 앞쪽 끝 (총구 화염 위치), 루트 기준.
	var muzzle: Vector3 = Vector3(0, 0.03, -0.3)
	## 조준선 높이 (루트 원점 기준). ADS에서 이 높이가 화면 중앙에 오게 무기를 내린다.
	var sight_y: float = 0.07
	var bounds: AABB = AABB()
	## 소켓 경로("barrel/muzzle") → Marker3D.
	var sockets: Dictionary[String, Marker3D] = {}
	## ADS 중 숨길 노드 (확대 조준경).
	var ads_hidden: Array[Node3D] = []
	var _has_bounds: bool = false

	func merge_bounds(box: AABB) -> void:
		bounds = bounds.merge(box) if _has_bounds else box
		_has_bounds = true


## 부품 구성이 같은지 비교할 키 (같으면 다시 조립할 필요 없음).
static func signature(assembly: WeaponAssembly) -> String:
	var parts: PackedStringArray = PackedStringArray()
	_signature_of(assembly.root, parts)
	return ",".join(parts)


static func _signature_of(node: WeaponPartNode, out: PackedStringArray) -> void:
	out.append(String(node.def.id))
	for socket: WeaponSocket in node.def.sockets:
		var child: WeaponPartNode = node.children.get(socket.name)
		out.append(String(socket.name) + (":" if child != null else ":-"))
		if child != null:
			_signature_of(child, out)


## 무기 한 자루를 조립한다. 반환된 root를 호출자가 트리에 넣는다.
static func build(assembly: WeaponAssembly) -> Built:
	var built := Built.new()
	built.root = Node3D.new()
	built.root.name = "Weapon"
	var look: WeaponLook.PartLook = WeaponLook.for_part(assembly.root.def)
	if look.sight_y != INF:
		built.sight_y = look.sight_y
	_add_part(assembly.root, built.root, Vector3.ZERO, "", built)
	return built


static func socket_node_name(socket_name: StringName) -> String:
	return SOCKET_PREFIX + String(socket_name)


static func _add_part(node: WeaponPartNode, parent: Node3D, origin: Vector3, path: String, built: Built) -> void:
	var look: WeaponLook.PartLook = WeaponLook.for_part(node.def)
	var part_root: Node3D = _instantiate_override(node.def)
	var overridden: bool = part_root != null
	if part_root == null:
		part_root = Node3D.new()
		part_root.name = String(node.def.id)
		for piece: WeaponLook.Piece in look.pieces:
			part_root.add_child(_piece_node(piece))
			var box: AABB = piece.local_bounds()
			box.position += origin
			built.merge_bounds(box)
	parent.add_child(part_root)
	if look.hide_in_ads:
		built.ads_hidden.append(part_root)
	if look.tip != Vector3.INF:
		var tip: Vector3 = origin + look.tip
		if tip.z < built.muzzle.z or path.is_empty():
			built.muzzle = tip
	if node.def.part_type == &"optic" and look.sight_y != INF:
		built.sight_y = origin.y + look.sight_y
	for socket: WeaponSocket in node.def.sockets:
		var marker: Node3D = _find_socket(part_root, socket.name) if overridden else null
		if marker == null:
			marker = Marker3D.new()
			marker.name = socket_node_name(socket.name)
			marker.position = look.sockets.get(socket.name, Vector3.ZERO)
			part_root.add_child(marker)
		var child_path: String = String(socket.name) if path.is_empty() else path + "/" + String(socket.name)
		if marker is Marker3D:
			built.sockets[child_path] = marker as Marker3D
		var child: WeaponPartNode = node.children.get(socket.name)
		if child != null:
			_add_part(child, marker, origin + marker.position, child_path, built)


static func _piece_node(piece: WeaponLook.Piece) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if piece.shape == WeaponLook.Shape.CYLINDER:
		var mesh := CylinderMesh.new()
		mesh.top_radius = piece.size.x
		mesh.bottom_radius = piece.size.x
		mesh.height = piece.size.z
		mesh.radial_segments = 12
		mesh.rings = 1
		mi.mesh = mesh
		mi.rotation_degrees.x = 90.0   # 원기둥 축(Y)을 총구 방향(Z)으로
	else:
		var mesh := BoxMesh.new()
		mesh.size = piece.size
		mi.mesh = mesh
		mi.rotation_degrees.x = piece.pitch_deg
	mi.material_override = material_for(piece.color, piece.glow)
	mi.position = piece.pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## 색마다 하나만 만들어 공유한다.
static func material_for(color: Color, glow: bool) -> StandardMaterial3D:
	var key: int = color.to_rgba32() * 2 + (1 if glow else 0)
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	if glow:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materials[key] = mat
	return mat


## 씬 오버라이드(.glb 임포트 씬 등)가 있으면 인스턴스. 없거나 없는 경로면 null.
static func _instantiate_override(def: WeaponPartDef) -> Node3D:
	var path: String = WeaponLook.scene_overrides.get(def.id, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path) as PackedScene
	return scene.instantiate() as Node3D if scene != null else null


static func _find_socket(part_root: Node, socket_name: StringName) -> Node3D:
	var exact: Node = part_root.find_child(socket_node_name(socket_name), true, false)
	if exact == null:
		exact = part_root.find_child(SOCKET_PREFIX + String(socket_name).capitalize(), true, false)
	return exact as Node3D
