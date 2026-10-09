class_name IndustrialAtmosphere
extends RefCounted
## 맵 분위기 요소: 잡초 덤불(MultiMesh 교차 판), 굴뚝 연기, 반사 프로브(웅덩이·젖은 아스팔트용).
## 품질 단계는 graphics_quality.gd가 그룹(gfx_weeds / gfx_smoke / gfx_probe)을 통해 조절한다.

const WEED_GROUP: StringName = &"gfx_weeds"
const PROBE_GROUP: StringName = &"gfx_probe"
const WEED_BASE_COUNT: int = 900


static func build(m: IndustrialMap) -> void:
	_weeds(m)
	for point: Vector3 in m.smoke_points:
		var plume := SmokePlume.new()
		plume.name = "Smoke%d" % int(point.x)
		plume.position = point
		m.add_child(plume)
	_probes(m)


## 교차한 두 장의 판 (바닥 중심, 폭 1.2 x 높이 0.9).
static func _weed_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for plane: int in range(2):
		var dir: Vector3 = Vector3.RIGHT if plane == 0 else Vector3.BACK
		var base: int = verts.size()
		verts.append(-dir * 0.6)
		verts.append(dir * 0.6)
		verts.append(dir * 0.6 + Vector3(0, 0.9, 0))
		verts.append(-dir * 0.6 + Vector3(0, 0.9, 0))
		uvs.append_array(PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]))
		for i: int in range(4):
			normals.append(Vector3.UP)
		indices.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, IndustrialMaterials.get_material(IndustrialMaterials.WEED))
	return mesh


static func _weeds(m: IndustrialMap) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var spots: Array[Vector3] = []
	var lines: Array[Vector3] = m.weed_lines
	var pairs: int = lines.size() / 2
	for p: int in range(pairs):
		var a: Vector3 = lines[p * 2]
		var b: Vector3 = lines[p * 2 + 1]
		var length: float = a.distance_to(b)
		var n: int = int(length / 1.6)
		var along: Vector3 = (b - a).normalized()
		var side := Vector3(-along.z, 0.0, along.x)
		for i: int in range(n):
			var t: float = rng.randf() * length
			spots.append(a + along * t + side * rng.randf_range(-1.2, 1.2))
	while spots.size() < WEED_BASE_COUNT:
		spots.append(spots[rng.randi() % maxi(spots.size(), 1)] + Vector3(rng.randf_range(-1.5, 1.5), 0.0, rng.randf_range(-1.5, 1.5)))
	# 섞어서 앞쪽 일부만 보여 줘도 고르게 퍼지게 한다
	for i: int in range(spots.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var tmp: Vector3 = spots[i]
		spots[i] = spots[j]
		spots[j] = tmp
	var count: int = mini(spots.size(), WEED_BASE_COUNT)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = _weed_mesh()
	multi.instance_count = count
	var palette: Array[Color] = [Color(0.42, 0.5, 0.26), Color(0.5, 0.52, 0.28), Color(0.36, 0.44, 0.24),
			Color(0.55, 0.5, 0.3), Color(0.32, 0.4, 0.22)]
	for i: int in range(count):
		var s: float = rng.randf_range(0.7, 1.5)
		var yaw: float = rng.randf() * TAU
		var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(s, s * rng.randf_range(0.8, 1.4), s))
		multi.set_instance_transform(i, Transform3D(basis, Vector3(spots[i].x, 0.0, spots[i].z)))
		multi.set_instance_color(i, palette[rng.randi() % palette.size()])
	var node := MultiMeshInstance3D.new()
	node.name = "Weeds"
	node.multimesh = multi
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_to_group(WEED_GROUP)
	node.set_meta(&"base_count", count)
	m.add_child(node)
	m.mesh_instance_count += 1


static func _probes(m: IndustrialMap) -> void:
	var sky := ReflectionProbe.new()
	sky.name = "ProbeSite"
	sky.position = Vector3(0.0, 8.0, 0.0)
	sky.size = Vector3(IndustrialMap.HALF * 2.0 + 20.0, 34.0, IndustrialMap.HALF * 2.0 + 20.0)
	sky.update_mode = ReflectionProbe.UPDATE_ONCE
	sky.intensity = 1.0
	sky.max_distance = 0.0
	sky.add_to_group(PROBE_GROUP)
	m.add_child(sky)
	# 공장 홀 안: 어둡고 푸른 실내 주변광
	var hall := ReflectionProbe.new()
	hall.name = "ProbeHall"
	hall.position = Vector3(-18.0, 5.0, -62.0)
	hall.size = Vector3(52.0, 10.5, 28.0)
	hall.update_mode = ReflectionProbe.UPDATE_ONCE
	hall.interior = true
	hall.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	hall.ambient_color = Color(0.16, 0.18, 0.22)
	hall.ambient_color_energy = 0.8
	hall.intensity = 0.7
	hall.add_to_group(PROBE_GROUP)
	m.add_child(hall)
