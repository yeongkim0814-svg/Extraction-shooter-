extends SceneTree
## scenes/dev/platform_test.tscn을 생성한다 (헤드리스: godot --headless -s tools/build_platform_scene.gd).
## 도형을 코드가 아니라 씬 노드로 두어야 편집기 라이트맵 굽기 대상이 된다.
## 모든 메시: UV2 추가(add_uv2) + GI 모드 정적(GI_MODE_STATIC). 라이트맵 노드를 씬에 포함한다.

const OUT_PATH := "res://scenes/dev/platform_test.tscn"
const SCRIPT_PATH := "res://scripts/game/dev/platform_test.gd"


func _init() -> void:
	var root := Node3D.new()
	root.name = "PlatformTest"
	root.set_script(load(SCRIPT_PATH))

	var lightmap := LightmapGI.new()
	lightmap.name = "LightmapGI"
	root.add_child(lightmap)
	lightmap.owner = root

	var ground := _mesh_node(root, "Ground", PlaneMesh.new(), _mat(Color(0.3, 0.3, 0.29), 0.95, 0.0), Vector3.ZERO)
	(ground.mesh as PlaneMesh).size = Vector2(60.0, 60.0)

	var concrete := _mat(Color(0.6, 0.6, 0.58), 0.9, 0.0)
	var steel := _mat(Color(0.8, 0.82, 0.85), 0.25, 1.0)
	var rust := _mat(Color(0.55, 0.3, 0.18), 0.7, 0.6)
	var glow := _mat(Color(0.2, 0.9, 1.0), 0.4, 0.0, true)

	var box := BoxMesh.new()
	box.size = Vector3(2.0, 2.0, 2.0)
	_mesh_node(root, "CrateConcrete", box, concrete, Vector3(-3.0, 1.0, -1.0))
	var tall := BoxMesh.new()
	tall.size = Vector3(1.5, 4.0, 1.5)
	_mesh_node(root, "PillarConcrete", tall, concrete, Vector3(3.5, 2.0, -2.5))
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.8
	cyl.bottom_radius = 0.8
	cyl.height = 2.5
	_mesh_node(root, "DrumSteel", cyl, steel, Vector3(0.0, 1.25, 2.5))
	_mesh_node(root, "DrumRust", cyl.duplicate(), rust, Vector3(-4.0, 1.25, 3.0))
	var box2 := box.duplicate() as BoxMesh
	_mesh_node(root, "CrateSteel", box2, steel, Vector3(2.5, 1.0, 3.5))
	_mesh_node(root, "DrumGlow", cyl.duplicate(), glow, Vector3(0.0, 1.25, -3.0))

	var packed := PackedScene.new()
	var err: int = packed.pack(root)
	if err != OK:
		push_error("pack failed: %d" % err)
		quit(1)
		return
	err = ResourceSaver.save(packed, OUT_PATH)
	if err != OK:
		push_error("save failed: %d" % err)
		quit(1)
		return
	print("WROTE " + OUT_PATH)
	quit(0)


func _mat(color: Color, rough: float, metal: float, emissive: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emissive:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 2.0
	return m


func _mesh_node(parent: Node3D, node_name: String, mesh: PrimitiveMesh, mat: Material,
		pos: Vector3) -> MeshInstance3D:
	mesh.add_uv2 = true
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	parent.add_child(mi)
	mi.owner = parent
	return mi
