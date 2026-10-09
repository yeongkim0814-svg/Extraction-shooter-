extends GutTest
## MeshBuilder: 모따기 박스·회전체·압출의 삼각형 수, 경계, 감김 방향, 법선, 정점 색 (스타일 비교 씬의 기반).

var _mat: StandardMaterial3D


func before_each() -> void:
	_mat = StandardMaterial3D.new()


func _builder() -> MeshBuilder:
	var b := MeshBuilder.new()
	b.surface(_mat)
	return b


func _arrays(b: MeshBuilder) -> Array:
	return b.build().surface_get_arrays(0)


func test_plain_box_has_twelve_triangles() -> void:
	var b: MeshBuilder = _builder()
	b.add_box(Transform3D.IDENTITY, Vector3(2, 1, 4))
	assert_eq(b.triangle_count, 12)


func test_chamfer_triangle_counts_by_segments() -> void:
	var one: MeshBuilder = _builder()
	one.add_box(Transform3D.IDENTITY, Vector3(2, 2, 2), 0.2, 1)
	assert_eq(one.triangle_count, 44, "1분할: 모서리 8 + 띠 24 + 면 12")
	var two: MeshBuilder = _builder()
	two.add_box(Transform3D.IDENTITY, Vector3(2, 2, 2), 0.2, 2)
	assert_eq(two.triangle_count, 92, "2분할: 모서리 32 + 띠 48 + 면 12")


func test_chamfer_box_fits_requested_bounds() -> void:
	var b: MeshBuilder = _builder()
	b.add_box(Transform3D.IDENTITY, Vector3(6, 2.6, 2.4), 0.12, 2)
	var aabb: AABB = b.build().get_aabb()
	assert_almost_eq(aabb.size.x, 6.0, 0.001)
	assert_almost_eq(aabb.size.y, 2.6, 0.001)
	assert_almost_eq(aabb.size.z, 2.4, 0.001)
	assert_almost_eq(aabb.get_center().length(), 0.0, 0.001)


func test_chamfer_is_clamped_to_half_size() -> void:
	var b: MeshBuilder = _builder()
	b.add_box(Transform3D.IDENTITY, Vector3(0.2, 1.0, 1.0), 5.0, 1)
	var aabb: AABB = b.build().get_aabb()
	assert_almost_eq(aabb.size.x, 0.2, 0.001)
	assert_gt(b.triangle_count, 0)


func test_windings_face_outward_for_front_clockwise() -> void:
	var b: MeshBuilder = _builder()
	b.add_box(Transform3D.IDENTITY, Vector3(2, 2, 2), 0.3, 2)
	var arrays: Array = _arrays(b)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i: int in range(0, verts.size(), 3):
		var cross: Vector3 = (verts[i + 1] - verts[i]).cross(verts[i + 2] - verts[i])
		var centroid: Vector3 = (verts[i] + verts[i + 1] + verts[i + 2]) / 3.0
		# 시계 방향 전면: 외적은 바깥의 반대쪽을 본다
		assert_lt(cross.dot(centroid), 0.0, "삼각형 %d가 안쪽을 향함" % (i / 3))


func test_normals_are_unit_and_outward() -> void:
	var b: MeshBuilder = _builder()
	b.add_box(Transform3D.IDENTITY, Vector3(2, 2, 2), 0.3, 2)
	var arrays: Array = _arrays(b)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i: int in range(verts.size()):
		assert_almost_eq(normals[i].length(), 1.0, 0.001)
		assert_gt(normals[i].dot(verts[i]), 0.0)


func test_flat_shading_gives_one_normal_per_triangle() -> void:
	var b: MeshBuilder = _builder()
	b.flat_shading = true
	b.add_box(Transform3D.IDENTITY, Vector3(2, 2, 2), 0.3, 2)
	var normals: PackedVector3Array = _arrays(b)[Mesh.ARRAY_NORMAL]
	for i: int in range(0, normals.size(), 3):
		assert_almost_eq(normals[i].distance_to(normals[i + 1]), 0.0, 0.0001)
		assert_almost_eq(normals[i].distance_to(normals[i + 2]), 0.0, 0.0001)


func test_transform_is_applied() -> void:
	var b: MeshBuilder = _builder()
	b.add_box(Transform3D(Basis.IDENTITY, Vector3(10, 5, -3)), Vector3(2, 2, 2))
	var aabb: AABB = b.build().get_aabb()
	assert_almost_eq(aabb.get_center().x, 10.0, 0.001)
	assert_almost_eq(aabb.get_center().y, 5.0, 0.001)
	assert_almost_eq(aabb.get_center().z, -3.0, 0.001)


