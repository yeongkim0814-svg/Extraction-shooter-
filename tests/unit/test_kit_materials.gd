extends GutTest
## KitMaterials: 모든 ID가 재질을 돌려주고, 트림 ID가 KitLayout의 실제 줄을 가리키는지 확인한다.


func test_every_id_returns_material() -> void:
	for id: StringName in KitMaterials.all_ids():
		assert_not_null(KitMaterials.get_material(id), "재질 %s" % id)


func test_material_is_cached() -> void:
	assert_same(KitMaterials.get_material(KitMaterials.CONCRETE_WALL), KitMaterials.get_material(KitMaterials.CONCRETE_WALL))


func test_trim_ids_reference_existing_strips() -> void:
	assert_true(KitMaterials.trim_ids().size() >= 25)
	for id: StringName in KitMaterials.trim_ids():
		var sheet: int = KitMaterials.sheet_of(id)
		var strip: StringName = KitMaterials.strip_of(id)
		assert_true(KitLayout.has_strip(sheet, strip), "%s -> %d.%s" % [id, sheet, strip])
		var v: Vector2 = KitMaterials.v_range(id)
		assert_true(v.y > v.x, "%s v 범위" % id)


func test_non_trim_ids_have_no_strip() -> void:
	assert_eq(KitMaterials.sheet_of(KitMaterials.FLAT_CONCRETE), 0)
	assert_eq(KitMaterials.strip_of(KitMaterials.GROUND_ASPHALT), &"")
	assert_true(KitMaterials.is_ground(KitMaterials.GROUND_GRAVEL))
	assert_true(KitMaterials.is_flat(KitMaterials.FLAT_ROOF))


func test_unknown_id_does_not_crash() -> void:
	assert_not_null(KitMaterials.get_material(&"__nope__"))
