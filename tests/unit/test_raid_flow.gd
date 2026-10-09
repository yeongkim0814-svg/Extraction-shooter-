extends GutTest
## M9 레이드 흐름의 순수 로직: 결과 집계(RaidSummary), 상호작용 대상 선택(InteractionFinder),
## 수색 전 아이템에 대한 드롭 판정·액션 목록, 컨테이너 루팅 테이블(RaidLoot).

var _auth: LocalAuthority
var _content: ContentDatabase


func before_each() -> void:
	_auth = CombatLoadout.build()
	_content = _auth.content


func _def(id: StringName, price: int, stack: int = 1) -> ItemDef:
	var def := ItemDef.create(id, 1, 1, stack)
	def.base_price = price
	return def


# --- RaidSummary ---

func test_carried_value_counts_only_found_in_raid_with_stacks() -> void:
	var inv: Inventory = _auth.inventory
	var fir: ItemInstance = _auth.create_item(_def(&"gold", 1000, 5), 3)
	fir.found_in_raid = true
	var own: ItemInstance = _auth.create_item(_def(&"mine", 500))
	var cheap: ItemInstance = _auth.create_item(_def(&"cheap", 10))
	cheap.found_in_raid = true
	assert_true(inv.add_item(fir, Inventory.pocket_key(0), Vector2i.ZERO, false).ok)
	assert_true(inv.add_item(own, Inventory.pocket_key(1), Vector2i.ZERO, false).ok)
	assert_true(inv.add_item(cheap, Inventory.pocket_key(2), Vector2i.ZERO, false).ok)
	assert_eq(RaidSummary.carried_value(inv), 3010)


func test_format_time() -> void:
	assert_eq(RaidSummary.format_time(0.0), "00:00")
	assert_eq(RaidSummary.format_time(65.9), "01:05")
	assert_eq(RaidSummary.format_time(-3.0), "00:00")
	assert_eq(RaidSummary.format_remaining(899.2), "15:00")
	assert_eq(RaidSummary.format_remaining(0.2), "00:01")


func test_report_for_extraction_and_death() -> void:
	var inv: Inventory = _auth.inventory
	var loot: ItemInstance = _auth.create_item(_def(&"gem", 7000))
	loot.found_in_raid = true
	assert_true(inv.auto_add_item(loot, [Inventory.pocket_key(0)]).ok)
	var session := RaidSession.new(inv)
	session.start_loadout()
	session.start_raid(600.0)
	session.tick(42.0)
	session.extract()
	var report: RaidSummary.Report = RaidSummary.build_report(session, 3, 2)
	assert_eq(report.outcome, RaidSession.Outcome.EXTRACTED)
	assert_eq(report.value, 7000)
	assert_eq(report.kills, 3)
	assert_eq(report.containers_searched, 2)
	assert_eq(report.lost_count, 0)
	assert_eq(RaidSummary.outcome_title(report.outcome), "탈출 성공")
	# 사망: 주머니 아이템을 잃고 잃은 개수가 기록된다
	var inv2: Inventory = _auth.inventory
	var dead := RaidSession.new(inv2)
	dead.start_loadout()
	dead.start_raid(600.0)
	dead.die()
	var dead_report: RaidSummary.Report = RaidSummary.build_report(dead, 0, 0)
	assert_eq(dead_report.outcome, RaidSession.Outcome.KILLED)
	assert_gt(dead_report.lost_count, 0)
	assert_eq(dead_report.value, 0)
	assert_eq(RaidSummary.outcome_title(RaidSession.Outcome.TIMED_OUT), "시간 초과")


# --- InteractionFinder.pick_index ---

func test_pick_nearest_in_front() -> void:
	var forward := Vector3(0, 0, -1)
	var spots: Array[Vector3] = [Vector3(0, 0, -2.0), Vector3(0, 0, -1.2)]
	assert_eq(InteractionFinder.pick_index(Vector3.ZERO, forward, spots), 1)


func test_pick_ignores_too_far_and_behind() -> void:
	var forward := Vector3(0, 0, -1)
	var spots: Array[Vector3] = [Vector3(0, 0, -3.0), Vector3(0, 0, 2.0), Vector3(2.4, 0, 0.0)]
	assert_eq(InteractionFinder.pick_index(Vector3.ZERO, forward, spots), -1)


func test_pick_point_blank_ignores_facing() -> void:
	var spots: Array[Vector3] = [Vector3(0, 0, 0.6)]
	assert_eq(InteractionFinder.pick_index(Vector3.ZERO, Vector3(0, 0, -1), spots), 0)


func test_pick_ignores_height_and_empty() -> void:
	var spots: Array[Vector3] = [Vector3(0, 1.0, -1.0)]
	assert_eq(InteractionFinder.pick_index(Vector3.ZERO, Vector3(0, 0, -1), spots), 0)
	var none: Array[Vector3] = []
	assert_eq(InteractionFinder.pick_index(Vector3.ZERO, Vector3(0, 0, -1), none), -1)
	assert_eq(InteractionFinder.pick_index(Vector3.ZERO, Vector3.ZERO, spots), -1)


