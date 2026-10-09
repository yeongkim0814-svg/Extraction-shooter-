extends SceneTree
## 부품 라이브러리 굽기 (ART.md 11.5): KitCatalog의 모든 부품을 scenes/kit/<분류>/<이름>.tscn으로 저장한다.
##   1) KitBuild로 도형·충돌·표식을 만든다.
##   2) 메시에 lightmap_unwrap으로 UV2를 넣는다 (라이트맵 굽기 대상, GI 모드 STATIC).
##   3) 삼각형이 LOD_MIN_TRIS 이상이면 ImporterMesh로 LOD를 만든다 (UV2를 만든 뒤라 UV2가 보존된다).
##   4) 메시는 <이름>_mesh.res, 씬은 <이름>.tscn. 목록·통계는 scenes/kit/kit_index.json.
## 사용법: godot --headless --path . --script tools/build_kit.gd [-- --only=wall_4m,barrel]
## 로그 접두사 "KIT: ". 실패한 부품이 있으면 종료 코드 1.

const OUT_DIR: String = "res://scenes/kit"
## 라이트맵 텍셀 크기 (m). 부품은 작아서 맵 굽기보다 촘촘하게 (텍스처 한도는 구역 단위로 관리).
const TEXEL_SIZE: float = 0.2
const LOD_MIN_TRIS: int = 600


func _initialize() -> void:
	var only: PackedStringArray = PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.substr("--only=".length()).split(",", false)
	var index: Dictionary = {}
	var failed: int = 0
	for piece: StringName in KitCatalog.names():
		if not only.is_empty() and not only.has(String(piece)):
			continue
		var rec: Dictionary = _bake(piece)
		if rec.is_empty():
			failed += 1
		else:
			index[String(piece)] = rec
	if only.is_empty():
		var f := FileAccess.open(OUT_DIR + "/kit_index.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(index, " ", true))
		f.close()
	print("KIT: done pieces=%d failed=%d" % [index.size(), failed])
	quit(1 if failed > 0 else 0)


func _bake(piece: StringName) -> Dictionary:
	var kb: KitBuild = KitCatalog.build(piece)
	if kb == null:
		print("KIT: FAIL %s (정의 없음)" % piece)
		return {}
	var category: String = String(KitCatalog.category_of(piece))
	var dir: String = "%s/%s" % [OUT_DIR, category]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var mesh: ArrayMesh = kb.mesh.build()
	var tris: int = kb.triangle_count()
	var uv2_ok: bool = mesh.lightmap_unwrap(Transform3D.IDENTITY, TEXEL_SIZE) == OK
	if not uv2_ok:
		push_warning("KIT: lightmap_unwrap 실패: %s" % piece)
	var lods: int = 0
	if tris >= LOD_MIN_TRIS:
		var lod_mesh: ArrayMesh = _with_lods(mesh)
		if lod_mesh != null:
			mesh = lod_mesh
			lods = 1
	var mesh_path: String = "%s/%s_mesh.res" % [dir, piece]
	if ResourceSaver.save(mesh, mesh_path, ResourceSaver.FLAG_COMPRESS) != OK:
		print("KIT: FAIL %s (메시 저장)" % piece)
		return {}
	mesh.take_over_path(mesh_path)
	var root: Node3D = kb.finish(mesh)
	_own(root, root)
	var packed := PackedScene.new()
	if packed.pack(root) != OK or ResourceSaver.save(packed, "%s/%s.tscn" % [dir, piece]) != OK:
		print("KIT: FAIL %s (씬 저장)" % piece)
		root.free()
		return {}
	var aabb: AABB = mesh.get_aabb()
	var marker_names: Array[String] = []
	for m: Array in kb.markers:
		marker_names.append(String(m[0]))
	root.free()
	var hint: Vector2i = mesh.get_lightmap_size_hint()
	print("KIT: %-16s %-9s tris=%5d surfaces=%d shapes=%d uv2=%s lod=%d lm=%dx%d size=(%.2f,%.2f,%.2f)" % [
		piece, category, tris, mesh.get_surface_count(), kb.collision.size(), "ok" if uv2_ok else "FAIL", lods,
		hint.x, hint.y, aabb.size.x, aabb.size.y, aabb.size.z])
	return {"category": category, "tris": tris, "surfaces": mesh.get_surface_count(), "shapes": kb.collision.size(),
		"uv2": uv2_ok, "lod": lods > 0, "size": [snappedf(aabb.size.x, 0.01), snappedf(aabb.size.y, 0.01), snappedf(aabb.size.z, 0.01)],
		"markers": marker_names}


## ImporterMesh로 LOD를 만든다. 실패하면 null (원본을 쓴다).
func _with_lods(mesh: ArrayMesh) -> ArrayMesh:
	var im := ImporterMesh.new()
	for s: int in range(mesh.get_surface_count()):
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(s), [], {}, mesh.surface_get_material(s))
	im.generate_lods(25.0, 60.0, [])
	var out: ArrayMesh = im.get_mesh()
	if out == null or out.get_surface_count() != mesh.get_surface_count():
		return null
	out.lightmap_size_hint = mesh.lightmap_size_hint
	return out


func _own(node: Node, owner_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner_node
		_own(child, owner_node)
