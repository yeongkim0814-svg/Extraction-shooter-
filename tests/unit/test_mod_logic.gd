extends GutTest
## 모딩 화면의 순수 로직 (M7): 소켓 트리 목록·후보 필터와 사유·스탯 변화 규칙·미리보기.

const STASH := Inventory.STASH

var _auth: LocalAuthority
var _inv: Inventory
var _content: ContentDatabase
var _rifle: ItemInstance


func before_each() -> void:
	_inv = Inventory.new(Vector2i(10, 8))
	_auth = LocalAuthority.new(_inv)
	_content = ContentDatabase.new()
	DemoWeapons.register(_content)
	_auth.content = _content
	var def := ItemDef.create(&"rifle", 5, 2)
	def.display_name = "소총"
	def.category = ItemDef.Category.WEAPON
	_rifle = _auth.create_item(def)
	_rifle.weapon = DemoWeapons.assemble(_content, &"rifle")
	assert_true(_inv.add_item(_rifle, STASH, Vector2i.ZERO, false).ok)


func _spare(part_id: StringName, key: StringName, cell: Vector2i) -> ItemInstance:
	var item: ItemInstance = _auth.create_item(_content.get_item(part_id))
	assert_true(_inv.add_item(item, key, cell, false).ok, "부품 배치 %s" % part_id)
	return item


func _labels() -> Array[String]:
	var labels: Array[String] = []
	for row: ModTree.Row in ModTree.rows(_rifle.weapon, _content):
		labels.append(row.label)
	return labels


func _candidate_for(list: Array[ModCandidates.Candidate], part_id: StringName) -> ModCandidates.Candidate:
	for candidate: ModCandidates.Candidate in list:
		if candidate.part.id == part_id:
			return candidate
	return null


func _muzzle() -> Array[StringName]:
	return [&"barrel"]


# --- 소켓 트리 목록 ---

func test_tree_rows_are_depth_first_with_indented_labels() -> void:
	assert_eq(_labels(), [
		"총열: 숏 배럴",
		"  └ 총구: (비어 있음)",
		"핸드가드: 레일 핸드가드",
		"  └ 손잡이: (비어 있음)",
		"개머리판: 고정 개머리판",
		"조준경: 레드 도트",
		"탄창: 30발 탄창",
	] as Array[String])


func test_tree_rows_carry_paths_and_depth() -> void:
	var rows: Array[ModTree.Row] = ModTree.rows(_rifle.weapon, _content)
	assert_eq(rows[1].path_text(), "barrel/muzzle")
	assert_eq(rows[1].depth, 1)
	assert_eq(rows[1].parent_path, [&"barrel"] as Array[StringName])
	assert_true(rows[1].is_empty())
	assert_false(rows[0].is_empty())
	assert_eq(rows[0].path(), [&"barrel"] as Array[StringName])


func test_deeper_parts_indent_further() -> void:
	var sup: ItemInstance = _spare(DemoWeapons.SUPPRESSOR, STASH, Vector2i(0, 4))
	assert_true(_auth.execute(AttachPartCommand.new(_rifle.id, _muzzle(), &"muzzle", sup.id)).ok)
	assert_true(_labels().has("  └ 총구: 소음기"))
	var grip: ItemInstance = _spare(DemoWeapons.GRIP_VERTICAL, STASH, Vector2i(2, 4))
	assert_true(_auth.execute(AttachPartCommand.new(_rifle.id, [&"handguard"], &"grip", grip.id)).ok)
	assert_true(_labels().has("  └ 손잡이: 수직 손잡이"))


func test_required_empty_socket_is_flagged() -> void:
	assert_eq(ModTree.missing_required_text(_rifle.weapon), "")
	_rifle.weapon.detach([], &"barrel")
	assert_true(_labels().has("총열: (비어 있음)  (필수)"))
	assert_eq(ModTree.missing_required_text(_rifle.weapon), "총열")


func test_missing_nested_required_socket_names_the_leaf() -> void:
	var receiver := WeaponPartDef.create(&"r", &"receiver")
	receiver.sockets = [WeaponSocket.create(&"handguard", &"handguard")]
	var guard := WeaponPartDef.create(&"g", &"handguard")
	guard.sockets = [WeaponSocket.create(&"grip", &"grip", true)]
	var assembly := WeaponAssembly.new(receiver)
	assembly.attach([], &"handguard", guard)
	assert_eq(ModTree.missing_required_text(assembly), "손잡이")


