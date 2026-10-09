extends GutTest
## 가상 조이스틱 벡터 계산, InputState 합성/래치, HUD용 탄약 집계, 재장전 메시지.


func test_stick_inside_radius_maps_linearly() -> void:
	var s := FloatingStick.new()
	s.radius = 100.0
	s.deadzone = 0.0
	s.begin(Vector2(200, 500))
	var v: Vector2 = s.update(Vector2(250, 500))
	assert_almost_eq(v.x, 0.5, 0.0001)
	assert_almost_eq(v.y, 0.0, 0.0001)
	v = s.update(Vector2(200, 400))
	assert_almost_eq(v.y, -1.0, 0.0001, "위로 밀면 앞(음수 y)")


func test_stick_deadzone_and_clamp() -> void:
	var s := FloatingStick.new()
	s.radius = 100.0
	s.deadzone = 0.2
	s.follow = false
	s.begin(Vector2.ZERO)
	assert_eq(s.update(Vector2(10, 0)), Vector2.ZERO)
	var v: Vector2 = s.update(Vector2(300, 0))
	assert_almost_eq(v.length(), 1.0, 0.0001)
	assert_eq(s.origin, Vector2.ZERO, "follow 꺼짐: 기준점 고정")
	assert_almost_eq(s.knob_position().x, 100.0, 0.001, "손잡이는 반지름 안에 머문다")


func test_stick_follow_moves_origin_and_sprint_threshold() -> void:
	var s := FloatingStick.new()
	s.radius = 100.0
	s.deadzone = 0.0
	s.begin(Vector2.ZERO)
	s.update(Vector2(50, 0))
	assert_false(s.is_sprint())
	s.update(Vector2(250, 0))
	assert_almost_eq(s.origin.x, 150.0, 0.001, "반지름을 넘은 만큼 기준점이 따라옴")
	assert_true(s.is_sprint())
	s.end()
	assert_false(s.is_sprint())
	assert_eq(s.vector, Vector2.ZERO)


func test_stick_ignores_updates_when_inactive() -> void:
	var s := FloatingStick.new()
	assert_eq(s.update(Vector2(100, 100)), Vector2.ZERO)


func test_input_state_merges_sources() -> void:
	var st := InputState.new()
	st.set_move(InputState.Source.KEYBOARD, Vector2(0, -1))
	st.set_move(InputState.Source.TOUCH, Vector2(0.3, 0))
	assert_eq(st.move(), Vector2(0, -1), "더 큰 쪽 소스")
	st.set_move(InputState.Source.KEYBOARD, Vector2.ZERO)
	assert_eq(st.move(), Vector2(0.3, 0))
	st.set_fire_held(InputState.Source.TOUCH, true)
	assert_true(st.is_fire_held())
	st.release_source(InputState.Source.TOUCH)
	assert_false(st.is_fire_held())
	assert_eq(st.move(), Vector2.ZERO)


func test_input_state_latches_one_shot_events() -> void:
	var st := InputState.new()
	st.press_jump()
	st.press_reload()
	st.select_slot(2)
	st.add_look(Vector2(0.1, 0.2))
	st.add_look(Vector2(0.1, 0.0))
	assert_true(st.consume_jump())
	assert_false(st.consume_jump())
	assert_true(st.consume_reload())
	assert_eq(st.consume_slot_select(), 2)
	assert_eq(st.consume_slot_select(), -1)
	assert_eq(st.consume_look(), Vector2(0.2, 0.2))
	assert_eq(st.consume_look(), Vector2.ZERO)


func test_ammo_counter_counts_matching_caliber_only_where_reload_looks() -> void:
	var auth: LocalAuthority = CombatLoadout.build()
	var inv: Inventory = auth.inventory
	assert_eq(AmmoCounter.count_carried(inv, auth.content, &"5.56"), 60)
	assert_eq(AmmoCounter.count_carried(inv, auth.content, &"9mm"), 30)
	assert_eq(AmmoCounter.count_carried(inv, auth.content, &"12ga"), 16)
	assert_eq(AmmoCounter.count_carried(inv, auth.content, &"7.62"), 0)
	assert_eq(AmmoCounter.count_carried(null, auth.content, &"9mm"), 0)
	# 주머니에 더 넣으면 합산
	var pocket: ItemInstance = auth.create_item(auth.content.get_item(CombatLoadout.AMMO_9MM), 10)
	assert_true(inv.add_item(pocket, Inventory.pocket_key(0), Vector2i.ZERO, false).ok)
	assert_eq(AmmoCounter.count_carried(inv, auth.content, &"9mm"), 40)


func test_reload_error_texts_are_korean() -> void:
	assert_eq(WeaponController.reload_error_text(CommandResult.NO_AMMO), "탄약 없음")
	assert_eq(WeaponController.reload_error_text(CommandResult.MAGAZINE_FULL), "탄창 가득 참")
	assert_eq(WeaponController.reload_error_text(CommandResult.NOT_A_WEAPON), "재장전 실패")
	assert_eq(WeaponController.reload_duration(2), WeaponController.RELOAD_TIME_PISTOL)
	assert_eq(WeaponController.reload_duration(0), WeaponController.RELOAD_TIME)


func test_hit_target_find_walks_ancestors() -> void:
	var root := Node3D.new()
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var target := HitTarget.new()
	root.add_child(target)
	root.add_child(body)
	body.add_child(shape)
	assert_eq(HitTarget.find_for(shape), target)
	var stray := Node3D.new()
	assert_eq(HitTarget.find_for(stray), null)
	stray.free()
	root.free()