func test_cylinder_bounds_and_cap_triangles() -> void:
	var b: MeshBuilder = _builder()
	b.add_cylinder(Transform3D.IDENTITY, 0.5, 1.0, 12)
	assert_eq(b.triangle_count, 12 + 24 + 12, "마개 12 + 옆면 24 + 마개 12")
	var aabb: AABB = b.build().get_aabb()
	assert_almost_eq(aabb.size.y, 1.0, 0.001)
	assert_almost_eq(aabb.size.x, 1.0, 0.01)


func test_prism_extrudes_profile() -> void:
	var b: MeshBuilder = _builder()
	var tri := PackedVector2Array([Vector2(0, 0), Vector2(2, 0), Vector2(1, 1)])
	b.add_prism(Transform3D.IDENTITY, tri, 4.0)
	assert_eq(b.triangle_count, 6 + 2, "옆면 사각형 3장(삼각형 6) + 마개 2")
	var aabb: AABB = b.build().get_aabb()
	assert_almost_eq(aabb.size.z, 4.0, 0.001)
	assert_almost_eq(aabb.size.x, 2.0, 0.001)


func test_surfaces_split_by_material() -> void:
	var b: MeshBuilder = _builder()
	var other := StandardMaterial3D.new()
	b.add_box(Transform3D.IDENTITY, Vector3.ONE)
	b.surface(other)
	b.add_box(Transform3D(Basis.IDENTITY, Vector3(3, 0, 0)), Vector3.ONE)
	b.surface(_mat)
	b.add_box(Transform3D(Basis.IDENTITY, Vector3(6, 0, 0)), Vector3.ONE)
	var mesh: ArrayMesh = b.build()
	assert_eq(mesh.get_surface_count(), 2)
	assert_eq(mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size(), 72, "첫 재질에 상자 2개")


func test_gradient_darkens_low_vertices() -> void:
	var b: MeshBuilder = _builder()
	b.set_gradient(-1.0, 1.0, 0.5)
	b.add_box(Transform3D.IDENTITY, Vector3(2, 2, 2))
	var arrays: Array = _arrays(b)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var low: float = 2.0
	var high: float = 0.0
	for i: int in range(verts.size()):
		if verts[i].y < -0.9:
			low = minf(low, colors[i].r)
		if verts[i].y > 0.9:
			high = maxf(high, colors[i].r)
	assert_almost_eq(low, 0.5, 0.01)
	assert_almost_eq(high, 1.0, 0.01)


func test_tangents_are_generated_on_request() -> void:
	var b: MeshBuilder = _builder()
	b.with_tangents = true
	b.add_box(Transform3D.IDENTITY, Vector3(2, 2, 2), 0.2, 1)
	var arrays: Array = _arrays(b)
	assert_not_null(arrays[Mesh.ARRAY_TANGENT])
	assert_gt((arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array).size(), 0)


## 월드 UV: 이웃한 두 상자의 같은 월드 점은 같은 UV, 위로 갈수록 v가 줄어든다 (텍스처 아래쪽 = y 0).
func test_world_uv_is_continuous_across_boxes() -> void:
	var b: MeshBuilder = _builder()
	b.world_uv = true
	b.add_box(Transform3D(Basis.IDENTITY, Vector3(3.0, 1.0, 0.0)), Vector3(2, 2, 2))
	b.add_box(Transform3D(Basis.IDENTITY, Vector3(5.0, 1.0, 0.0)), Vector3(2, 2, 2))
	var arrays: Array = _arrays(b)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var checked: int = 0
	for i: int in range(verts.size()):
		if norms[i].z > 0.9:
			assert_almost_eq(uvs[i].x, verts[i].x, 0.0001)
			assert_almost_eq(uvs[i].y, -verts[i].y, 0.0001)
			checked += 1
	assert_gt(checked, 0)


func test_world_uv_follows_box_rotation() -> void:
	var b: MeshBuilder = _builder()
	b.world_uv = true
	var base := Transform3D(Basis(Vector3.UP, 0.6), Vector3(4.0, 0.0, 2.0))
	b.add_box(Transform3D(base.basis, base * Vector3(0.0, 1.0, 0.0)), Vector3(2, 2, 2))
	var arrays: Array = _arrays(b)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	# 옆면의 v는 회전과 상관없이 -월드 y (때 그라데이션이 지면에서 시작)
	var sides: int = 0
	for i: int in range(verts.size()):
		if absf(norms[i].y) < 0.05:
			assert_almost_eq(uvs[i].y, -verts[i].y, 0.0001)
			sides += 1
	assert_gt(sides, 0)