# --- 후보 목록과 사유 ---

func test_candidates_list_every_part_item_and_explain_disabled_ones() -> void:
	_spare(DemoWeapons.SUPPRESSOR, STASH, Vector2i(0, 4))
	_spare(DemoWeapons.BARREL_LONG, STASH, Vector2i(2, 4))
	_spare(DemoWeapons.RED_DOT, STASH, Vector2i(5, 4))
	var list: Array[ModCandidates.Candidate] = ModCandidates.collect(_inv, _content, _rifle, _muzzle(), &"muzzle")
	assert_eq(list.size(), 3)
	assert_eq(list[0].part.id, DemoWeapons.SUPPRESSOR, "쓸 수 있는 것이 맨 앞")
	assert_true(list[0].enabled())
	var barrel: ModCandidates.Candidate = _candidate_for(list, DemoWeapons.BARREL_LONG)
	assert_false(barrel.enabled())
	assert_eq(barrel.error, WeaponAssembly.WRONG_PART_TYPE)
	assert_eq(barrel.reason, "종류 불일치")
	assert_eq(barrel.source, "스태시")


func test_non_part_items_are_not_candidates() -> void:
	var junk: ItemInstance = _auth.create_item(ItemDef.create(&"junk", 1, 1))
	_inv.add_item(junk, STASH, Vector2i(0, 4), false)
	assert_eq(ModCandidates.collect(_inv, _content, _rifle, [], &"optic").size(), 0)


func test_conflict_reason_names_the_blocking_part() -> void:
	_rifle.weapon.detach([], &"stock")
	var folding: ItemInstance = _spare(DemoWeapons.STOCK_FOLDING, STASH, Vector2i(0, 4))
	_spare(DemoWeapons.SCOPE_4X, STASH, Vector2i(3, 4))
	assert_true(_auth.execute(AttachPartCommand.new(_rifle.id, [], &"stock", folding.id)).ok)
	_rifle.weapon.detach([], &"optic")
	var list: Array[ModCandidates.Candidate] = ModCandidates.collect(_inv, _content, _rifle, [], &"optic")
	var scope: ModCandidates.Candidate = _candidate_for(list, DemoWeapons.SCOPE_4X)
	assert_eq(scope.error, WeaponAssembly.CONFLICT)
	assert_eq(scope.reason, "충돌: 접이식 개머리판")
	assert_false(scope.enabled())


func test_no_space_is_predicted_without_changing_anything() -> void:
	_spare(DemoWeapons.SUPPRESSOR, STASH, Vector2i(0, 4))
	var blocker: ItemInstance = _auth.create_item(ItemDef.create(&"box", 1, 1))
	_inv.add_item(blocker, STASH, Vector2i(5, 1), false)
	var list: Array[ModCandidates.Candidate] = ModCandidates.collect(_inv, _content, _rifle, _muzzle(), &"muzzle")
	assert_eq(list[0].error, CommandResult.NO_SPACE)
	assert_eq(list[0].reason, "공간 부족")
	assert_eq(_rifle.size(), Vector2i(5, 2), "미리 따져 보기만 한다")
	assert_true(_inv.is_consistent())
	# 실제로 해도 같은 결과
	var r: CommandResult = _auth.execute(AttachPartCommand.new(_rifle.id, _muzzle(), &"muzzle", list[0].item.id))
	assert_eq(r.error, CommandResult.NO_SPACE)


func test_part_lying_in_the_growth_area_does_not_block_itself() -> void:
	_spare(DemoWeapons.SUPPRESSOR, STASH, Vector2i(5, 0))
	var list: Array[ModCandidates.Candidate] = ModCandidates.collect(_inv, _content, _rifle, _muzzle(), &"muzzle")
	assert_true(list[0].enabled())


