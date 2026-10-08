extends GutTest
## 무기 시스템 테스트 (M3): 부품 트리 조립·오류 코드·스탯·크기, 탄창, 데미지 모델.

const OK := WeaponAssembly.OK

var _rcv: WeaponPartDef
var _hg: WeaponPartDef
var _grip_a: WeaponPartDef
var _grip_b: WeaponPartDef
var _barrel_s: WeaponPartDef
var _barrel_l: WeaponPartDef
var _stock: WeaponPartDef
var _stock_fold: WeaponPartDef
var _supp: WeaponPartDef
var _brake: WeaponPartDef


func before_each() -> void:
	_rcv = WeaponPartDef.create(&"rcv", &"receiver")
	_rcv.base_stats[WeaponStats.RECOIL] = 10.0
	_rcv.base_stats[WeaponStats.FIRE_RATE] = 600.0
	_rcv.base_stats[WeaponStats.WEIGHT] = 3.0
	_rcv.base_stats[WeaponStats.DAMAGE_MULT] = 1.0
	_rcv.sockets.append(WeaponSocket.create(&"handguard", &"handguard", true))
	_rcv.sockets.append(WeaponSocket.create(&"barrel", &"barrel", true))
	_rcv.sockets.append(WeaponSocket.create(&"stock", &"stock"))

	_hg = WeaponPartDef.create(&"hg", &"handguard")
	_hg.sockets.append(WeaponSocket.create(&"grip", &"grip", true))
	_hg.sockets.append(WeaponSocket.create(&"rail", &"rail"))

	_grip_a = WeaponPartDef.create(&"grip_a", &"grip")
	_grip_a.modifiers.additive[WeaponStats.RECOIL] = -2.0
	_grip_a.conflicts.append(&"stock_fold")
	_grip_b = WeaponPartDef.create(&"grip_b", &"grip")

	_barrel_s = WeaponPartDef.create(&"barrel_s", &"barrel")
	_barrel_l = WeaponPartDef.create(&"barrel_l", &"barrel")
	_barrel_l.size_delta = Vector2i(1, 0)
	var muzzle_socket: WeaponSocket = WeaponSocket.create(&"muzzle", &"muzzle")
	muzzle_socket.allowed_parts.append(&"supp")
	_barrel_s.sockets.append(muzzle_socket)

	_stock = WeaponPartDef.create(&"stock_a", &"stock")
	_stock_fold = WeaponPartDef.create(&"stock_fold", &"stock")
	_supp = WeaponPartDef.create(&"supp", &"muzzle")
	_brake = WeaponPartDef.create(&"brake", &"muzzle")


func _path(names: Array) -> Array[StringName]:
	var p: Array[StringName] = []
	p.assign(names)
	return p


func _assembly() -> WeaponAssembly:
	return WeaponAssembly.new(_rcv)


## 리시버 → 핸드가드 → 손잡이, 총열까지 갖춘 작동 가능한 무기.
func _full() -> WeaponAssembly:
	var w: WeaponAssembly = _assembly()
	assert_eq(w.attach(_path([]), &"handguard", _hg), OK)
	assert_eq(w.attach(_path([&"handguard"]), &"grip", _grip_a), OK)
	assert_eq(w.attach(_path([]), &"barrel", _barrel_s), OK)
	return w


func _ids(w: WeaponAssembly) -> Array[StringName]:
	var ids: Array[StringName] = []
	for node: WeaponPartNode in w.get_parts():
		ids.append(node.def.id)
	return ids


# --- 장착 / 분리 ---

func test_attach_nested_by_path() -> void:
	var w: WeaponAssembly = _full()
	assert_eq(w.find_node(_path([&"handguard", &"grip"])).def, _grip_a)
	assert_eq(w.find_node(_path([])), w.root)
	assert_null(w.find_node(_path([&"handguard", &"rail"])))
	assert_null(w.find_node(_path([&"nope"])))
	assert_eq(_ids(w), [&"rcv", &"hg", &"grip_a", &"barrel_s"] as Array[StringName])


