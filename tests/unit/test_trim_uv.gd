extends GutTest
## 트림시트 UV 사상(TrimUv)·줄 배치(TrimLayout)·MeshBuilder 트림 모드·정점 AO 순수 계산(VertexAo).

const LO: Vector3 = Vector3(-1.0, -0.5, -0.25)
const HI: Vector3 = Vector3(1.0, 0.5, 0.25)
const STRIP: Vector2 = Vector2(0.25, 0.375)


func test_face_of_picks_dominant_axis() -> void:
	assert_eq(TrimUv.face_of(Vector3(1, 0.2, 0.1)), TrimUv.PX)
	assert_eq(TrimUv.face_of(Vector3(-1, 0.2, 0.1)), TrimUv.NX)
	assert_eq(TrimUv.face_of(Vector3(0.1, 1, 0.3)), TrimUv.PY)
	assert_eq(TrimUv.face_of(Vector3(0.1, -1, 0.3)), TrimUv.NY)
	assert_eq(TrimUv.face_of(Vector3(0.1, 0.2, 1)), TrimUv.PZ)
	assert_eq(TrimUv.face_of(Vector3(0.1, 0.2, -1)), TrimUv.NZ)


func test_v_spans_strip_range_bottom_to_top() -> void:
	var bottom: Vector2 = TrimUv.map_planar(Vector3(0, LO.y, HI.z), LO, HI, TrimUv.PZ, STRIP, 4.0)
	var top: Vector2 = TrimUv.map_planar(Vector3(0, HI.y, HI.z), LO, HI, TrimUv.PZ, STRIP, 4.0)
	assert_almost_eq(bottom.y, STRIP.y, 0.0001, "면 아래 끝 = 줄 아래(v1)")
	assert_almost_eq(top.y, STRIP.x, 0.0001, "면 위 끝 = 줄 위(v0)")


func test_u_counts_world_meters_at_fixed_density() -> void:
	var a: Vector2 = TrimUv.map_planar(Vector3(LO.x, 0, HI.z), LO, HI, TrimUv.PZ, STRIP, TrimLayout.TILE_M)
	var b: Vector2 = TrimUv.map_planar(Vector3(HI.x, 0, HI.z), LO, HI, TrimUv.PZ, STRIP, TrimLayout.TILE_M)
	assert_almost_eq(a.x, 0.0, 0.0001)
	assert_almost_eq(b.x - a.x, 2.0 / TrimLayout.TILE_M, 0.0001, "2 m 면은 U가 2 / 4 = 0.5 진행")


func test_opposite_faces_run_opposite_directions() -> void:
	var pz: float = TrimUv.map_planar(Vector3(0.5, 0, HI.z), LO, HI, TrimUv.PZ, STRIP, 4.0).x
	var nz: float = TrimUv.map_planar(Vector3(0.5, 0, LO.z), LO, HI, TrimUv.NZ, STRIP, 4.0).x
	assert_ne(pz, nz, "앞뒤 면은 U 방향이 반대라 같은 점에서 값이 다르다")


func test_top_face_maps_depth_into_strip() -> void:
	var near: Vector2 = TrimUv.map_planar(Vector3(0, HI.y, LO.z), LO, HI, TrimUv.PY, STRIP, 4.0)
	var far: Vector2 = TrimUv.map_planar(Vector3(0, HI.y, HI.z), LO, HI, TrimUv.PY, STRIP, 4.0)
	assert_almost_eq(near.y, STRIP.x, 0.0001)
	assert_almost_eq(far.y, STRIP.y, 0.0001)


func test_wrap_repeats_whole_tiles_around_circumference() -> void:
	var seam_end: Vector2 = TrimUv.map_wrap(1.0, 0.29, 0.5, STRIP, 4.0)
	assert_almost_eq(seam_end.x, roundf(seam_end.x), 0.0001, "둘레 끝의 U는 정수라 이음매가 맞는다")
	assert_gte(seam_end.x, 1.0)


func test_axial_fold_is_continuous_at_seam() -> void:
	var a: Vector2 = TrimUv.map_axial(0.0, 1.0, STRIP, 4.0)
	var b: Vector2 = TrimUv.map_axial(1.0, 1.0, STRIP, 4.0)
	assert_almost_eq(a.y, b.y, 0.0001)
	assert_almost_eq(TrimUv.map_axial(0.5, 2.0, STRIP, 4.0).x, 0.5, 0.0001)