# --- 수색 전 아이템 (DropResolver / InventoryActions) ---

func _open_searchable() -> Dictionary:
	var grid := ItemGrid.new(4, 3)
	var hidden: ItemInstance = _auth.create_item(_content.get_item(CombatLoadout.AMMO_9MM), 10)
	assert_true(grid.try_place(hidden, Vector2i(0, 0), false))
	var key: StringName = _auth.register_container(grid, "상자", true)
	assert_true(_auth.execute(OpenContainerCommand.new(key)).ok)
	return {"key": key, "item": hidden}


func test_hidden_item_cannot_be_dropped_or_selected() -> void:
	var c: Dictionary = _open_searchable()
	var inv: Inventory = _auth.inventory
	var item: ItemInstance = c["item"]
	var to_pocket: DropResolver.Resolution = DropResolver.resolve_grid(inv, item.id, Inventory.pocket_key(0), Vector2i.ZERO, false)
	assert_false(to_pocket.valid)
	assert_eq(to_pocket.error, CommandResult.NOT_REVEALED)
	assert_eq(DropResolver.resolve_tap_grid(inv, item.id, Inventory.pocket_key(0), Vector2i.ZERO, false).error,
			CommandResult.NOT_REVEALED)
	assert_eq(DropResolver.plan_equip(inv, item.id).error, CommandResult.NOT_REVEALED)
	assert_null(DropResolver.plan_split(inv, item.id))
	assert_null(DropResolver.plan_rotate_in_place(inv, item.id, true))
	assert_true(InventoryActions.for_item(inv, item.id).is_empty())


func test_dropping_onto_hidden_stack_is_not_a_merge() -> void:
	var c: Dictionary = _open_searchable()
	var inv: Inventory = _auth.inventory
	var hidden: ItemInstance = c["item"]
	var own: ItemInstance = _auth.create_item(hidden.def, 5)
	assert_true(inv.add_item(own, Inventory.pocket_key(0), Vector2i.ZERO, false).ok)
	var drop: DropResolver.Resolution = DropResolver.resolve_grid(inv, own.id, c["key"], Vector2i.ZERO, false)
	assert_false(drop.valid)
	assert_eq(drop.error, CommandResult.NOT_REVEALED)


func test_revealed_item_becomes_normal() -> void:
	var c: Dictionary = _open_searchable()
	var inv: Inventory = _auth.inventory
	var item: ItemInstance = c["item"]
	_auth.execute(SearchContainerCommand.new(c["key"]))
	_auth.tick_searches(10.0)
	assert_false(inv.is_hidden(item))
	assert_true(DropResolver.resolve_grid(inv, item.id, Inventory.pocket_key(0), Vector2i.ZERO, false).valid)
	assert_false(InventoryActions.for_item(inv, item.id).is_empty())


# --- RaidLoot / DemoLoot ---

func test_demo_items_fit_and_have_varied_prices() -> void:
	DemoLoot.register_items(_content)
	var calculator := SearchTimeCalculator.new()
	var times: Dictionary = {}
	for id: StringName in [&"scrap_metal", &"toolkit", &"lighter", &"gold_watch", &"gold_bar", &"medkit", &"bandage"]:
		var def: ItemDef = _content.get_item(id)
		assert_not_null(def, String(id))
		assert_between(def.width, 1, 2)
		assert_between(def.height, 1, 2)
		assert_gt(def.base_price, 0, String(id))
		times[snappedf(calculator.time_for(def), 0.01)] = true
	assert_gt(times.size(), 3, "수색 시간이 아이템마다 달라야 함")


func test_every_kind_rolls_items_that_fit_its_grid() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for kind: LootContainer.Kind in LootContainer.Kind.values():
		var table: LootTable = RaidLoot.table_for(kind, _content)
		assert_gt(table.entries.size(), 3, LootContainer.kind_name(kind))
		var size: Vector2i = LootContainer.GRID_SIZES[kind]
		for _round: int in range(20):
			var grid := ItemGrid.new(size.x, size.y)
			var placed: Array[ItemInstance] = table.fill_grid(grid, rng, _auth)
			assert_gte(placed.size(), table.min_items - 1, LootContainer.kind_name(kind))
			for item: ItemInstance in placed:
				assert_true(item.found_in_raid)


func test_container_roll_registers_searchable_container() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var container := LootContainer.create(LootContainer.Kind.WEAPON_BOX)
	var key: StringName = container.roll_contents(_auth, rng)
	assert_true(Inventory.is_external_key(key))
	assert_true(_auth.searches.has(key))
	assert_eq(_auth.container_titles[key], "무기 상자")
	assert_gt(container.item_count(), 0)
	assert_eq(container.roll_contents(_auth, rng), key, "두 번 굴려도 같은 키")
	container.free()
