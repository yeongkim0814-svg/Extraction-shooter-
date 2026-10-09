extends GutTest
## WeaponAssembler / WeaponLook (M7): 부품 트리 → 소켓 Marker3D가 있는 노드 트리.

var _content: ContentDatabase


func before_each() -> void:
	_content = ContentDatabase.new()
	DemoWeapons.register(_content)


func _rifle() -> WeaponAssembly:
	return DemoWeapons.assemble(_content, &"rifle")


func _attach(assembly: WeaponAssembly, path: Array[StringName], socket: StringName, part_id: StringName) -> void:
	assert_eq(assembly.attach(path, socket, _content.get_part(part_id)), WeaponAssembly.OK)


func test_every_demo_part_has_a_look_table_entry() -> void:
	for id: StringName in [DemoWeapons.RIFLE_RECEIVER, DemoWeapons.SHOTGUN_RECEIVER, DemoWeapons.PISTOL_RECEIVER,
			DemoWeapons.BARREL_SHORT, DemoWeapons.BARREL_LONG, DemoWeapons.HANDGUARD, DemoWeapons.GRIP_VERTICAL,
			DemoWeapons.STOCK_FIXED, DemoWeapons.STOCK_FOLDING, DemoWeapons.MAG_30, DemoWeapons.RED_DOT,
			DemoWeapons.SCOPE_4X, DemoWeapons.SUPPRESSOR]:
		assert_true(WeaponLook.has_look(id), "외형 표에 %s가 있어야 함" % id)


func test_every_declared_socket_has_a_position_in_the_table() -> void:
	for part_id: StringName in [DemoWeapons.RIFLE_RECEIVER, DemoWeapons.SHOTGUN_RECEIVER, DemoWeapons.PISTOL_RECEIVER,
			DemoWeapons.BARREL_SHORT, DemoWeapons.BARREL_LONG, DemoWeapons.HANDGUARD]:
		var def: WeaponPartDef = _content.get_part(part_id)
		var look: WeaponLook.PartLook = WeaponLook.for_part(def)
		for socket: WeaponSocket in def.sockets:
			assert_true(look.sockets.has(socket.name), "%s 소켓 %s 위치" % [part_id, socket.name])


func test_unknown_part_falls_back_to_a_visible_box() -> void:
	var mystery := WeaponPartDef.create(&"mystery_part", &"whatever")
	var look: WeaponLook.PartLook = WeaponLook.for_part(mystery)
	assert_eq(look.pieces.size(), 1)


func test_build_creates_socket_markers_nested_like_the_part_tree() -> void:
	var assembly: WeaponAssembly = _rifle()
	var built: WeaponAssembler.Built = WeaponAssembler.build(assembly)
	add_child_autofree(built.root)
	for path: String in ["barrel", "barrel/muzzle", "handguard", "handguard/grip", "stock", "optic", "magazine"]:
		assert_true(built.sockets.has(path), "소켓 경로 %s" % path)
	var barrel_marker: Marker3D = built.sockets["barrel"]
	assert_eq(barrel_marker.name, &"SOCKET_barrel")
	var barrel_node: Node = barrel_marker.get_child(0)
	assert_eq(barrel_node.name, &"barrel_short", "자식 부품은 소켓 Marker3D의 자식")
	assert_not_null(barrel_node.get_node_or_null("SOCKET_muzzle"), "총열의 총구 소켓")


func test_attaching_a_part_adds_it_under_its_socket_and_changes_signature() -> void:
	var assembly: WeaponAssembly = _rifle()
	var before: String = WeaponAssembler.signature(assembly)
	_attach(assembly, [&"barrel"], &"muzzle", DemoWeapons.SUPPRESSOR)
	var after: String = WeaponAssembler.signature(assembly)
	assert_ne(before, after)
	var built: WeaponAssembler.Built = WeaponAssembler.build(assembly)
	add_child_autofree(built.root)
	var muzzle: Marker3D = built.sockets["barrel/muzzle"]
	assert_eq(muzzle.get_child_count(), 1)
	assert_eq(muzzle.get_child(0).name, &"suppressor")
	assert_eq(WeaponAssembler.signature(assembly), after, "같은 구성은 같은 키")


func test_muzzle_moves_forward_with_longer_barrel_and_suppressor() -> void:
	var short_gun: WeaponAssembly = _rifle()
	var short_built: WeaponAssembler.Built = WeaponAssembler.build(short_gun)
	add_child_autofree(short_built.root)
	var long_gun: WeaponAssembly = _rifle()
	long_gun.detach([], &"barrel")
	_attach(long_gun, [], &"barrel", DemoWeapons.BARREL_LONG)
	var long_built: WeaponAssembler.Built = WeaponAssembler.build(long_gun)
	add_child_autofree(long_built.root)
	assert_lt(long_built.muzzle.z, short_built.muzzle.z)
	_attach(long_gun, [&"barrel"], &"muzzle", DemoWeapons.SUPPRESSOR)
	var suppressed: WeaponAssembler.Built = WeaponAssembler.build(long_gun)
	add_child_autofree(suppressed.root)
	assert_lt(suppressed.muzzle.z, long_built.muzzle.z)