func test_layout_strips_fit_sheet_without_overlap() -> void:
	for sheet: int in TrimLayout.STRIPS:
		var spans: Array[Vector2i] = []
		for span: Vector2i in (TrimLayout.STRIPS[sheet] as Dictionary).values():
			assert_gte(span.x, 0)
			assert_lte(span.x + span.y, TrimLayout.SIZE, "시트 안에 들어간다")
			for other: Vector2i in spans:
				assert_true(span.x >= other.x + other.y or other.x >= span.x + span.y, "줄이 겹치지 않는다")
			spans.append(span)


func test_layout_matches_generator_json() -> void:
	var f := FileAccess.open("res://assets/textures/trim/trim_layout.json", FileAccess.READ)
	assert_not_null(f, "trim_layout.json이 있다 (tools/gen_trim_sheets.py)")
	if f == null:
		return
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	assert_eq(int(data["size"]), TrimLayout.SIZE)
	assert_eq(float(data["texels_per_m"]), TrimLayout.TEXELS_PER_M)
	for sheet: int in TrimLayout.STRIPS:
		var table: Dictionary = (data["sheets"] as Dictionary)[str(sheet)]
		assert_eq(table.size(), (TrimLayout.STRIPS[sheet] as Dictionary).size())
		for strip_name: StringName in TrimLayout.STRIPS[sheet]:
			var span: Vector2i = TrimLayout.STRIPS[sheet][strip_name]
			assert_eq(int(table[String(strip_name)]["y"]), span.x, "%s y" % strip_name)
			assert_eq(int(table[String(strip_name)]["h"]), span.y, "%s h" % strip_name)


func test_v_range_and_height() -> void:
	var r: Vector2 = TrimLayout.v_range(1, TrimLayout.BRICK)
	assert_almost_eq(r.x, 384.0 / 1024.0, 0.00001)
	assert_almost_eq(r.y, 540.0 / 1024.0, 0.00001)
	assert_almost_eq(TrimLayout.strip_height_m(1, TrimLayout.BRICK), 156.0 / 256.0, 0.00001)


func _trim_builder(v: Vector2) -> MeshBuilder:
	var b := MeshBuilder.new()
	b.surface(StandardMaterial3D.new())
	b.trim_strips = TrimUv.uniform_strips(v)
	return b


func test_builder_box_uv_stays_inside_strip_range() -> void:
	var b: MeshBuilder = _trim_builder(STRIP)
	b.add_box(Transform3D(Basis.IDENTITY, Vector3(3, 1, 2)), Vector3(2.4, 2.0, 0.6), 0.1, 2)
	var uvs: PackedVector2Array = b.build().surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	assert_gt(uvs.size(), 0)
	var vmin: float = 10.0
	var vmax: float = -10.0
	for uv: Vector2 in uvs:
		vmin = minf(vmin, uv.y)
		vmax = maxf(vmax, uv.y)
	assert_gte(vmin, STRIP.x - 0.0001)
	assert_lte(vmax, STRIP.y + 0.0001)


func test_builder_front_face_hits_strip_edges() -> void:
	# 모따기 없는 박스의 앞면(+Z): 아래 모서리는 v1, 위 모서리는 v0에 정확히 닿는다
	var b: MeshBuilder = _trim_builder(STRIP)
	b.add_box(Transform3D.IDENTITY, Vector3(2, 2, 2), 0.0)
	var arrays: Array = b.build().surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var checked: int = 0
	for i: int in range(verts.size()):
		if normals[i].z > 0.9:
			var expect: float = STRIP.y if verts[i].y < 0.0 else STRIP.x
			assert_almost_eq(uvs[i].y, expect, 0.0001)
			checked += 1
	assert_eq(checked, 6)


func test_builder_without_trim_keeps_box_projection() -> void:
	var b := MeshBuilder.new()
	b.surface(StandardMaterial3D.new())
	b.add_box(Transform3D.IDENTITY, Vector3(2, 2, 2), 0.0)
	var uvs: PackedVector2Array = b.build().surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	var outside: bool = false
	for uv: Vector2 in uvs:
		outside = outside or uv.y < 0.0
	assert_true(outside, "트림을 끄면 기존 박스 투영(-y)이다")


