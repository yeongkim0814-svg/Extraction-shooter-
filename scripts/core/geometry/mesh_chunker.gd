class_name MeshChunker
extends RefCounted
## 큰 메시를 XZ 격자 칸 단위로 쪼갠다 (라이트맵 UV2 차트가 한 덩어리로 커지지 않게).
## 삼각형은 무게중심이 속한 칸에 통째로 배정한다 -> 삼각형은 잘리지 않고 빠지거나 겹치지도 않는다.
## 그래서 칸 경계를 넘는 큰 삼각형은 그 칸의 덩어리를 칸보다 키운다 (덩어리 범위 <= 칸 + 가장 큰 삼각형 변).
## 순수 지오메트리라 노드·씬 트리에 의존하지 않는다 (ArrayMesh는 리소스이며 헤드리스 테스트 가능).
##
## 라이트맵 크기 근거 (Godot 4.7 lightmap_unwrap)
## - texel_size는 "텍셀 하나의 월드 길이(m)"다. 표면적 A(m²)의 메시는 대략 A / texel² 텍셀이 필요하다.
##   예: 0.25 m 텍셀이면 A = 66 m² 이 약 1056 텍셀이다. (2048 x 0.25)² / 4 = 65536 m² 이니 "한 장에 들어가는 면적"의 한계는
##   66 m²가 아니라 약 6.6만 m² 이다. 실제 경고의 기준은 메시가 내놓는 lightmap_size_hint가 max_texture_size를 넘는지다.
## - xatlas는 차트를 한 텍스처에 패킹하므로, 큰 메시일수록 힌트가 커지고 다른 메시와 한 장에 못 담긴다.
##   메시를 칸(기본 8 m)으로 쪼개면 힌트가 칸 면적에 비례해 작아져 한 장에 여러 덩어리가 여유 있게 들어간다.

## 기본 칸 한 변 (m).
const DEFAULT_CELL_M: float = 8.0


## 점이 속한 격자 칸 (XZ). 칸 경계에서는 floor 규칙이라 아래쪽·왼쪽 경계가 칸에 포함된다.
static func cell_of(p: Vector3, cell_m: float) -> Vector2i:
	return Vector2i(int(floorf(p.x / cell_m)), int(floorf(p.z / cell_m)))


## 정점 배열(삼각형 목록, indices가 비면 3개씩 순서대로)을 무게중심 칸별로 묶는다.
## 반환: 칸 -> 삼각형 번호(0부터) 배열. 삼각형 번호 t는 정점 3t..3t+2 (또는 indices[3t..3t+2])를 가리킨다.
static func group_triangles(verts: PackedVector3Array, indices: PackedInt32Array, cell_m: float) -> Dictionary[Vector2i, PackedInt32Array]:
	var out: Dictionary[Vector2i, PackedInt32Array] = {}
	var count: int = (indices.size() if not indices.is_empty() else verts.size()) / 3
	for t: int in range(count):
		var i0: int = t * 3
		var i1: int = t * 3 + 1
		var i2: int = t * 3 + 2
		if not indices.is_empty():
			i0 = indices[i0]
			i1 = indices[i1]
			i2 = indices[i2]
		var c: Vector3 = (verts[i0] + verts[i1] + verts[i2]) / 3.0
		var key: Vector2i = cell_of(c, cell_m)
		if not out.has(key):
			out[key] = PackedInt32Array()
		var list: PackedInt32Array = out[key]
		list.append(t)
		out[key] = list
	return out


