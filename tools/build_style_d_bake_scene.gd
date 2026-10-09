extends SceneTree
## 스타일 D를 라이트맵으로 굽기 위한 씬을 만든다 (헤드리스):
##   godot --headless --path . --script tools/build_style_d_bake_scene.gd
## 1) 스타일 D 비네트를 정점 베이크 없이 만든다 (StyleCompare.bake_scene_mode).
## 2) 정적 메시마다 ArrayMesh.lightmap_unwrap으로 UV2를 만들고 GI 모드를 STATIC으로 한다 (먼 배경·빛줄기·식물은 끔).
##    unwrap이 헤드리스에서 실패하면 그 메시는 UV2 없이 저장하고 경고를 남긴다 (에디터 Mesh 메뉴 > Unwrap UV2 for Lightmap으로 대체).
##    수평 범위가 SPLIT_EXTENT_M를 넘는 메시는 MeshChunker로 CELL_M 칸마다 `<이름>_c<번호>` 덩어리로 쪼갠다 (차트·힌트를 작게 유지).
##    힌트 = ArrayMesh.get_lightmap_size_hint(): 이것이 LightmapGI.max_texture_size보다 크면 "최대 텍스처 크기가 작다" 경고가 난다.
## 3) LightmapGI를 붙인다: interior 끔(마당), 품질 중간, 최대 텍스처 2048(모바일), 디노이저 켬, 프로브 자동 생성.
##    조명: 태양 = 간접광만 굽고 직접광은 실시간(BAKE_DYNAMIC), 램프 = 정적.
## 4) 메시는 scenes/dev/style_d_bake/*.res(압축 바이너리)로 따로 저장하고 씬은 그것을 참조한다 -> scenes/dev/style_d_bake.tscn.
## 사용자는 이 씬을 태블릿 에디터에서 열어 LightmapGI를 선택하고 "Bake Lightmaps"를 누른다.