func test_attach_unknown_path() -> void:
	var w: WeaponAssembly = _assembly()
	assert_eq(w.attach(_path([&"handguard"]), &"grip", _grip_a), WeaponAssembly.UNKNOWN_PATH)
	assert_eq(w.get_parts().size(), 1)


func test_attach_unknown_socket() -> void:
	var w: WeaponAssembly = _assembly()
	assert_eq(w.attach(_path([]), &"nope", _hg), WeaponAssembly.UNKNOWN_SOCKET)
	assert_eq(w.get_parts().size(), 1)


func test_attach_socket_occupied() -> void:
	var w: WeaponAssembly = _full()
	assert_eq(w.attach(_path([&"handguard"]), &"grip", _grip_b), WeaponAssembly.SOCKET_OCCUPIED)
	assert_eq(w.find_node(_path([&"handguard", &"grip"])).def, _grip_a)


func test_attach_wrong_part_type() -> void:
	var w: WeaponAssembly = _assembly()
	assert_eq(w.attach(_path([]), &"handguard", _barrel_s), WeaponAssembly.WRONG_PART_TYPE)
	assert_eq(w.get_parts().size(), 1)


func test_attach_part_not_allowed() -> void:
	var w: WeaponAssembly = _full()
	assert_eq(w.attach(_path([&"barrel"]), &"muzzle", _brake), WeaponAssembly.PART_NOT_ALLOWED)
	assert_eq(w.attach(_path([&"barrel"]), &"muzzle", _supp), OK)


func test_conflict_existing_declares() -> void:
	var w: WeaponAssembly = _full()  # grip_a가 stock_fold와 충돌 선언
	assert_eq(w.attach(_path([]), &"stock", _stock_fold), WeaponAssembly.CONFLICT)
	assert_false(w.root.children.has(&"stock"))


func test_conflict_added_declares() -> void:
	var w: WeaponAssembly = _assembly()
	assert_eq(w.attach(_path([]), &"stock", _stock_fold), OK)
	assert_eq(w.attach(_path([]), &"handguard", _hg), OK)
	# stock_fold는 아무것도 선언하지 않았지만, 새로 붙는 grip_a가 stock_fold를 선언한다.
	assert_eq(w.attach(_path([&"handguard"]), &"grip", _grip_a), WeaponAssembly.CONFLICT)
	assert_false(w.find_node(_path([&"handguard"])).children.has(&"grip"))


func test_conflict_in_prebuilt_subtree_child() -> void:
	var w: WeaponAssembly = _assembly()
	assert_eq(w.attach(_path([]), &"stock", _stock_fold), OK)
	var sub := WeaponPartNode.new(_hg)
	sub.children[&"grip"] = WeaponPartNode.new(_grip_a)  # 하위 부품이 충돌
	assert_eq(w.attach_node(_path([]), &"handguard", sub), WeaponAssembly.CONFLICT)
	assert_eq(w.get_parts().size(), 2)
	assert_false(w.root.children.has(&"handguard"))


func test_attach_prebuilt_subtree_success() -> void:
	var w: WeaponAssembly = _assembly()
	var sub := WeaponPartNode.new(_hg)
	sub.children[&"grip"] = WeaponPartNode.new(_grip_b)
	assert_eq(w.attach_node(_path([]), &"handguard", sub), OK)
	assert_eq(w.find_node(_path([&"handguard", &"grip"])).def, _grip_b)


func test_can_attach_does_not_mutate() -> void:
	var w: WeaponAssembly = _assembly()
	assert_eq(w.can_attach(_path([]), &"handguard", _hg), OK)
	assert_eq(w.get_parts().size(), 1)


func test_failed_attach_leaves_tree_unchanged() -> void:
	var w: WeaponAssembly = _full()
	var before: Array[StringName] = _ids(w)
	var stats_before: Dictionary[StringName, float] = w.compute_stats()
	w.attach(_path([&"nope"]), &"grip", _grip_b)
	w.attach(_path([]), &"nope", _grip_b)
	w.attach(_path([&"handguard"]), &"grip", _grip_b)
	w.attach(_path([]), &"stock", _stock_fold)
	w.attach(_path([&"barrel"]), &"muzzle", _brake)
	w.attach(_path([]), &"stock", _barrel_s)
	assert_eq(_ids(w), before)
	assert_eq(w.compute_stats(), stats_before)


