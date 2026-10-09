extends GutTest
## GraphicsTier: 단계별 설정 표·순환·기본 단계 선택 (M10).


func test_render_scale_rises_with_tier() -> void:
	var low: GraphicsTier.Settings = GraphicsTier.settings_for(GraphicsTier.Tier.LOW)
	var mid: GraphicsTier.Settings = GraphicsTier.settings_for(GraphicsTier.Tier.MID)
	var high: GraphicsTier.Settings = GraphicsTier.settings_for(GraphicsTier.Tier.HIGH)
	assert_almost_eq(low.render_scale, 0.7, 0.001)
	assert_almost_eq(mid.render_scale, 0.85, 0.001)
	assert_almost_eq(high.render_scale, 1.0, 0.001)


func test_shadow_settings_per_tier() -> void:
	var low: GraphicsTier.Settings = GraphicsTier.settings_for(GraphicsTier.Tier.LOW)
	var mid: GraphicsTier.Settings = GraphicsTier.settings_for(GraphicsTier.Tier.MID)
	var high: GraphicsTier.Settings = GraphicsTier.settings_for(GraphicsTier.Tier.HIGH)
	assert_false(low.shadows)
	assert_true(mid.shadows)
	assert_eq(mid.shadow_splits, 1)
	assert_almost_eq(mid.shadow_distance, 30.0, 0.001)
	assert_eq(high.shadow_splits, 2)
	assert_almost_eq(high.shadow_distance, 45.0, 0.001)


func test_glow_msaa_and_density() -> void:
	var low: GraphicsTier.Settings = GraphicsTier.settings_for(GraphicsTier.Tier.LOW)
	var mid: GraphicsTier.Settings = GraphicsTier.settings_for(GraphicsTier.Tier.MID)
	var high: GraphicsTier.Settings = GraphicsTier.settings_for(GraphicsTier.Tier.HIGH)
	assert_false(low.glow)
	assert_true(mid.glow and high.glow)
	assert_eq(low.msaa, GraphicsTier.MSAA_OFF)
	assert_eq(mid.msaa, GraphicsTier.MSAA_2X)
	assert_eq(high.msaa, GraphicsTier.MSAA_2X)
	assert_lt(low.particle_ratio, mid.particle_ratio)
	assert_lt(mid.particle_ratio, high.particle_ratio)
	assert_lt(low.weed_density, mid.weed_density)
	assert_lt(mid.weed_density, high.weed_density)


func test_next_cycles_through_all_tiers() -> void:
	var tier: GraphicsTier.Tier = GraphicsTier.Tier.LOW
	var seen: Array[GraphicsTier.Tier] = []
	for i: int in range(3):
		seen.append(tier)
		tier = GraphicsTier.next(tier)
	assert_eq(tier, GraphicsTier.Tier.LOW)
	assert_eq(seen, [GraphicsTier.Tier.LOW, GraphicsTier.Tier.MID, GraphicsTier.Tier.HIGH])


func test_names() -> void:
	assert_eq(GraphicsTier.tier_name(GraphicsTier.Tier.HIGH), "HIGH")
	assert_eq(GraphicsTier.from_name(" mid "), GraphicsTier.Tier.MID)
	assert_eq(GraphicsTier.from_name("???", GraphicsTier.Tier.LOW), GraphicsTier.Tier.LOW)


func test_default_tier() -> void:
	assert_eq(GraphicsTier.default_tier(true, false), GraphicsTier.Tier.MID)
	assert_eq(GraphicsTier.default_tier(false, true), GraphicsTier.Tier.MID)
	assert_eq(GraphicsTier.default_tier(false, false), GraphicsTier.Tier.HIGH)