const SCENE_OUT: String = "res://scenes/dev/style_d_bake.tscn"
const MESH_DIR: String = "res://scenes/dev/style_d_bake"
const SOURCE_SCENE: String = "res://scenes/dev/style_compare.tscn"
const MAX_TEXTURE_SIZE: int = 2048
const TEXEL_SIZE: float = 0.25
## 이 수평 범위(m)를 넘는 정적 메시는 쪼갠다. 칸(CELL_M)의 3배 안쪽이면 한 덩어리로도 차트가 충분히 작다.
const SPLIT_EXTENT_M: float = 12.0
const CELL_M: float = 8.0
## 덩어리 하나의 힌트가 이 값(텍셀)을 넘으면 경고한다. 최대 텍스처(2048)의 1/4이면 여러 덩어리가 한 장에 여유 있게 패킹된다.
const HINT_WARN: int = 512
const NO_GI_GROUPS: Array[String] = ["Skyline", "Shaft", "Glow", "Weeds", "Puddle", "Ivy", "FarGround"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	StyleCompare.bake_scene_mode = true
	StyleCompare.forced_style = StyleCompare.Style.D
	var source: Node = (load(SOURCE_SCENE) as PackedScene).instantiate()
	root.add_child(source)
	for _i: int in range(6):
		await process_frame
	var out := Node3D.new()
	out.name = "StyleDBake"
	var meshes: int = 0
	var unwrapped: int = 0
	var failed: int = 0
	var over_limit: int = 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MESH_DIR))
	_clear_old_meshes()
	var keep: Array[Node] = []
	for child: Node in source.get_children():
		keep.append(child)
	for child: Node in keep:
		source.remove_child(child)
		if child is Camera3D:
			var cam := Camera3D.new()
			cam.name = "Camera"
			cam.set_script(load("res://scripts/game/dev/style_shot_camera.gd"))
			out.add_child(cam)
			child.free()
			continue
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var no_gi: bool = _is_no_gi(String(mi.name))
			var am: ArrayMesh = mi.mesh as ArrayMesh
			var ext: Vector3 = (mi.transform * am.get_aabb()).size
			var parts: Array[MeshInstance3D] = []
			if not no_gi and maxf(ext.x, ext.z) > SPLIT_EXTENT_M:
				var chunks: Array[ArrayMesh] = MeshChunker.split_mesh(am, CELL_M)
				for i: int in range(chunks.size()):
					var part := mi.duplicate() as MeshInstance3D
					part.name = "%s_c%d" % [mi.name, i]
					part.mesh = chunks[i]
					parts.append(part)
				print("SPLIT: %s ext=(%.1f,%.1f) -> %d 덩어리" % [mi.name, ext.x, ext.z, chunks.size()])
				child.free()
			else:
				parts.append(mi)
			for part: MeshInstance3D in parts:
				out.add_child(part)
				meshes += 1
				var pm: ArrayMesh = part.mesh as ArrayMesh
				if no_gi:
					part.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
				else:
					part.gi_mode = GeometryInstance3D.GI_MODE_STATIC
					var err: Error = pm.lightmap_unwrap(Transform3D.IDENTITY, TEXEL_SIZE)
					if err == OK:
						unwrapped += 1
					else:
						failed += 1
						push_warning("lightmap_unwrap 실패: %s (%s)" % [part.name, error_string(err)])
					var bb: AABB = part.transform * pm.get_aabb()
					var hint: Vector2i = pm.get_lightmap_size_hint()
					var over: bool = hint.x > HINT_WARN or hint.y > HINT_WARN or hint.x > MAX_TEXTURE_SIZE or hint.y > MAX_TEXTURE_SIZE
					if over:
						over_limit += 1
					print("CHUNK: %-16s size=(%.1f,%.1f,%.1f) area=%.1f hint=%dx%d%s" % [part.name, bb.size.x, bb.size.y, bb.size.z,
							MeshChunker.surface_area(pm), hint.x, hint.y, "  <-- 한도 초과" if over else ""])
				var path: String = "%s/%s.res" % [MESH_DIR, String(part.name).to_lower()]
				ResourceSaver.save(pm, path, ResourceSaver.FLAG_COMPRESS)
				pm.take_over_path(path)
		else:
			out.add_child(child)
	source.free()
	var gi := LightmapGI.new()
	gi.name = "LightmapGI"
	gi.quality = LightmapGI.BAKE_QUALITY_MEDIUM
	gi.bounces = 3
	gi.interior = false
	gi.use_denoiser = true
	gi.max_texture_size = MAX_TEXTURE_SIZE
	gi.generate_probes_subdiv = LightmapGI.GENERATE_PROBES_SUBDIV_8
	gi.environment_mode = LightmapGI.ENVIRONMENT_MODE_SCENE
	out.add_child(gi)
	_set_owner(out, out)
	var packed := PackedScene.new()
	var pack_err: Error = packed.pack(out)
	var save_err: Error = ERR_CANT_CREATE
	if pack_err == OK:
		save_err = ResourceSaver.save(packed, SCENE_OUT)
	print("BAKE_SCENE: meshes=%d unwrapped=%d failed=%d pack=%s save=%s path=%s" % [
			meshes, unwrapped, failed, error_string(pack_err), error_string(save_err), SCENE_OUT])
	print("BAKE_LIMIT: over_limit=%d (힌트 > %d 텍셀)" % [over_limit, HINT_WARN])
	out.free()
	quit(0 if save_err == OK and failed == 0 else 1)


## NO_GI_GROUPS에 속하는지 (대소문자 무시: 씬 노드 이름은 "FarGround"처럼 대문자가 섞여 있다).
func _is_no_gi(node_name: String) -> bool:
	for g: String in NO_GI_GROUPS:
		if g.to_lower() == node_name.to_lower():
			return true
	return false


## 이전 실행의 메시 파일을 지운다 (쪼갠 이름이 바뀌면 낡은 .res가 남지 않게).
func _clear_old_meshes() -> void:
	var dir := DirAccess.open(MESH_DIR)
	if dir == null:
		return
	for f: String in dir.get_files():
		if f.ends_with(".res"):
			dir.remove(f)


func _set_owner(node: Node, owner_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner_node
		_set_owner(child, owner_node)