func test_detach_returns_subtree_and_stats_disappear() -> void:
	var w: WeaponAssembly = _full()
	assert_almost_eq(w.compute_stats()[WeaponStats.RECOIL], 8.0, 0.0001)
	var node: WeaponPartNode = w.detach(_path([]), &"handguard")
	assert_not_null(node)
	assert_eq(node.def, _hg)
	assert_eq(node.children[&"grip"].def, _grip_a)  # 하위 트리 유지
	assert_false(w.root.children.has(&"handguard"))
	assert_almost_eq(w.compute_stats()[WeaponStats.RECOIL], 10.0, 0.0001)
	assert_eq(_ids(w), [&"rcv", &"barrel_s"] as Array[StringName])
	# 소켓이 다시 비었으므로 재장착 가능
	assert_eq(w.attach_node(_path([]), &"handguard", node), OK)
	assert_almost_eq(w.compute_stats()[WeaponStats.RECOIL], 8.0, 0.0001)


func test_detach_nested_and_invalid() -> void:
	var w: WeaponAssembly = _full()
	var grip: WeaponPartNode = w.detach(_path([&"handguard"]), &"grip")
	assert_eq(grip.def, _grip_a)
	assert_null(w.detach(_path([&"handguard"]), &"grip"))  # 이미 빔
	assert_null(w.detach(_path([&"nope"]), &"grip"))        # 잘못된 경로
	assert_null(w.detach(_path([]), &"stock"))              # 빈 소켓


# --- 필수 소켓 ---

func test_missing_required_paths() -> void:
	var w: WeaponAssembly = _assembly()
	assert_eq(w.missing_required(), ["handguard", "barrel"] as Array[String])
	assert_false(w.is_operational())
	w.attach(_path([]), &"handguard", _hg)
	assert_eq(w.missing_required(), ["handguard/grip", "barrel"] as Array[String])
	w.attach(_path([&"handguard"]), &"grip", _grip_b)
	assert_eq(w.missing_required(), ["barrel"] as Array[String])
	assert_false(w.is_operational())
	w.attach(_path([]), &"barrel", _barrel_s)
	assert_eq(w.missing_required(), [] as Array[String])
	assert_true(w.is_operational())


func test_optional_sockets_not_required() -> void:
	var w: WeaponAssembly = _full()
	assert_true(w.is_operational())  # stock, rail, muzzle은 비어도 된다.


# --- 스탯 ---

func test_stats_base_only() -> void:
	var stats: Dictionary[StringName, float] = _assembly().compute_stats()
	assert_eq(stats[WeaponStats.RECOIL], 10.0)
	assert_eq(stats[WeaponStats.FIRE_RATE], 600.0)


func test_stats_additive_then_multiplicative() -> void:
	_grip_a.modifiers.additive[WeaponStats.RECOIL] = -2.0
	_stock.modifiers.additive[WeaponStats.RECOIL] = -3.0
	_stock.modifiers.multiplier[WeaponStats.RECOIL] = 0.5
	_barrel_s.modifiers.multiplier[WeaponStats.RECOIL] = 0.8
	var w: WeaponAssembly = _full()
	w.attach(_path([]), &"stock", _stock)
	# (10 - 2 - 3) × 0.5 × 0.8 = 2.0 (배율을 먼저 적용했다면 달라진다)
	assert_almost_eq(w.compute_stats()[WeaponStats.RECOIL], 2.0, 0.0001)


func test_stats_multiple_parts_additive_sum() -> void:
	_hg.modifiers.additive[WeaponStats.WEIGHT] = 0.5
	_barrel_s.modifiers.additive[WeaponStats.WEIGHT] = 1.0
	_grip_a.modifiers.additive[WeaponStats.WEIGHT] = 0.25
	var w: WeaponAssembly = _full()
	assert_almost_eq(w.compute_stats()[WeaponStats.WEIGHT], 4.75, 0.0001)


