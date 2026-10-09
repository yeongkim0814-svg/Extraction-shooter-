extends GutTest
## 부품 라이브러리 (KitCatalog) 전수 검사: 모든 부품이 만들어지고, 삼각형 예산·표식·루팅 메타를 지키는지.

const LOOT_PIECES: Array[StringName] = [&"crate_wood", &"crate_military", &"locker_steel", &"drawer_cabinet"]
const CATEGORIES: Array[StringName] = [KitCatalog.BUILDING, KitCatalog.LARGE, KitCatalog.PROP, KitCatalog.DRESSING]


func _budget(category: StringName) -> int:
	match category:
		KitCatalog.BUILDING:
			return 2000
		KitCatalog.LARGE:
			return 4000
		_:
			return 1500


func _marker_names(root: Node3D) -> Array[String]:
	var out: Array[String] = []
	for child: Node in root.get_children():
		if child is Marker3D:
			out.append(String(child.name))
	return out


func test_catalog_not_empty() -> void:
	assert_gte(KitCatalog.names().size(), 45)


func test_every_piece_builds_within_budget() -> void:
	for piece: StringName in KitCatalog.names():
		var kb: KitBuild = KitCatalog.build(piece)
		assert_not_null(kb, "build 실패: %s" % piece)
		if kb == null:
			continue
		var category: StringName = KitCatalog.category_of(piece)
		assert_true(CATEGORIES.has(category), "분류 이상: %s" % piece)
		assert_gt(kb.triangle_count(), 0, "삼각형 없음: %s" % piece)
		assert_lte(kb.triangle_count(), _budget(category), "예산 초과: %s (%d)" % [piece, kb.triangle_count()])
		var root: Node3D = kb.finish()
		var mi := root.get_node_or_null("Mesh") as MeshInstance3D
		assert_not_null(mi, "Mesh 노드 없음: %s" % piece)
		if mi != null:
			assert_not_null(mi.mesh, "메시 없음: %s" % piece)
		root.free()


func test_loot_pieces_have_marker_and_meta() -> void:
	for piece: StringName in LOOT_PIECES:
		var kb: KitBuild = KitCatalog.build(piece)
		var root: Node3D = kb.finish()
		assert_true(_marker_names(root).has("LOOT"), "LOOT 표식 없음: %s" % piece)
		assert_true(root.has_meta("loot_kind"), "loot_kind 없음: %s" % piece)
		root.free()


func test_wall_modules_have_snap_markers() -> void:
	for piece: StringName in KitCatalog.names():
		if not String(piece).begins_with("wall_"):
			continue
		var kb: KitBuild = KitCatalog.build(piece)
		var root: Node3D = kb.finish()
		var names: Array[String] = _marker_names(root)
		assert_true(names.has("SNAP_L") and names.has("SNAP_R"), "SNAP 표식 없음: %s" % piece)
		root.free()


func test_lamps_have_light_marker() -> void:
	var count: int = 0
	for piece: StringName in KitCatalog.names():
		if not String(piece).begins_with("lamp_"):
			continue
		count += 1
		var kb: KitBuild = KitCatalog.build(piece)
		var root: Node3D = kb.finish()
		var found: bool = false
		for n: String in _marker_names(root):
			if n.begins_with("LIGHT_"):
				found = true
		assert_true(found, "LIGHT_ 표식 없음: %s" % piece)
		root.free()
	assert_eq(count, 4)


func test_build_is_deterministic() -> void:
	for piece: StringName in [&"rubble_large", &"debris_planks", &"puddle_2m", &"wall_4m_damaged"]:
		var a: KitBuild = KitCatalog.build(piece)
		var b: KitBuild = KitCatalog.build(piece)
		assert_eq(a.triangle_count(), b.triangle_count())
		assert_eq(a.mesh.build().get_aabb(), b.mesh.build().get_aabb(), "비결정: %s" % piece)
