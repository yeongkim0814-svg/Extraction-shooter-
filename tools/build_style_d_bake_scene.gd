extends SceneTree
## 스타일 D를 라이트맵으로 굽기 위한 씬을 만든다 (헤드리스):
##   godot --headless --path . --script tools/build_style_d_bake_scene.gd
## 1) 스타일 D 비네트를 정점 베이크 없이 만든다 (StyleCompare.bake_scene_mode).
## 2) 정적 메시마다 ArrayMesh.lightmap_unwrap으로 UV2를 만들고 GI 모드를 STATIC으로 한다 (먼 배경·빛줄기·식물은 끔).
##    unwrap이 헤드리스에서 실패하면 그 메시는 UV2 없이 저장하고 경고를 남긴다 (에디터 Mesh 메뉴 > Unwrap UV2 for Lightmap으로 대체).
## 3) LightmapGI를 붙인다: interior 끔(마당), 품질 중간, 최대 텍스처 2048(모바일), 디노이저 켬, 프로브 자동 생성.
##    조명: 태양 = 간접광만 굽고 직접광은 실시간(BAKE_DYNAMIC), 램프 = 정적.
## 4) 메시는 scenes/dev/style_d_bake/*.res(압축 바이너리)로 따로 저장하고 씬은 그것을 참조한다 -> scenes/dev/style_d_bake.tscn.
## 사용자는 이 씬을 태블릿 에디터에서 열어 LightmapGI를 선택하고 "Bake Lightmaps"를 누른다.

const SCENE_OUT: String = "res://scenes/dev/style_d_bake.tscn"
const MESH_DIR: String = "res://scenes/dev/style_d_bake"
const SOURCE_SCENE: String = "res://scenes/dev/style_compare.tscn"
const TEXEL_SIZE: float = 0.25
const NO_GI_GROUPS: Array[String] = ["Skyline", "Shaft", "Glow", "Weeds", "Puddle", "Ivy", "Farground"]


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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MESH_DIR))
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
		out.add_child(child)
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			meshes += 1
			var am: ArrayMesh = mi.mesh as ArrayMesh
			if NO_GI_GROUPS.has(String(mi.name)):
				mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			else:
				mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
				var err: Error = am.lightmap_unwrap(Transform3D.IDENTITY, TEXEL_SIZE)
				if err == OK:
					unwrapped += 1
				else:
					failed += 1
					push_warning("lightmap_unwrap 실패: %s (%s)" % [mi.name, error_string(err)])
			var path: String = "%s/%s.res" % [MESH_DIR, String(mi.name).to_lower()]
			ResourceSaver.save(am, path, ResourceSaver.FLAG_COMPRESS)
			am.take_over_path(path)
	source.free()
	var gi := LightmapGI.new()
	gi.name = "LightmapGI"
	gi.quality = LightmapGI.BAKE_QUALITY_MEDIUM
	gi.bounces = 3
	gi.interior = false
	gi.use_denoiser = true
	gi.max_texture_size = 2048
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
	out.free()
	quit(0 if save_err == OK and failed == 0 else 1)


func _set_owner(node: Node, owner_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner_node
		_set_owner(child, owner_node)
