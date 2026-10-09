extends SceneTree
## 구역 씬 굽기 (ART.md 11.6·11.7): ZoneCatalog의 구역마다 scenes/raid/zones/<구역>.tscn을 만든다.
##   1) 구역 정의가 ZoneBuilder에 부품·맞춤 지오메트리·바닥·빛을 넣는다.
##   2) 부품·맞춤 메시를 CELL_M 칸별로 SurfaceTool에 합친다 (재질별 표면). 바닥은 칸 크기로 잘라 같은 칸에 넣는다.
##   3) 칸 메시마다 lightmap_unwrap으로 UV2를 넣고 <구역>/cell_<x>_<z>.res로 저장한다 (GI 모드 STATIC).
##   4) 충돌 상자는 StaticBody3D "Body" 하나에, 빛은 "Lights" 아래 OmniLight3D로, 라이트맵 굽기 노드 "LightmapGI"를 하나 둔다
##      (태블릿에서 이 씬을 열고 굽는다: 프로브 끔, 품질 Low, 바운스 2).
## 사용법: godot --headless --path . --script tools/build_zones.gd [-- --only=factory_hall]
## 로그 접두사 "ZONE: ". 실패하면 종료 코드 1.

const OUT_DIR: String = "res://scenes/raid/zones"
const CELL_M: float = 16.0
const TEXEL_SIZE: float = 0.25
const MAX_TEXTURE_SIZE: int = 2048
## 라이트맵 힌트가 이보다 크면 경고 (태블릿 굽기 메모리).
const HINT_WARN: int = 1024


func _initialize() -> void:
	var only: PackedStringArray = PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.substr("--only=".length()).split(",", false)
	var failed: int = 0
	for zone: StringName in ZoneCatalog.names():
		if not only.is_empty() and not only.has(String(zone)):
			continue
		if not _bake(zone):
			failed += 1
	print("ZONE: done failed=%d" % failed)
	quit(1 if failed > 0 else 0)


func _bake(zone: StringName) -> bool:
	var zb := ZoneBuilder.new(zone)
	if not ZoneCatalog.build(zone, zb):
		print("ZONE: FAIL %s (정의 없음)" % zone)
		return false
	_cell_m = zb.cell_m
	var dir: String = "%s/%s" % [OUT_DIR, zone]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_clear_dir(dir)
	# 칸 키 -> SurfaceTool 목록 (재질별)
	var cells: Dictionary[Vector2i, Dictionary] = {}
	var mesh_cache: Dictionary[StringName, ArrayMesh] = {}
	var body := StaticBody3D.new()
	body.name = "Body"
	var shape_count: int = 0
	var tris: int = 0
	for rec: Array in zb.pieces:
		var piece: StringName = rec[0]
		var xform: Transform3D = rec[1]
		var kb: KitBuild = zb.kit(piece)
		if kb == null:
			continue
		if not mesh_cache.has(piece):
			mesh_cache[piece] = kb.mesh.build()
		_add_mesh(cells, mesh_cache[piece], xform)
		tris += kb.triangle_count()
		shape_count += _add_shapes(body, kb, xform)
	for custom_name: String in zb.customs:
		var kb: KitBuild = zb.customs[custom_name]
		var m: ArrayMesh = kb.mesh.build()
		_add_split(cells, m)
		tris += kb.triangle_count()
		shape_count += _add_shapes(body, kb, Transform3D.IDENTITY)
	for rec: Array in zb.grounds:
		_add_split(cells, zb.ground_mesh(rec))
	var root := Node3D.new()
	root.name = "Zone" + String(zone).to_pascal_case()
	var cell_count: int = 0
	var over: int = 0
	var cell_tris: int = 0
	for key: Vector2i in cells:
		var mesh := ArrayMesh.new()
		var per_mat: Dictionary = cells[key]
		for mat: Material in per_mat:
			var st: SurfaceTool = per_mat[mat]
			st.generate_tangents()
			st.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
		var pre_tris: int = 0
		for si: int in range(mesh.get_surface_count()):
			pre_tris += int((mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3)
		if mesh.lightmap_unwrap(Transform3D.IDENTITY, TEXEL_SIZE) != OK:
			push_warning("ZONE: lightmap_unwrap 실패 %s %s" % [zone, key])
		var post_tris: int = 0
		for si: int in range(mesh.get_surface_count()):
			post_tris += int((mesh.surface_get_arrays(si)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3)
		cell_tris += post_tris
		if post_tris < pre_tris:
			print("ZONE:   칸 %s 언랩이 삼각형을 잃음 %d -> %d" % [key, pre_tris, post_tris])
		var hint: Vector2i = mesh.get_lightmap_size_hint()
		if hint.x > HINT_WARN or hint.y > HINT_WARN:
			over += 1
			print("ZONE:   칸 %s 라이트맵 힌트 %dx%d 큼" % [key, hint.x, hint.y])
		var path: String = "%s/cell_%d_%d.res" % [dir, key.x, key.y]
		if ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS) != OK:
			print("ZONE: FAIL %s (메시 저장 %s)" % [zone, path])
			return false
		mesh.take_over_path(path)
		var mi := MeshInstance3D.new()
		mi.name = "Cell_%d_%d" % [key.x + 1000, key.y + 1000]
		mi.mesh = mesh
		mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		if not zb.cast_shadows:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		cell_count += 1
	root.add_child(body)
	var lights_root := Node3D.new()
	lights_root.name = "Lights"
	root.add_child(lights_root)
	for rec: Array in zb.lights:
		lights_root.add_child(zb.make_light(rec[0], rec[1], rec[2]))
	var gi := LightmapGI.new()
	gi.name = "LightmapGI"
	gi.quality = LightmapGI.BAKE_QUALITY_LOW
	gi.bounces = 2
	gi.use_denoiser = true
	gi.max_texture_size = MAX_TEXTURE_SIZE
	gi.generate_probes_subdiv = LightmapGI.GENERATE_PROBES_DISABLED
	gi.environment_mode = LightmapGI.ENVIRONMENT_MODE_SCENE
	root.add_child(gi)
	_own(root, root)
	var packed := PackedScene.new()
	var scene_path: String = "%s/%s.tscn" % [OUT_DIR, zone]
	if packed.pack(root) != OK or ResourceSaver.save(packed, scene_path) != OK:
		print("ZONE: FAIL %s (씬 저장)" % zone)
		root.free()
		return false
	root.free()
	print("ZONE: %s pieces=%d customs=%d cells=%d shapes=%d lights=%d tris=%d (칸 메시 합 %d) big_hints=%d" % [
		zone, zb.pieces.size(), zb.customs.size(), cell_count, shape_count, zb.lights.size(), tris, cell_tris, over])
	return true


## 지금 굽는 구역의 칸 크기 (ZoneBuilder.cell_m).
var _cell_m: float = CELL_M


func _cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / _cell_m), floori(p.z / _cell_m))