func test_equipped_weapon_never_lacks_space() -> void:
	_spare(DemoWeapons.SUPPRESSOR, STASH, Vector2i(0, 4))
	assert_true(_inv.equip(_rifle.id, EquipmentSlots.Slot.PRIMARY_1).ok)
	var blocker: ItemInstance = _auth.create_item(ItemDef.create(&"box", 1, 1))
	_inv.add_item(blocker, STASH, Vector2i(5, 0), false)
	var list: Array[ModCandidates.Candidate] = ModCandidates.collect(_inv, _content, _rifle, _muzzle(), &"muzzle")
	assert_true(list[0].enabled())


func test_candidates_come_from_reachable_containers_only() -> void:
	var pack_def := ItemDef.create(&"pack", 3, 3)
	pack_def.category = ItemDef.Category.BACKPACK
	pack_def.grids = [Vector2i(3, 3)]
	var rig_def := ItemDef.create(&"rig", 2, 2)
	rig_def.category = ItemDef.Category.RIG
	rig_def.grids = [Vector2i(2, 2)]
	var safe_def := ItemDef.create(&"safe", 2, 2)
	safe_def.category = ItemDef.Category.SECURE_CONTAINER
	safe_def.grids = [Vector2i(2, 2)]
	var pack: ItemInstance = _auth.create_item(pack_def)
	var rig: ItemInstance = _auth.create_item(rig_def)
	var safe: ItemInstance = _auth.create_item(safe_def)
	assert_true(_inv.add_equipped(pack, EquipmentSlots.Slot.BACKPACK).ok)
	assert_true(_inv.add_equipped(rig, EquipmentSlots.Slot.RIG).ok)
	assert_true(_inv.add_equipped(safe, EquipmentSlots.Slot.SECURE_CONTAINER).ok)
	var in_pack: ItemInstance = _spare(DemoWeapons.RED_DOT, Inventory.item_grid_key(pack.id, 0), Vector2i.ZERO)
	var in_rig: ItemInstance = _spare(DemoWeapons.RED_DOT, Inventory.item_grid_key(rig.id, 0), Vector2i.ZERO)
	var in_pocket: ItemInstance = _spare(DemoWeapons.RED_DOT, Inventory.pocket_key(1), Vector2i.ZERO)
	var in_safe: ItemInstance = _spare(DemoWeapons.RED_DOT, Inventory.item_grid_key(safe.id, 0), Vector2i.ZERO)
	var in_stash: ItemInstance = _spare(DemoWeapons.RED_DOT, STASH, Vector2i(0, 4))
	_rifle.weapon.detach([], &"optic")
	var list: Array[ModCandidates.Candidate] = ModCandidates.collect(_inv, _content, _rifle, [], &"optic")
	var found: Dictionary[int, String] = {}
	for candidate: ModCandidates.Candidate in list:
		found[candidate.item.id] = candidate.source
	assert_eq(found.get(in_pack.id), "배낭")
	assert_eq(found.get(in_rig.id), "조끼")
	assert_eq(found.get(in_pocket.id), "주머니")
	assert_eq(found.get(in_stash.id), "스태시")
	assert_false(found.has(in_safe.id), "보안 컨테이너 안은 제외")
	_inv.stash_locked = true
	list = ModCandidates.collect(_inv, _content, _rifle, [], &"optic")
	for candidate: ModCandidates.Candidate in list:
		assert_ne(candidate.item.id, in_stash.id, "잠긴 스태시는 제외")


func test_reason_texts_are_korean() -> void:
	assert_eq(ModCandidates.reason_text(WeaponAssembly.CONFLICT), "충돌")
	assert_eq(ModCandidates.reason_text(WeaponAssembly.WRONG_PART_TYPE), "종류 불일치")
	assert_eq(ModCandidates.reason_text(CommandResult.NO_SPACE), "공간 부족")
	assert_eq(ModCandidates.reason_text(&"something_else"), "something_else")


# --- 스탯 변화 규칙 ---

func _row(key: StringName) -> ModStats.Row:
	for row: ModStats.Row in ModStats.rows():
		if row.key == key:
			return row
	return null


