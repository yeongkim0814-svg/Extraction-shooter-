extends GutTest
## RaidSession / DeathResolver / ExtractionTracker 테스트 (M3).

const Slot := EquipmentSlots.Slot

var _next_id: int = 1
var _inv: Inventory
var _session: RaidSession
var _ids: Dictionary = {}


func before_each() -> void:
	_next_id = 1
	_inv = Inventory.new(Vector2i(10, 10))
	_session = RaidSession.new(_inv)
	_ids = {}


func _make(def: ItemDef) -> ItemInstance:
	var item := ItemInstance.new(_next_id, def)
	_next_id += 1
	return item


func _def(category: ItemDef.Category, grid_sizes: Array[Vector2i] = []) -> ItemDef:
	var def := ItemDef.create(&"x", 2, 2)
	def.category = category
	def.grids = grid_sizes
	return def


func _loadout() -> void:
	var sizes: Array[Vector2i] = [Vector2i(4, 4)]
	var helmet: ItemInstance = _make(_def(ItemDef.Category.HELMET))
	var pack: ItemInstance = _make(_def(ItemDef.Category.BACKPACK, sizes))
	var secure: ItemInstance = _make(_def(ItemDef.Category.SECURE_CONTAINER, sizes))
	assert_true(_inv.add_equipped(helmet, Slot.HELMET).ok)
	assert_true(_inv.add_equipped(pack, Slot.BACKPACK).ok)
	assert_true(_inv.add_equipped(secure, Slot.SECURE_CONTAINER).ok)
	var in_pack: ItemInstance = _make(ItemDef.create(&"p", 1, 1))
	var in_secure: ItemInstance = _make(ItemDef.create(&"s", 1, 1))
	var in_pocket: ItemInstance = _make(ItemDef.create(&"k", 1, 1))
	var in_stash: ItemInstance = _make(ItemDef.create(&"t", 1, 1))
	assert_true(_inv.add_item(in_pack, Inventory.item_grid_key(pack.id, 0), Vector2i.ZERO, false).ok)
	assert_true(_inv.add_item(in_secure, Inventory.item_grid_key(secure.id, 0), Vector2i.ZERO, false).ok)
	assert_true(_inv.add_item(in_pocket, Inventory.pocket_key(0), Vector2i.ZERO, false).ok)
	assert_true(_inv.add_item(in_stash, Inventory.STASH, Vector2i.ZERO, false).ok)
	_ids = {"helmet": helmet, "pack": pack, "secure": secure, "in_pack": in_pack,
			"in_secure": in_secure, "in_pocket": in_pocket, "in_stash": in_stash}


func _begin_raid(limit: float = 100.0) -> void:
	assert_true(_session.start_loadout())
	assert_true(_session.start_raid(limit))


func _has(key: String) -> bool:
	return _inv.get_item((_ids[key] as ItemInstance).id) != null


# --- 상태 전이 ---

func test_legal_full_cycle_extract() -> void:
	assert_eq(_session.state, RaidSession.State.HIDEOUT)
	assert_true(_session.start_loadout())
	assert_eq(_session.state, RaidSession.State.LOADOUT)
	assert_true(_session.start_raid(60.0))
	assert_eq(_session.state, RaidSession.State.IN_RAID)
	assert_true(_session.extract())
	assert_eq(_session.state, RaidSession.State.EXTRACTED)
	assert_eq(_session.outcome, RaidSession.Outcome.EXTRACTED)
	assert_true(_session.show_results())
	assert_eq(_session.state, RaidSession.State.RESULTS)
	assert_true(_session.return_to_hideout())
	assert_eq(_session.state, RaidSession.State.HIDEOUT)


func test_legal_death_path() -> void:
	_begin_raid()
	assert_true(_session.die())
	assert_eq(_session.state, RaidSession.State.DEAD)
	assert_eq(_session.outcome, RaidSession.Outcome.KILLED)
	assert_true(_session.show_results())
	assert_true(_session.return_to_hideout())


func test_illegal_transitions_change_nothing() -> void:
	assert_false(_session.start_raid(60.0))
	assert_false(_session.extract())
	assert_false(_session.die())
	assert_false(_session.show_results())
	assert_false(_session.return_to_hideout())
	assert_false(_session.tick(1.0))
	assert_eq(_session.state, RaidSession.State.HIDEOUT)
	assert_false(_inv.stash_locked)

	assert_true(_session.start_loadout())
	assert_false(_session.start_loadout())
	assert_false(_session.extract())
	assert_false(_session.die())
	assert_false(_session.show_results())
	assert_false(_session.return_to_hideout())
	assert_false(_session.start_raid(0.0))
	assert_eq(_session.state, RaidSession.State.LOADOUT)

	assert_true(_session.start_raid(60.0))
	assert_false(_session.start_loadout())
	assert_false(_session.start_raid(60.0))
	assert_false(_session.show_results())
	assert_false(_session.return_to_hideout())
	assert_eq(_session.state, RaidSession.State.IN_RAID)

	assert_true(_session.extract())
	assert_false(_session.extract())
	assert_false(_session.die())
	assert_false(_session.tick(1.0))
	assert_false(_session.return_to_hideout())
	assert_eq(_session.state, RaidSession.State.EXTRACTED)

	assert_true(_session.show_results())
	assert_false(_session.show_results())
	assert_false(_session.extract())
	assert_false(_session.die())
	assert_false(_session.start_loadout())
	assert_eq(_session.state, RaidSession.State.RESULTS)