func _tool_for(cells: Dictionary[Vector2i, Dictionary], key: Vector2i, mat: Material) -> SurfaceTool:
	if not cells.has(key):
		cells[key] = {}
	var per_mat: Dictionary = cells[key]
	if not per_mat.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		per_mat[mat] = st
	return per_mat[mat]


## 부품 메시 전체를 부품 중심이 속한 칸 하나에 넣는다 (부품을 쪼개지 않는다).
func _add_mesh(cells: Dictionary[Vector2i, Dictionary], mesh_in: ArrayMesh, xform: Transform3D) -> void:
	var mesh: ArrayMesh = _indexed(mesh_in)
	var key: Vector2i = _cell_of(xform * mesh.get_aabb().get_center())
	for s: int in range(mesh.get_surface_count()):
		_tool_for(cells, key, mesh.surface_get_material(s)).append_from(mesh, s, xform)


## 모든 표면에 인덱스 배열을 보장한 사본. SurfaceTool.append_from은 인덱스 있는 메시와 없는 메시를 섞어 합치면
## 인덱스 없는 쪽 삼각형을 조용히 잃는다 (인덱스 배열이 있는 쪽만 참조됨) -> 합치기 전에 모두 인덱스 메시로 맞춘다.
static func _indexed(mesh: ArrayMesh) -> ArrayMesh:
	var all_indexed: bool = true
	for s: int in range(mesh.get_surface_count()):
		if mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] == null:
			all_indexed = false
	if all_indexed:
		return mesh
	var out := ArrayMesh.new()
	for s: int in range(mesh.get_surface_count()):
		var st := SurfaceTool.new()
		st.create_from(mesh, s)
		st.index()
		st.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, mesh.surface_get_material(s))
	return out


## 큰 메시(바닥·맞춤 지오메트리)는 MeshChunker로 칸마다 잘라 넣는다.
func _add_split(cells: Dictionary[Vector2i, Dictionary], mesh: ArrayMesh) -> void:
	for part: ArrayMesh in MeshChunker.split_mesh(mesh, _cell_m):
		_add_mesh(cells, part, Transform3D.IDENTITY)


static func _add_shapes(body: StaticBody3D, kb: KitBuild, xform: Transform3D) -> int:
	for rec: Array in kb.collision:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = rec[1] as Vector3
		cs.shape = shape
		cs.transform = xform * (rec[0] as Transform3D)
		body.add_child(cs)
	return kb.collision.size()


static func _own(node: Node, owner_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner_node
		_own(child, owner_node)


static func _clear_dir(dir: String) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		return
	for f: String in da.get_files():
		if f.ends_with(".res"):
			da.remove(f)