func test_stats_floor_applied() -> void:
	_grip_a.modifiers.additive[WeaponStats.RECOIL] = -50.0
	_barrel_s.modifiers.multiplier[WeaponStats.DAMAGE_MULT] = 0.01
	_hg.modifiers.additive[WeaponStats.FIRE_RATE] = -10000.0
	var stats: Dictionary[StringName, float] = _full().compute_stats()
	assert_eq(stats[WeaponStats.RECOIL], WeaponStats.MIN_VALUES[WeaponStats.RECOIL])
	assert_eq(stats[WeaponStats.DAMAGE_MULT], WeaponStats.MIN_VALUES[WeaponStats.DAMAGE_MULT])
	assert_eq(stats[WeaponStats.FIRE_RATE], WeaponStats.MIN_VALUES[WeaponStats.FIRE_RATE])


func test_stats_only_in_modifiers() -> void:
	_stock.modifiers.additive[WeaponStats.ERGONOMICS] = 12.0
	var w: WeaponAssembly = _full()
	assert_false(w.compute_stats().has(WeaponStats.ERGONOMICS))
	w.attach(_path([]), &"stock", _stock)
	assert_eq(w.compute_stats()[WeaponStats.ERGONOMICS], 12.0)


func test_stats_multiplier_only_key_gets_floor() -> void:
	# 기본값·가산 없이 배율만 있는 스탯은 0 × 배율 = 0 → 하한으로 올라간다.
	_stock.modifiers.multiplier[WeaponStats.LOUDNESS] = 0.5
	var w: WeaponAssembly = _full()
	w.attach(_path([]), &"stock", _stock)
	assert_eq(w.compute_stats()[WeaponStats.LOUDNESS], WeaponStats.MIN_VALUES[WeaponStats.LOUDNESS])


func test_stats_unknown_key_has_no_floor() -> void:
	_stock.modifiers.additive[&"custom"] = -5.0
	var w: WeaponAssembly = _full()
	w.attach(_path([]), &"stock", _stock)
	assert_eq(w.compute_stats()[&"custom"], -5.0)


func test_stats_null_modifiers_ignored() -> void:
	_stock.modifiers = null
	var w: WeaponAssembly = _full()
	assert_eq(w.attach(_path([]), &"stock", _stock), OK)
	assert_almost_eq(w.compute_stats()[WeaponStats.RECOIL], 8.0, 0.0001)


# --- 크기 ---

func test_compute_size_deltas_sum() -> void:
	_stock.size_delta = Vector2i(0, 1)
	_hg.size_delta = Vector2i(1, 1)
	var w: WeaponAssembly = _assembly()
	assert_eq(w.compute_size(Vector2i(3, 1)), Vector2i(3, 1))
	w.attach(_path([]), &"barrel", _barrel_l)
	w.attach(_path([]), &"stock", _stock)
	w.attach(_path([]), &"handguard", _hg)
	assert_eq(w.compute_size(Vector2i(3, 1)), Vector2i(5, 3))


func test_compute_size_floor_at_one() -> void:
	_stock.size_delta = Vector2i(-5, -9)
	var w: WeaponAssembly = _assembly()
	w.attach(_path([]), &"stock", _stock)
	assert_eq(w.compute_size(Vector2i(3, 2)), Vector2i(1, 1))
	assert_eq(w.compute_size(Vector2i(6, 10)), Vector2i(1, 1))
	assert_eq(w.compute_size(Vector2i(8, 12)), Vector2i(3, 3))


# --- 탄창 ---

func _ammo(id: StringName, caliber: StringName = &"556") -> AmmoDef:
	return AmmoDef.create(id, caliber, 40.0, 20.0)