func test_lower_is_better_for_recoil_spread_weight_loudness() -> void:
	for key: StringName in [WeaponStats.RECOIL, WeaponStats.SPREAD, WeaponStats.WEIGHT, WeaponStats.LOUDNESS]:
		var row: ModStats.Row = _row(key)
		assert_true(row.lower_is_better, String(key))
		assert_eq(ModStats.verdict(row, 10.0, 5.0), ModStats.Verdict.BETTER)
		assert_eq(ModStats.verdict(row, 5.0, 10.0), ModStats.Verdict.WORSE)
	for key: StringName in [WeaponStats.ERGONOMICS, WeaponStats.RANGE, WeaponMotion.ZOOM]:
		var row: ModStats.Row = _row(key)
		assert_false(row.lower_is_better, String(key))
		assert_eq(ModStats.verdict(row, 10.0, 15.0), ModStats.Verdict.BETTER)
		assert_eq(ModStats.verdict(row, 15.0, 10.0), ModStats.Verdict.WORSE)


func test_changes_smaller_than_the_displayed_precision_count_as_same() -> void:
	var weight: ModStats.Row = _row(WeaponStats.WEIGHT)   # 소수 2자리
	assert_eq(ModStats.verdict(weight, 3.0, 3.004), ModStats.Verdict.SAME)
	assert_eq(ModStats.verdict(weight, 3.0, 3.02), ModStats.Verdict.WORSE)
	assert_eq(ModStats.format_delta(weight, 3.0, 3.004), "")


func test_verdict_colors_green_red_neutral() -> void:
	assert_eq(ModStats.verdict_color(ModStats.Verdict.BETTER), ModStats.BETTER_COLOR)
	assert_eq(ModStats.verdict_color(ModStats.Verdict.WORSE), ModStats.WORSE_COLOR)
	assert_eq(ModStats.verdict_color(ModStats.Verdict.SAME), ModStats.SAME_COLOR)
	assert_gt(ModStats.BETTER_COLOR.g, ModStats.BETTER_COLOR.r)
	assert_gt(ModStats.WORSE_COLOR.r, ModStats.WORSE_COLOR.g)


func test_value_and_delta_formatting() -> void:
	assert_eq(ModStats.format_value(_row(WeaponStats.SPREAD), 1.2), "1.20°")
	assert_eq(ModStats.format_value(_row(WeaponStats.RANGE), 190.0), "190 m")
	assert_eq(ModStats.format_value(_row(WeaponMotion.ZOOM), 1.5), "2.5x", "배율은 1 + zoom")
	assert_eq(ModStats.format_delta(_row(WeaponStats.RECOIL), 30.0, 26.0), "−4.0")
	assert_eq(ModStats.format_delta(_row(WeaponStats.ERGONOMICS), 43.0, 46.0), "+3.0")


func test_part_summary_lists_effects_and_size() -> void:
	var sup: String = ModStats.part_summary(_content.get_part(DemoWeapons.SUPPRESSOR))
	assert_string_contains(sup, "소음 ×0.4")
	assert_string_contains(sup, "가로 +1칸")
	var fold: String = ModStats.part_summary(_content.get_part(DemoWeapons.STOCK_FOLDING))
	assert_string_contains(fold, "가로 −1칸")
	assert_string_contains(fold, "반동 −1")
	var plain := WeaponPartDef.create(&"plain", &"x")
	assert_eq(ModStats.part_summary(plain), "변화 없음")


func test_current_fills_missing_keys() -> void:
	var stats: Dictionary[StringName, float] = ModStats.current(_rifle.weapon)
	assert_eq(stats[WeaponMotion.ZOOM], 0.1, "레드 도트 zoom")
	var bare := WeaponPartDef.create(&"bare", &"receiver")
	var empty: Dictionary[StringName, float] = ModStats.current(WeaponAssembly.new(bare))
	assert_eq(empty[WeaponStats.LOUDNESS], 1.0)
	assert_eq(empty[WeaponStats.RECOIL], 0.0)


func test_preview_attach_shows_new_stats_and_leaves_the_weapon_untouched() -> void:
	var before_signature: String = WeaponAssembler.signature(_rifle.weapon)
	var before: Dictionary[StringName, float] = ModStats.current(_rifle.weapon)
	var preview: ModStats.Preview = ModStats.preview_attach(_rifle, _muzzle(), &"muzzle",
			_content.get_part(DemoWeapons.SUPPRESSOR))
	assert_eq(preview.error, &"")
	assert_almost_eq(preview.stats[WeaponStats.LOUDNESS], 0.4, 0.0001)
	assert_eq(preview.size, Vector2i(6, 2))
	assert_eq(WeaponAssembler.signature(_rifle.weapon), before_signature)
	assert_eq(ModStats.current(_rifle.weapon), before)
	assert_eq(_rifle.size(), Vector2i(5, 2))


