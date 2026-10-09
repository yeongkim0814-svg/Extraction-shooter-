class_name StyleBake
extends RefCounted
## 스타일 D의 베이크 대용: 정점마다 반구 레이를 쏴 AO·하늘 가시성·램프 따뜻함을 구워 정점 색 COLOR에 넣는다 (한 번, 빌드 시점).
## LightmapGI를 못 굽는 환경(Vulkan 없음, 웹, 헤드리스)에서 라이트맵 대신 쓰는 값이다. 순수 계산은 VertexAo가 맡고, 여기는 물리 질의만 한다.
## 방법: 빌더가 모은 삼각형으로 ConcavePolygonShape3D 충돌체를 임시로 만들고(물리 프레임 두 번 기다림),
## PhysicsDirectSpaceState3D.intersect_ray로 쏜 뒤 충돌체를 지운다. 같은 자리·법선의 정점은 값 하나를 공유한다.
## 로그 접두사 "STYLE: " (vertex_ao).

const PREFIX: String = "STYLE: "
## 임시 충돌체를 만들지 않는 그룹 (먼 배경·빛줄기·식물·웅덩이).
const SKIP_GROUPS: Array[StringName] = [&"skyline", &"shaft", &"glow", &"far_ground", &"weeds", &"puddle", &"ivy"]
const AO_RAYS: int = 6
const SKY_DIRS: Array[Vector3] = [Vector3(0, 1, 0), Vector3(0.5, 0.86, 0.3)]
const AO_DISTANCE: float = 2.6
const SKY_DISTANCE: float = 40.0
const ORIGIN_OFFSET: float = 0.03
const LAYER: int = 1 << 19

## 다음 세 값이 조절 손잡이다. 튜닝은 여기서.
static var ao_strength: float = 1.0
static var ao_distance: float = AO_DISTANCE


## 장면에 라이트맵 데이터가 들어 있는 LightmapGI가 있나. 있으면 정점 베이크(와 셰이더의 vertex_bake)를 쓰지 않는다.
static func lightmap_present(root: Node) -> bool:
	for node: Node in root.find_children("*", "LightmapGI", true, false):
		if (node as LightmapGI).light_data != null:
			return true
	return false


## 베이크를 돌린다. host는 씬 트리에 들어 있어야 한다. lamps = [{pos: Vector3, radius: float}].
## 반환: {vertices, unique, rays, ms}.
static func run(host: Node3D, kit: StyleKit, lamps: Array[Dictionary], ray_count: int = AO_RAYS) -> Dictionary:
	var t0: int = Time.get_ticks_msec()
	var body := StaticBody3D.new()
	body.name = "BakeColliders"
	body.collision_layer = LAYER
	body.collision_mask = 0
	host.add_child(body)
	var shape_count: int = 0
	for group_name: StringName in kit.groups:
		if SKIP_GROUPS.has(group_name):
			continue
		var faces := PackedVector3Array()
		for surf: MeshBuilder.Surface in (kit.groups[group_name] as MeshBuilder).surfaces():
			faces.append_array(surf.verts)
		if faces.size() < 3:
			continue
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		shape_count += 1
	var tree: SceneTree = host.get_tree()
	await tree.physics_frame
	await tree.physics_frame
	var space: PhysicsDirectSpaceState3D = host.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = LAYER
	query.hit_from_inside = false
	query.collide_with_areas = false
	var dirs: PackedVector3Array = VertexAo.hemisphere_dirs(ray_count)
	var cache: Dictionary[int, Color] = {}
	var vertex_total: int = 0
	var ray_total: int = 0
	for group_name: StringName in kit.groups:
		if SKIP_GROUPS.has(group_name):
			continue
		var builder: MeshBuilder = kit.groups[group_name]
		for surf: MeshBuilder.Surface in builder.surfaces():
			var count: int = surf.verts.size()
			vertex_total += count
			if count == 0 or surf.colors.size() != count:
				continue
			for i: int in range(count):
				var pos: Vector3 = surf.verts[i]
				var nrm: Vector3 = surf.normals[i]
				var key: int = VertexAo.key(pos, nrm)
				if cache.has(key):
					surf.colors[i] = cache[key]
					continue
				var c: Color = _shade_vertex(space, query, pos, nrm, dirs, lamps, key)
				ray_total += ray_count + SKY_DIRS.size() + lamps.size()
				cache[key] = c
				surf.colors[i] = c
	body.queue_free()
	var ms: int = Time.get_ticks_msec() - t0
	print(PREFIX + "vertex_ao vertices=%d unique=%d rays=%d shapes=%d ms=%d" % [vertex_total, cache.size(), ray_total, shape_count, ms])
	return {"vertices": vertex_total, "unique": cache.size(), "rays": ray_total, "ms": ms}


static func _shade_vertex(space: PhysicsDirectSpaceState3D, query: PhysicsRayQueryParameters3D, pos: Vector3, nrm: Vector3,
		dirs: PackedVector3Array, lamps: Array[Dictionary], key: int) -> Color:
	var n: Vector3 = nrm.normalized()
	var origin: Vector3 = pos + n * ORIGIN_OFFSET
	var spin: float = float(key & 0xFFFF) / 65535.0 * TAU
	var weight_sum: float = 0.0
	for d: Vector3 in dirs:
		var dir: Vector3 = VertexAo.orient(d, n, spin)
		query.from = origin
		query.to = origin + dir * ao_distance
		var hit: Dictionary = space.intersect_ray(query)
		if not hit.is_empty():
			weight_sum += VertexAo.hit_weight(origin.distance_to(hit["position"] as Vector3), ao_distance)
	var ao: float = VertexAo.ao_value(weight_sum, dirs.size(), ao_strength)
	var open_sky: int = 0
	for sd: Vector3 in SKY_DIRS:
		query.from = origin
		query.to = origin + sd * SKY_DISTANCE
		if space.intersect_ray(query).is_empty():
			open_sky += 1
	var sky: float = float(open_sky) / float(SKY_DIRS.size())
	var warm: float = 0.0
	for lamp: Dictionary in lamps:
		var lp: Vector3 = lamp["pos"]
		var radius: float = lamp["radius"]
		if origin.distance_to(lp) >= radius:
			continue
		query.from = origin
		query.to = lp
		var seen: bool = space.intersect_ray(query).is_empty()
		warm += VertexAo.lamp_warmth(pos, n, lp, radius, seen)
	return VertexAo.pack(ao, sky, minf(warm, 1.0))