func test_subdivision_splits_long_triangles_and_keeps_area() -> void:
	var plain := MeshBuilder.new()
	plain.surface(StandardMaterial3D.new())
	plain.add_box(Transform3D.IDENTITY, Vector3(10, 0.2, 6), 0.0)
	var split := MeshBuilder.new()
	split.surface(StandardMaterial3D.new())
	split.subdiv_max = 2.0
	split.add_box(Transform3D.IDENTITY, Vector3(10, 0.2, 6), 0.0)
	assert_gt(split.triangle_count, plain.triangle_count)
	assert_almost_eq(split.build().get_aabb().size.x, 10.0, 0.001)
	var verts: PackedVector3Array = split.build().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for t: int in range(0, verts.size(), 3):
		var longest: float = maxf(verts[t].distance_to(verts[t + 1]), maxf(verts[t + 1].distance_to(verts[t + 2]), verts[t + 2].distance_to(verts[t])))
		assert_lte(longest, 2.0 * 1.0001 + 0.0001, "변이 subdiv_max 이하")


func test_cylinder_wrap_uv_has_whole_repeats() -> void:
	var b: MeshBuilder = _trim_builder(STRIP)
	b.add_cylinder(Transform3D.IDENTITY, 0.3, 0.9, 12)
	var uvs: PackedVector2Array = b.build().surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	assert_gt(uvs.size(), 0)
	for uv: Vector2 in uvs:
		assert_gte(uv.y, STRIP.x - 0.0001)
		assert_lte(uv.y, STRIP.y + 0.0001)


func test_hemisphere_dirs_are_unit_and_upward() -> void:
	var dirs: PackedVector3Array = VertexAo.hemisphere_dirs(12)
	assert_eq(dirs.size(), 12)
	for d: Vector3 in dirs:
		assert_almost_eq(d.length(), 1.0, 0.0001)
		assert_gt(d.z, 0.0)


func test_orient_keeps_angle_to_normal() -> void:
	var n: Vector3 = Vector3(0.3, 0.8, -0.5).normalized()
	for d: Vector3 in VertexAo.hemisphere_dirs(8):
		var o: Vector3 = VertexAo.orient(d, n, 1.3)
		assert_almost_eq(o.dot(n), d.z, 0.0001)
		assert_almost_eq(o.length(), 1.0, 0.0001)


func test_ao_value_and_hit_weight() -> void:
	assert_almost_eq(VertexAo.ao_value(0.0, 8, 1.0), 1.0, 0.0001)
	assert_almost_eq(VertexAo.ao_value(8.0, 8, 1.0), 0.0, 0.0001)
	assert_gt(VertexAo.hit_weight(0.2, 2.0), VertexAo.hit_weight(1.5, 2.0), "가까운 가림이 더 어둡다")
	assert_eq(VertexAo.hit_weight(3.0, 2.0), 0.0)


func test_lamp_warmth_falls_off_and_needs_sight() -> void:
	var near: float = VertexAo.lamp_warmth(Vector3(0, 0, 0), Vector3.UP, Vector3(0, 2, 0), 6.0, true)
	var far: float = VertexAo.lamp_warmth(Vector3(0, 0, 0), Vector3.UP, Vector3(0, 5, 0), 6.0, true)
	assert_gt(near, far)
	assert_eq(VertexAo.lamp_warmth(Vector3.ZERO, Vector3.UP, Vector3(0, 2, 0), 6.0, false), 0.0)
	assert_eq(VertexAo.lamp_warmth(Vector3.ZERO, Vector3.UP, Vector3(0, 9, 0), 6.0, true), 0.0)


func test_vertex_key_merges_same_spot_and_splits_normals() -> void:
	var k1: int = VertexAo.key(Vector3(1, 2, 3), Vector3.UP)
	assert_eq(k1, VertexAo.key(Vector3(1.001, 2.0, 3.0), Vector3.UP))
	assert_ne(k1, VertexAo.key(Vector3(1, 2, 3), Vector3.RIGHT))