func test_preview_attach_reports_the_error_code() -> void:
	var preview: ModStats.Preview = ModStats.preview_attach(_rifle, _muzzle(), &"muzzle",
			_content.get_part(DemoWeapons.BARREL_LONG))
	assert_eq(preview.error, WeaponAssembly.WRONG_PART_TYPE)


func test_preview_detach_shows_stats_without_the_part_and_restores() -> void:
	var before_signature: String = WeaponAssembler.signature(_rifle.weapon)
	var preview: ModStats.Preview = ModStats.preview_detach(_rifle, [], &"stock")
	assert_eq(preview.error, &"")
	var now: Dictionary[StringName, float] = ModStats.current(_rifle.weapon)
	assert_gt(preview.stats[WeaponStats.RECOIL], now[WeaponStats.RECOIL], "개머리판을 떼면 반동이 늘어난다")
	assert_lt(preview.stats[WeaponStats.ERGONOMICS], now[WeaponStats.ERGONOMICS])
	assert_eq(WeaponAssembler.signature(_rifle.weapon), before_signature)
	var guarded: ModStats.Preview = ModStats.preview_detach(_rifle, [], &"barrel")
	assert_eq(guarded.error, &"", "총구가 비어 있으면 총열은 뗄 수 있다")
	var sup: ItemInstance = _spare(DemoWeapons.SUPPRESSOR, STASH, Vector2i(0, 4))
	assert_true(_auth.execute(AttachPartCommand.new(_rifle.id, _muzzle(), &"muzzle", sup.id)).ok)
	assert_eq(ModStats.preview_detach(_rifle, [], &"barrel").error, CommandResult.HAS_ATTACHMENTS)
	assert_eq(ModStats.preview_detach(_rifle, [], &"nonexistent").error, WeaponAssembly.UNKNOWN_SOCKET)


# --- 데모 콘텐츠 정합성 ---

func test_demo_size_deltas_keep_the_rifle_at_least_one_cell() -> void:
	var assembly: WeaponAssembly = DemoWeapons.assemble(_content, &"rifle")
	assert_eq(assembly.compute_size(Vector2i(5, 2)), Vector2i(5, 2), "기본 부품은 크기 변화 없음")
	assembly.detach([], &"stock")
	assembly.attach([], &"stock", _content.get_part(DemoWeapons.STOCK_FOLDING))
	assert_eq(assembly.compute_size(Vector2i(5, 2)), Vector2i(4, 2))
	assembly.detach([], &"barrel")
	assembly.attach([], &"barrel", _content.get_part(DemoWeapons.BARREL_LONG))
	assembly.attach([&"barrel"], &"muzzle", _content.get_part(DemoWeapons.SUPPRESSOR))
	assert_eq(assembly.compute_size(Vector2i(5, 2)), Vector2i(6, 2))
	assert_eq(assembly.compute_size(Vector2i(1, 1)), Vector2i(2, 1), "접이식 −1, 긴 총열 +1, 소음기 +1 = +1")
	assembly.detach([&"barrel"], &"muzzle")
	assembly.detach([], &"barrel")
	assert_eq(assembly.compute_size(Vector2i(1, 1)), Vector2i(1, 1), "하한은 칸마다 1 (0이 되지 않음)")


