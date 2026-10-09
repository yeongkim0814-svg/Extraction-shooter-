extends GutTest
## MeshChunker: 칸 배정, 삼각형 보존(수·중복·누락 없음), 덩어리 범위, 재질 표면 유지.

const CELL: float = 8.0
var _mat_a: StandardMaterial3D
var _mat_b: StandardMaterial3D


func before_each() -> void:
	_mat_a = StandardMaterial3D.new()
	_mat_b = StandardMaterial3D.new()


## 격자 위에 흩어 놓은 작은 상자들을 두 재질로 나눠 담은 메시.
func _scatter_mesh() -> ArrayMesh:
	var b := MeshBuilder.new()
	for i: int in range(60):
		b.surface(_mat_a if i % 2 == 0 else _mat_b)
		var pos := Vector3(float(i % 10) * 3.7 - 5.0, 0.5, float(i / 10) * 4.3 - 6.0)
		b.add_box(Transform3D(Basis.IDENTITY, pos), Vector3(1.0, 1.0, 1.0))
	return b.build()


func test_cell_of_uses_floor() -> void:
	assert_eq(MeshChunker.cell_of(Vector3(0.0, 5.0, 0.0), CELL), Vector2i(0, 0))
	assert_eq(MeshChunker.cell_of(Vector3(7.99, 0.0, 8.0), CELL), Vector2i(0, 1))
	assert_eq(MeshChunker.cell_of(Vector3(-0.01, 0.0, -8.01), CELL), Vector2i(-1, -2))


func test_group_triangles_assigns_each_triangle_once() -> void:
	var verts := PackedVector3Array([
			Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, 1),
			Vector3(9, 0, 0), Vector3(10, 0, 0), Vector3(9, 0, 1)])
	var groups: Dictionary[Vector2i, PackedInt32Array] = MeshChunker.group_triangles(verts, PackedInt32Array(), CELL)
	assert_eq(groups.size(), 2)
	assert_eq(groups[Vector2i(0, 0)], PackedInt32Array([0]))
	assert_eq(groups[Vector2i(1, 0)], PackedInt32Array([1]))


func test_group_triangles_respects_index_buffer() -> void:
	var verts := PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(20, 0, 0)])
	var idx := PackedInt32Array([0, 1, 2, 3, 3, 3])
	var groups: Dictionary[Vector2i, PackedInt32Array] = MeshChunker.group_triangles(verts, idx, CELL)
	assert_eq(groups[Vector2i(0, 0)], PackedInt32Array([0]))
	assert_eq(groups[Vector2i(2, 0)], PackedInt32Array([1]))


func test_split_preserves_triangle_count() -> void:
	var mesh: ArrayMesh = _scatter_mesh()
	var chunks: Array[ArrayMesh] = MeshChunker.split_mesh(mesh, CELL)
	var total: int = 0
	for c: ArrayMesh in chunks:
		total += MeshChunker.triangle_count(c)
	assert_gt(chunks.size(), 1, "여러 칸으로 나뉜다")
	assert_eq(total, MeshChunker.triangle_count(mesh), "삼각형이 늘지도 줄지도 않는다")


func test_split_preserves_surface_area() -> void:
	var mesh: ArrayMesh = _scatter_mesh()
	var total: float = 0.0
	for c: ArrayMesh in MeshChunker.split_mesh(mesh, CELL):
		total += MeshChunker.surface_area(c)
	assert_almost_eq(total, MeshChunker.surface_area(mesh), 0.01)


func test_every_triangle_centroid_lies_in_its_chunk_cell() -> void:
	var chunks: Array[ArrayMesh] = MeshChunker.split_mesh(_scatter_mesh(), CELL)
	var seen: Dictionary[Vector2i, bool] = {}
	for c: ArrayMesh in chunks:
		var cells: Dictionary[Vector2i, bool] = {}
		for s: int in range(c.get_surface_count()):
			var arrays: Array = c.surface_get_arrays(s)
			var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for t: int in range(idx.size() / 3):
				var cen: Vector3 = (v[idx[t * 3]] + v[idx[t * 3 + 1]] + v[idx[t * 3 + 2]]) / 3.0
				cells[MeshChunker.cell_of(cen, CELL)] = true
		assert_eq(cells.size(), 1, "한 덩어리는 한 칸에만 속한다")
		for k: Vector2i in cells:
			assert_false(seen.has(k), "칸이 두 덩어리로 갈라지지 않는다")
			seen[k] = true


func test_chunk_extent_bounded_by_cell_plus_triangle() -> void:
	# 상자 한 변이 1 m이므로 덩어리는 칸 + 1 m(삼각형 범위)를 넘지 않는다.
	for c: ArrayMesh in MeshChunker.split_mesh(_scatter_mesh(), CELL):
		var size: Vector3 = c.get_aabb().size
		assert_lte(size.x, CELL + 1.0 + 0.001)
		assert_lte(size.z, CELL + 1.0 + 0.001)


func test_split_keeps_materials_and_drops_empty_surfaces() -> void:
	var b := MeshBuilder.new()
	b.surface(_mat_a)
	b.add_box(Transform3D(Basis.IDENTITY, Vector3(1, 0.5, 1)), Vector3.ONE)
	b.surface(_mat_b)
	b.add_box(Transform3D(Basis.IDENTITY, Vector3(20, 0.5, 1)), Vector3.ONE)
	var chunks: Array[ArrayMesh] = MeshChunker.split_mesh(b.build(), CELL)
	assert_eq(chunks.size(), 2)
	assert_eq(chunks[0].get_surface_count(), 1)
	assert_eq(chunks[0].surface_get_material(0), _mat_a)
	assert_eq(chunks[1].surface_get_material(0), _mat_b)


func test_split_order_is_stable_by_cell() -> void:
	var a: Array[ArrayMesh] = MeshChunker.split_mesh(_scatter_mesh(), CELL)
	var b: Array[ArrayMesh] = MeshChunker.split_mesh(_scatter_mesh(), CELL)
	assert_eq(a.size(), b.size())
	for i: int in range(a.size()):
		assert_eq(a[i].get_aabb(), b[i].get_aabb())


func test_split_keeps_vertex_attributes() -> void:
	var b := MeshBuilder.new()
	b.with_tangents = true
	b.surface(_mat_a)
	b.add_box(Transform3D(Basis.IDENTITY, Vector3(1, 0.5, 1)), Vector3.ONE)
	b.add_box(Transform3D(Basis.IDENTITY, Vector3(30, 0.5, 1)), Vector3.ONE)
	var src: ArrayMesh = b.build()
	var chunks: Array[ArrayMesh] = MeshChunker.split_mesh(src, CELL)
	assert_eq(chunks.size(), 2)
	var arrays: Array = chunks[0].surface_get_arrays(0)
	var n: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	assert_eq((arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).size(), n)
	assert_eq((arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size(), n)
	assert_eq((arrays[Mesh.ARRAY_COLOR] as PackedColorArray).size(), n)
	assert_eq((arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array).size(), n * 4)