## 메시를 칸별 ArrayMesh로 쪼갠다. 표면(재질)은 원본 순서를 지키고, 그 칸에 삼각형이 없는 표면은 뺀다.
## 반환 순서는 칸 (x, z) 오름차순이라 이름 번호가 실행마다 같다.
static func split_mesh(mesh: ArrayMesh, cell_m: float = DEFAULT_CELL_M) -> Array[ArrayMesh]:
	var keys: Array[Vector2i] = []
	var per_surface: Array[Dictionary] = []
	for s: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			idx = arrays[Mesh.ARRAY_INDEX]
		var groups: Dictionary[Vector2i, PackedInt32Array] = group_triangles(verts, idx, cell_m)
		per_surface.append(groups)
		for k: Vector2i in groups:
			if not keys.has(k):
				keys.append(k)
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	var out: Array[ArrayMesh] = []
	for k: Vector2i in keys:
		var chunk := ArrayMesh.new()
		for s: int in range(mesh.get_surface_count()):
			var groups: Dictionary[Vector2i, PackedInt32Array] = per_surface[s]
			if not groups.has(k):
				continue
			var sub: Array = _extract(mesh.surface_get_arrays(s), groups[k])
			chunk.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sub)
			chunk.surface_set_material(chunk.get_surface_count() - 1, mesh.surface_get_material(s))
			chunk.surface_set_name(chunk.get_surface_count() - 1, mesh.surface_get_name(s))
		out.append(chunk)
	return out


## 삼각형 번호 목록만 담은 새 표면 배열 (사용한 정점만 다시 번호 매김, 같은 정점은 공유).
static func _extract(arrays: Array, tris: PackedInt32Array) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		idx = arrays[Mesh.ARRAY_INDEX]
	var remap: Dictionary[int, int] = {}
	var order: PackedInt32Array = PackedInt32Array()
	var new_idx: PackedInt32Array = PackedInt32Array()
	for t: int in tris:
		for k: int in range(3):
			var src: int = idx[t * 3 + k] if not idx.is_empty() else t * 3 + k
			if not remap.has(src):
				remap[src] = order.size()
				order.append(src)
			new_idx.append(remap[src])
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	var n: int = verts.size()
	for slot: int in range(Mesh.ARRAY_MAX):
		var a: Variant = arrays[slot]
		if a == null or slot == Mesh.ARRAY_INDEX:
			continue
		if a is PackedVector3Array:
			var src3: PackedVector3Array = a
			if src3.size() != n:
				continue
			var dst3 := PackedVector3Array()
			for o: int in order:
				dst3.append(src3[o])
			out[slot] = dst3
		elif a is PackedVector2Array:
			var src2: PackedVector2Array = a
			if src2.size() != n:
				continue
			var dst2 := PackedVector2Array()
			for o: int in order:
				dst2.append(src2[o])
			out[slot] = dst2
		elif a is PackedColorArray:
			var srcc: PackedColorArray = a
			if srcc.size() != n:
				continue
			var dstc := PackedColorArray()
			for o: int in order:
				dstc.append(srcc[o])
			out[slot] = dstc
		elif a is PackedFloat32Array:
			var srcf: PackedFloat32Array = a
			if srcf.size() != n * 4:
				continue
			var dstf := PackedFloat32Array()
			for o: int in order:
				for c: int in range(4):
					dstf.append(srcf[o * 4 + c])
			out[slot] = dstf
	out[Mesh.ARRAY_INDEX] = new_idx
	return out


## 메시의 총 표면적 (m²).
static func surface_area(mesh: ArrayMesh) -> float:
	var area: float = 0.0
	for s: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			idx = arrays[Mesh.ARRAY_INDEX]
		var count: int = (idx.size() if not idx.is_empty() else verts.size()) / 3
		for t: int in range(count):
			var a: int = idx[t * 3] if not idx.is_empty() else t * 3
			var b: int = idx[t * 3 + 1] if not idx.is_empty() else t * 3 + 1
			var c: int = idx[t * 3 + 2] if not idx.is_empty() else t * 3 + 2
			area += (verts[b] - verts[a]).cross(verts[c] - verts[a]).length() * 0.5
	return area


## 메시의 삼각형 수.
static func triangle_count(mesh: ArrayMesh) -> int:
	var n: int = 0
	for s: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		if arrays[Mesh.ARRAY_INDEX] != null:
			n += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		else:
			n += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n