func test_demo_part_effects_go_the_intended_way() -> void:
	var base: Dictionary[StringName, float] = DemoWeapons.assemble(_content, &"rifle").compute_stats()
	assert_almost_eq(base[WeaponStats.RECOIL], 30.0, 0.0001)
	var long_gun: WeaponAssembly = DemoWeapons.assemble(_content, &"rifle")
	long_gun.detach([], &"barrel")
	long_gun.attach([], &"barrel", _content.get_part(DemoWeapons.BARREL_LONG))
	var long_stats: Dictionary[StringName, float] = long_gun.compute_stats()
	assert_gt(long_stats[WeaponStats.RANGE], base[WeaponStats.RANGE])
	assert_lt(long_stats[WeaponStats.RECOIL], base[WeaponStats.RECOIL])
	var grip_gun: WeaponAssembly = DemoWeapons.assemble(_content, &"rifle")
	grip_gun.attach([&"handguard"], &"grip", _content.get_part(DemoWeapons.GRIP_VERTICAL))
	assert_lt(grip_gun.compute_stats()[WeaponStats.RECOIL], base[WeaponStats.RECOIL])
	var scope_gun: WeaponAssembly = DemoWeapons.assemble(_content, &"rifle")
	scope_gun.detach([], &"optic")
	scope_gun.attach([], &"optic", _content.get_part(DemoWeapons.SCOPE_4X))
	var scope_stats: Dictionary[StringName, float] = scope_gun.compute_stats()
	assert_gt(scope_stats[WeaponMotion.ZOOM], base[WeaponMotion.ZOOM])
	assert_lt(scope_stats[WeaponStats.ERGONOMICS], base[WeaponStats.ERGONOMICS])
	var quiet: WeaponAssembly = DemoWeapons.assemble(_content, &"rifle")
	quiet.attach([&"barrel"], &"muzzle", _content.get_part(DemoWeapons.SUPPRESSOR))
	assert_almost_eq(quiet.compute_stats()[WeaponStats.LOUDNESS], 0.4, 0.0001)


func test_pistol_and_shotgun_sockets() -> void:
	var pistol: WeaponAssembly = DemoWeapons.assemble(_content, &"pistol")
	assert_eq(pistol.attach([], &"muzzle", _content.get_part(DemoWeapons.SUPPRESSOR)), WeaponAssembly.OK)
	assert_eq(pistol.attach([], &"optic", _content.get_part(DemoWeapons.RED_DOT)), WeaponAssembly.OK)
	assert_true(pistol.is_operational())
	var shotgun: WeaponAssembly = DemoWeapons.assemble(_content, &"shotgun")
	assert_eq(shotgun.root.def.sockets.size(), 1)
	assert_eq(shotgun.attach([], &"optic", _content.get_part(DemoWeapons.SCOPE_4X)), WeaponAssembly.OK)
	assert_eq(shotgun.attach([], &"muzzle", _content.get_part(DemoWeapons.SUPPRESSOR)), WeaponAssembly.UNKNOWN_SOCKET)


func test_part_ids_and_item_ids_match_in_the_content_database() -> void:
	for id: StringName in [DemoWeapons.BARREL_SHORT, DemoWeapons.BARREL_LONG, DemoWeapons.HANDGUARD,
			DemoWeapons.GRIP_VERTICAL, DemoWeapons.STOCK_FIXED, DemoWeapons.STOCK_FOLDING, DemoWeapons.MAG_30,
			DemoWeapons.RED_DOT, DemoWeapons.SCOPE_4X, DemoWeapons.SUPPRESSOR]:
		assert_not_null(_content.get_part(id), "부품 %s" % id)
		var item_def: ItemDef = _content.get_item(id)
		assert_not_null(item_def, "아이템 %s" % id)
		assert_eq(item_def.category, ItemDef.Category.ATTACHMENT)


func test_ads_time_is_a_derived_row_that_follows_ergonomics() -> void:
	var stats: Dictionary[StringName, float] = ModStats.current(_rifle.weapon)
	assert_almost_eq(stats[ModStats.ADS_TIME], WeaponMotion.ads_time_for(stats[WeaponStats.ERGONOMICS]), 0.0001)
	var row: ModStats.Row = _row(ModStats.ADS_TIME)
	assert_true(row.lower_is_better)
	# 레드 도트 → 4배율 조준경: 조작성↓ → 조준 시간↑ (나빠짐)
	var preview: ModStats.Preview = ModStats.preview_attach(_rifle, [] as Array[StringName], &"optic",
			_content.get_part(DemoWeapons.SCOPE_4X))
	assert_eq(preview.error, WeaponAssembly.SOCKET_OCCUPIED)
	_rifle.weapon.detach([], &"optic")
	preview = ModStats.preview_attach(_rifle, [] as Array[StringName], &"optic", _content.get_part(DemoWeapons.SCOPE_4X))
	assert_eq(ModStats.verdict(row, stats[ModStats.ADS_TIME], preview.stats[ModStats.ADS_TIME]), ModStats.Verdict.WORSE)