func test_stash_lock_toggles() -> void:
	assert_false(_inv.stash_locked)
	_session.start_loadout()
	assert_false(_inv.stash_locked)
	_session.start_raid(30.0)
	assert_true(_inv.stash_locked)
	_session.extract()
	_session.show_results()
	assert_true(_inv.stash_locked)
	_session.return_to_hideout()
	assert_false(_inv.stash_locked)


func test_tick_accumulates_and_times_out() -> void:
	_loadout()
	_begin_raid(10.0)
	assert_true(_session.tick(4.0))
	assert_eq(_session.elapsed, 4.0)
	assert_eq(_session.state, RaidSession.State.IN_RAID)
	assert_true(_session.tick(6.0))
	assert_eq(_session.state, RaidSession.State.DEAD)
	assert_eq(_session.outcome, RaidSession.Outcome.TIMED_OUT)
	assert_false(_has("helmet"))
	assert_false(_session.lost_item_ids.is_empty())
	assert_false(_session.tick(1.0))


func test_tick_negative_ignored() -> void:
	_begin_raid(10.0)
	assert_false(_session.tick(-1.0))
	assert_eq(_session.elapsed, 0.0)


# --- 사망 처리 ---

func test_death_keeps_secure_container_contents_and_stash() -> void:
	_loadout()
	_begin_raid()
	assert_true(_session.die())
	assert_false(_has("helmet"))
	assert_false(_has("pack"))
	assert_false(_has("in_pack"))
	assert_false(_has("in_pocket"))
	assert_true(_has("secure"))
	assert_true(_has("in_secure"))
	assert_true(_has("in_stash"))
	assert_null(_inv.equipment.get_item(Slot.HELMET))
	assert_not_null(_inv.equipment.get_item(Slot.SECURE_CONTAINER))
	assert_true(_inv.is_consistent())


func test_lost_item_ids_include_nested() -> void:
	_loadout()
	_begin_raid()
	_session.die()
	var lost: Array[int] = _session.lost_item_ids
	assert_eq(lost.size(), 4)
	for key: String in ["helmet", "pack", "in_pack", "in_pocket"]:
		assert_has(lost, (_ids[key] as ItemInstance).id)
	for key: String in ["secure", "in_secure", "in_stash"]:
		assert_does_not_have(lost, (_ids[key] as ItemInstance).id)


func test_extraction_keeps_everything() -> void:
	_loadout()
	_begin_raid()
	var before: int = _inv.get_items().size()
	assert_true(_session.extract())
	assert_eq(_inv.get_items().size(), before)
	assert_true(_session.lost_item_ids.is_empty())
	for key: String in _ids:
		assert_true(_has(key))


func test_resolver_with_empty_inventory() -> void:
	assert_eq(DeathResolver.resolve(Inventory.new()).size(), 0)


func test_resolver_works_when_stash_locked() -> void:
	_loadout()
	_inv.stash_locked = true
	var lost: Array[int] = DeathResolver.resolve(_inv)
	assert_eq(lost.size(), 4)
	assert_true(_has("in_stash"))


# --- 탈출 지점 ---

func _point(wait: float = 4.0, flag: StringName = &"") -> ExtractionPoint:
	var point := ExtractionPoint.new()
	point.id = &"p"
	point.wait_time = wait
	point.required_flag = flag
	return point


func test_extraction_point_defaults() -> void:
	var point := ExtractionPoint.new()
	assert_eq(point.wait_time, 7.0)
	assert_eq(point.required_flag, &"")


func test_tracker_progress_and_fires_once() -> void:
	var tracker := ExtractionTracker.new()
	tracker.enter(_point(4.0))
	assert_false(tracker.tick(1.0, {}))
	assert_eq(tracker.progress(), 0.25)
	assert_false(tracker.tick(2.0, {}))
	assert_true(tracker.tick(1.0, {}))
	assert_eq(tracker.progress(), 1.0)
	assert_false(tracker.tick(1.0, {}))
	assert_false(tracker.tick(1.0, {}))


func test_tracker_leave_resets() -> void:
	var tracker := ExtractionTracker.new()
	var point: ExtractionPoint = _point(4.0)
	tracker.enter(point)
	tracker.tick(3.0, {})
	tracker.leave()
	assert_eq(tracker.progress(), 0.0)
	assert_false(tracker.tick(5.0, {}))
	tracker.enter(point)
	assert_false(tracker.tick(3.0, {}))
	assert_true(tracker.tick(1.0, {}))


func test_tracker_can_fire_again_after_reenter() -> void:
	var tracker := ExtractionTracker.new()
	var point: ExtractionPoint = _point(2.0)
	tracker.enter(point)
	assert_true(tracker.tick(2.0, {}))
	tracker.leave()
	tracker.enter(point)
	assert_true(tracker.tick(2.0, {}))


func test_tracker_flag_gating() -> void:
	var tracker := ExtractionTracker.new()
	tracker.enter(_point(4.0, &"power_on"))
	assert_false(tracker.tick(10.0, {}))
	assert_eq(tracker.progress(), 0.0)
	assert_false(tracker.tick(10.0, {&"power_on": false}))
	assert_false(tracker.tick(3.0, {&"power_on": true}))
	assert_eq(tracker.progress(), 0.75)
	# 도중에 닫히면 초기화
	assert_false(tracker.tick(1.0, {}))
	assert_eq(tracker.progress(), 0.0)
	assert_false(tracker.tick(3.0, {&"power_on": true}))
	assert_true(tracker.tick(1.0, {&"power_on": true}))


func test_tracker_without_point_does_nothing() -> void:
	var tracker := ExtractionTracker.new()
	assert_false(tracker.tick(10.0, {}))
	assert_eq(tracker.progress(), 0.0)