func test_optic_sets_sight_height_and_scope_hides_in_ads() -> void:
	var assembly: WeaponAssembly = _rifle()
	var with_dot: WeaponAssembler.Built = WeaponAssembler.build(assembly)
	add_child_autofree(with_dot.root)
	assert_gt(with_dot.sight_y, 0.07, "조준경이 있으면 레일 위로 조준선이 올라간다")
	assert_eq(with_dot.ads_hidden.size(), 0)
	assembly.detach([], &"optic")
	_attach(assembly, [], &"optic", DemoWeapons.SCOPE_4X)
	var with_scope: WeaponAssembler.Built = WeaponAssembler.build(assembly)
	add_child_autofree(with_scope.root)
	assert_eq(with_scope.ads_hidden.size(), 1)
	assembly.detach([], &"optic")
	var iron: WeaponAssembler.Built = WeaponAssembler.build(assembly)
	add_child_autofree(iron.root)
	assert_almost_eq(iron.sight_y, 0.07, 0.0001, "조준경이 없으면 리시버의 기본 조준선")


func test_weapon_is_much_smaller_than_the_old_box_gun() -> void:
	var built: WeaponAssembler.Built = WeaponAssembler.build(_rifle())
	add_child_autofree(built.root)
	assert_lt(built.bounds.size.x, 0.1, "폭")
	assert_lt(built.bounds.size.y, 0.25, "높이")
	assert_lt(built.bounds.size.z, 0.85, "길이")
	assert_gt(built.bounds.size.z, 0.4)


func test_pistol_and_shotgun_build_with_their_sockets() -> void:
	var pistol: WeaponAssembler.Built = WeaponAssembler.build(DemoWeapons.assemble(_content, &"pistol"))
	add_child_autofree(pistol.root)
	assert_true(pistol.sockets.has("muzzle") and pistol.sockets.has("optic"))
	var shotgun: WeaponAssembler.Built = WeaponAssembler.build(DemoWeapons.assemble(_content, &"shotgun"))
	add_child_autofree(shotgun.root)
	assert_true(shotgun.sockets.has("optic"))
	assert_eq(shotgun.sockets.size(), 1)


func test_materials_are_shared_per_color() -> void:
	var a: StandardMaterial3D = WeaponAssembler.material_for(WeaponLook.METAL, false)
	var b: StandardMaterial3D = WeaponAssembler.material_for(WeaponLook.METAL, false)
	var c: StandardMaterial3D = WeaponAssembler.material_for(WeaponLook.METAL, true)
	assert_same(a, b)
	assert_ne(a, c)


func test_scene_override_replaces_the_placeholder_and_uses_its_markers() -> void:
	# 부품 하나를 .glb 대신 임시 씬으로 대체: 소켓 위치는 씬 안 Marker3D가 정한다.
	var root := Node3D.new()
	root.name = "ShortBarrelModel"
	var marker := Marker3D.new()
	marker.name = "SOCKET_muzzle"
	root.add_child(marker)
	marker.owner = root
	marker.position = Vector3(0, 0, -0.5)
	var scene := PackedScene.new()
	assert_eq(scene.pack(root), OK)
	root.free()
	var path := "user://test_barrel_override.tscn"
	assert_eq(ResourceSaver.save(scene, path), OK)
	WeaponLook.scene_overrides[DemoWeapons.BARREL_SHORT] = path
	var assembly: WeaponAssembly = _rifle()
	_attach(assembly, [&"barrel"], &"muzzle", DemoWeapons.SUPPRESSOR)
	var built: WeaponAssembler.Built = WeaponAssembler.build(assembly)
	add_child_autofree(built.root)
	WeaponLook.scene_overrides.erase(DemoWeapons.BARREL_SHORT)
	DirAccess.remove_absolute(path)
	var barrel_marker: Marker3D = built.sockets["barrel"]
	assert_eq(barrel_marker.get_child(0).name, &"ShortBarrelModel", "플레이스홀더 대신 씬이 쓰임")
	assert_true(built.sockets.has("barrel/muzzle"))
	var found: Node = barrel_marker.get_child(0).get_node_or_null("SOCKET_muzzle")
	assert_not_null(found)
	assert_eq(found.get_child(0).name, &"suppressor", "자식 부품은 씬 안 소켓에 꽂힘")
	assert_almost_eq(built.muzzle.z, -0.2 - 0.5 - 0.17, 0.01, "총구 끝은 씬 안 소켓 위치 + 소음기 길이")