func test_magazine_caliber_mismatch_loads_zero() -> void:
	var mag := Magazine.new(&"556", 30)
	assert_eq(mag.load_rounds(_ammo(&"x", &"762"), 10), 0)
	assert_true(mag.is_empty())


func test_magazine_capacity_limit() -> void:
	var mag := Magazine.new(&"556", 30)
	assert_eq(mag.load_rounds(_ammo(&"a"), 20), 20)
	assert_eq(mag.load_rounds(_ammo(&"a"), 20), 10)
	assert_true(mag.is_full())
	assert_eq(mag.load_rounds(_ammo(&"a"), 5), 0)
	assert_eq(mag.count(), 30)


func test_magazine_non_positive_amount() -> void:
	var mag := Magazine.new(&"556", 30)
	assert_eq(mag.load_rounds(_ammo(&"a"), 0), 0)
	assert_eq(mag.load_rounds(_ammo(&"a"), -3), 0)
	assert_true(mag.is_empty())


func test_magazine_lifo_mixed_ammo() -> void:
	var mag := Magazine.new(&"556", 30)
	mag.load_rounds(_ammo(&"fmj"), 3)
	mag.load_rounds(_ammo(&"ap"), 2)
	assert_eq(mag.peek_round(), &"ap")
	assert_eq(mag.pop_round(), &"ap")
	assert_eq(mag.pop_round(), &"ap")
	assert_eq(mag.pop_round(), &"fmj")
	assert_eq(mag.count(), 2)
	mag.load_rounds(_ammo(&"hp"), 1)
	assert_eq(mag.pop_round(), &"hp")
	assert_eq(mag.pop_round(), &"fmj")
	assert_eq(mag.pop_round(), &"fmj")
	assert_eq(mag.pop_round(), &"")
	assert_eq(mag.peek_round(), &"")
	assert_true(mag.is_empty())


func test_magazine_unload_all_counts() -> void:
	var mag := Magazine.new(&"556", 30)
	mag.load_rounds(_ammo(&"fmj"), 5)
	mag.load_rounds(_ammo(&"ap"), 3)
	mag.load_rounds(_ammo(&"fmj"), 2)
	var counts: Dictionary[StringName, int] = mag.unload_all()
	assert_eq(counts[&"fmj"], 7)
	assert_eq(counts[&"ap"], 3)
	assert_eq(counts.size(), 2)
	assert_true(mag.is_empty())
	assert_eq(mag.unload_all().size(), 0)


func test_magazine_get_rounds_is_copy() -> void:
	var mag := Magazine.new(&"556", 30)
	mag.load_rounds(_ammo(&"fmj"), 2)
	mag.load_rounds(_ammo(&"ap"), 1)
	var rounds: Array[StringName] = mag.get_rounds()
	assert_eq(rounds, [&"fmj", &"fmj", &"ap"] as Array[StringName])
	rounds.clear()
	rounds.append(&"junk")
	assert_eq(mag.count(), 3)
	assert_eq(mag.peek_round(), &"ap")


# --- 데미지 모델 ---

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_no_armor_full_damage() -> void:
	var ammo: AmmoDef = _ammo(&"a")
	ammo.penetration = 0.0  # 관통력이 0이어도 방탄이 없으면 전부 들어간다.
	var rng: RandomNumberGenerator = _rng(1)
	for _i: int in range(50):
		var hit: DamageModel.HitResult = DamageModel.resolve_hit(ammo, 1.5, 0, 1.0, rng)
		assert_true(hit.penetrated)
		assert_almost_eq(hit.damage, 60.0, 0.0001)
		assert_eq(hit.armor_damage, 0.0)


func test_penetration_chance_key_points() -> void:
	# 방탄 수치 = 등급 × 10 × 내구도.
	assert_almost_eq(DamageModel.penetration_chance(20.0, 2, 1.0), 0.5, 0.0001)
	assert_almost_eq(DamageModel.penetration_chance(25.0, 2, 1.0), 0.75, 0.0001)
	assert_almost_eq(DamageModel.penetration_chance(15.0, 2, 1.0), 0.25, 0.0001)
	assert_almost_eq(DamageModel.penetration_chance(30.0, 2, 1.0), 1.0, 0.0001)
	assert_almost_eq(DamageModel.penetration_chance(10.0, 2, 1.0), 0.0, 0.0001)
	# 내구도 50%면 등급 4도 방탄 수치 20.
	assert_almost_eq(DamageModel.penetration_chance(20.0, 4, 0.5), 0.5, 0.0001)


func test_penetration_chance_clamped() -> void:
	assert_eq(DamageModel.penetration_chance(1000.0, 6, 1.0), 1.0)
	assert_eq(DamageModel.penetration_chance(0.0, 6, 1.0), 0.0)
	assert_eq(DamageModel.penetration_chance(-50.0, 1, 1.0), 0.0)
	# 내구도 비율 > 1은 1로 제한
	assert_almost_eq(DamageModel.penetration_chance(20.0, 2, 3.0), 0.5, 0.0001)


func test_penetration_chance_zero_durability_is_one() -> void:
	assert_eq(DamageModel.penetration_chance(0.0, 6, 0.0), 1.0)
	assert_eq(DamageModel.penetration_chance(0.0, 6, -0.5), 1.0)
	assert_eq(DamageModel.penetration_chance(0.0, 0, 1.0), 1.0)
	assert_eq(DamageModel.penetration_chance(0.0, -1, 1.0), 1.0)


func test_blunt_damage_on_block() -> void:
	var ammo: AmmoDef = _ammo(&"a")
	ammo.penetration = 0.0
	# 등급 10 → 확률 0 → 항상 막힘 (난수에 의존하지 않음)
	var hit: DamageModel.HitResult = DamageModel.resolve_hit(ammo, 1.0, 10, 1.0, _rng(3))
	assert_false(hit.penetrated)
	assert_almost_eq(hit.damage, 40.0 * DamageModel.BLUNT_RATIO, 0.0001)
	assert_almost_eq(hit.armor_damage, 40.0 * 0.4, 0.0001)


func test_blunt_uses_damage_mult() -> void:
	var ammo: AmmoDef = _ammo(&"a")
	ammo.penetration = 0.0
	var hit: DamageModel.HitResult = DamageModel.resolve_hit(ammo, 2.0, 10, 1.0, _rng(3))
	assert_almost_eq(hit.damage, 80.0 * DamageModel.BLUNT_RATIO, 0.0001)


func test_armor_damage_on_penetration() -> void:
	var ammo: AmmoDef = _ammo(&"a")
	ammo.penetration = 100.0
	var hit: DamageModel.HitResult = DamageModel.resolve_hit(ammo, 1.0, 3, 1.0, _rng(3))
	assert_true(hit.penetrated)
	assert_almost_eq(hit.damage, 40.0, 0.0001)
	assert_almost_eq(hit.armor_damage, 16.0, 0.0001)


func test_penetration_rate_tracks_chance() -> void:
	var ammo: AmmoDef = _ammo(&"a")
	ammo.penetration = 25.0  # 등급 2 → 확률 0.75
	var rng: RandomNumberGenerator = _rng(12345)
	var trials: int = 4000
	var penetrated: int = 0
	for _i: int in range(trials):
		if DamageModel.resolve_hit(ammo, 1.0, 2, 1.0, rng).penetrated:
			penetrated += 1
	assert_almost_eq(float(penetrated) / trials, 0.75, 0.03)


func test_resolve_hit_deterministic_with_seed() -> void:
	var ammo: AmmoDef = _ammo(&"a")
	ammo.penetration = 20.0
	var a: Array[bool] = []
	var b: Array[bool] = []
	var rng_a: RandomNumberGenerator = _rng(99)
	var rng_b: RandomNumberGenerator = _rng(99)
	for _i: int in range(40):
		a.append(DamageModel.resolve_hit(ammo, 1.0, 2, 1.0, rng_a).penetrated)
		b.append(DamageModel.resolve_hit(ammo, 1.0, 2, 1.0, rng_b).penetrated)
	assert_eq(a, b)
