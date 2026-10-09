class_name IndustrialFactory
extends RefCounted
## 공장 단지 (북쪽): 걸어 들어갈 수 있는 바닥층 홀(문 구멍·캣워크·크레인 레일), "03" 표시가 붙은 큰 본관 블록,
## 굴뚝 4개(하나는 빨강·흰 띠), 부속동, 탱크. 홀 안은 어둡고 높은 창문 띠로 빛이 들어온다.

const BRICK: StringName = IndustrialMaterials.BRICK
const CONCRETE: StringName = IndustrialMaterials.CONCRETE
const CONCRETE_DARK: StringName = IndustrialMaterials.CONCRETE_DARK
const STEEL: StringName = IndustrialMaterials.STEEL
const RUST: StringName = IndustrialMaterials.RUST
const BAND_RED: StringName = IndustrialMaterials.BAND_RED
const BAND_WHITE: StringName = IndustrialMaterials.BAND_WHITE
const FONT: Font = preload("res://assets/fonts/NotoSansKR.ttf")

const HALL_X0: float = -44.0
const HALL_X1: float = 8.0
const HALL_Z0: float = -76.0
const HALL_Z1: float = -48.0
const HALL_H: float = 9.5
const WALL_T: float = 0.6
const CATWALK_Y: float = 4.2


static func build(m: IndustrialMap) -> void:
	_hall(m)
	_hall_interior(m)
	_main_block(m)
	_stacks(m)
	_north_yard(m)


static func _hall(m: IndustrialMap) -> void:
	var door_h: float = 4.2
	m.wall_x(HALL_X0, HALL_X1, HALL_Z1, 0.0, HALL_H, WALL_T, BRICK,
			[Vector2(-34.0, 5.0), Vector2(-18.0, 5.0), Vector2(-2.0, 5.0)], door_h)
	m.wall_x(HALL_X0, HALL_X1, HALL_Z0, 0.0, HALL_H, WALL_T, BRICK, [Vector2(-30.0, 4.0)], 3.6)
	m.wall_z(HALL_Z0, HALL_Z1, HALL_X0, 0.0, HALL_H, WALL_T, BRICK, [Vector2(-52.0, 4.0)], 3.6)
	m.wall_z(HALL_Z0, HALL_Z1, HALL_X1, 0.0, HALL_H, WALL_T, BRICK, [])
	# 지붕판 + 처마 띠
	m.span(HALL_X0 - 0.3, HALL_X1 + 0.3, HALL_H, HALL_H + 0.4, HALL_Z0 - 0.3, HALL_Z1 + 0.3, STEEL)
	m.span(HALL_X0 - 0.4, HALL_X1 + 0.4, HALL_H - 1.0, HALL_H, HALL_Z1 + 0.3, HALL_Z1 + 0.5, CONCRETE_DARK, false)
	# 높은 창문 띠: 안쪽(밝음) / 바깥쪽(희미)
	var y0: float = 6.5
	var y1: float = 8.3
	m.window_strip(Vector3(HALL_X0 + 1.0, 0, HALL_Z1 - 0.3), Vector3(HALL_X1 - 1.0, 0, HALL_Z1 - 0.3), y0, y1, Vector3(0, 0, -1), true)
	m.window_strip(Vector3(HALL_X0 + 1.0, 0, HALL_Z1 + 0.3), Vector3(HALL_X1 - 1.0, 0, HALL_Z1 + 0.3), y0, y1, Vector3(0, 0, 1), false)
	m.window_strip(Vector3(HALL_X0 + 1.0, 0, HALL_Z0 + 0.3), Vector3(HALL_X1 - 1.0, 0, HALL_Z0 + 0.3), y0, y1, Vector3(0, 0, 1), true)
	m.window_strip(Vector3(HALL_X0 + 1.0, 0, HALL_Z0 - 0.3), Vector3(HALL_X1 - 1.0, 0, HALL_Z0 - 0.3), y0, y1, Vector3(0, 0, -1), false)
	m.window_strip(Vector3(HALL_X0 + 0.3, 0, HALL_Z0 + 1.0), Vector3(HALL_X0 + 0.3, 0, HALL_Z1 - 1.0), y0, y1, Vector3(1, 0, 0), true)
	m.window_strip(Vector3(HALL_X0 - 0.3, 0, HALL_Z0 + 1.0), Vector3(HALL_X0 - 0.3, 0, HALL_Z1 - 1.0), y0, y1, Vector3(-1, 0, 0), false)
	# 북쪽 창에서 홀 안으로 비스듬히 들어오는 빛줄기 (해가 북쪽에 낮게 있다)
	for x: float in [-40.0, -32.0, -24.0, -16.0, -8.0, 0.0]:
		m.light_shaft(Vector3(x - 1.4, 0, HALL_Z0 + 0.4), Vector3(x + 1.4, 0, HALL_Z0 + 0.4), y1, Vector3(0.3, 0, 1.0), 15.0)
	for x: float in [-30.0, -10.0]:
		m.light_shaft(Vector3(x - 1.4, 0, HALL_Z1 - 0.4), Vector3(x + 1.4, 0, HALL_Z1 - 0.4), y1, Vector3(-0.2, 0, -1.0),
				11.0, 0.09, 0.01)
	# 매달린 램프
	for pos: Vector3 in [Vector3(-36, 9.4, -58), Vector3(-24, 9.4, -66), Vector3(-12, 9.4, -57), Vector3(-2, 9.4, -68),
			Vector3(-26, 9.4, -53)]:
		m.hanging_lamp(pos, 2.6)


static func _hall_interior(m: IndustrialMap) -> void:
	# 기둥: 두 줄
	for z: float in [-56.0, -68.0]:
		for x: float in [-40.0, -28.0, -16.0, -4.0]:
			m.box(Vector3(x, HALL_H * 0.5, z), Vector3(0.7, HALL_H, 0.7), STEEL)
			m.cover_markers(x, z, 0.35, 0.35, 0.0, 0.8)
	# 천장 크레인: 레일 + 교량 + 트롤리
	m.span(HALL_X0 + 0.5, HALL_X1 - 0.5, 8.4, 9.1, -62.4, -61.6, STEEL, false, false)
	m.span(-16.4, -15.6, 8.5, 9.2, HALL_Z0 + 0.5, HALL_Z1 - 0.5, STEEL, false, false)
	m.box(Vector3(-16.0, 8.0, -62.0), Vector3(1.4, 0.6, 1.4), RUST, Basis.IDENTITY, false, false)
	m.box(Vector3(-16.0, 6.6, -62.0), Vector3(0.05, 2.2, 0.05), STEEL, Basis.IDENTITY, false, false)
	m.box(Vector3(-16.0, 5.4, -62.0), Vector3(0.5, 0.3, 0.3), IndustrialMaterials.CONT_OCHRE, Basis.IDENTITY, false, false)
	# 북쪽 벽 쪽 캣워크 (경사로로 올라간다)
	var z_near: float = -71.5
	m.span(-43.0, -11.0, CATWALK_Y - 0.3, CATWALK_Y, HALL_Z0 + 0.7, z_near, STEEL)
	for x: float in [-42.0, -34.0, -26.0, -18.0, -12.0]:
		m.box(Vector3(x, (CATWALK_Y - 0.3) * 0.5, z_near + 0.2), Vector3(0.3, CATWALK_Y - 0.3, 0.3), STEEL)
	m.span(-43.0, -11.0, CATWALK_Y + 0.95, CATWALK_Y + 1.03, z_near - 0.05, z_near + 0.03, STEEL, false, false)
	m.span(-43.0, -11.0, CATWALK_Y + 0.5, CATWALK_Y + 0.56, z_near - 0.05, z_near + 0.03, STEEL, false, false)
	for x: float in [-43.0, -37.0, -31.0, -25.0, -19.0, -13.0, -11.1]:
		m.box(Vector3(x, CATWALK_Y + 0.5, z_near - 0.01), Vector3(0.05, 1.0, 0.05), STEEL, Basis.IDENTITY, false, false)
	m.ramp_z(-41.7, 2.4, -57.5, z_near, 0.0, CATWALK_Y, STEEL)
	# 기계·소품 (엄폐)
	m.cover_box(Vector3(-12.0, 1.3, -64.0), Vector3(6.0, 2.6, 3.0), RUST)
	m.cover_box(Vector3(-6.0, 1.0, -72.4), Vector3(3.0, 2.0, 2.4), STEEL)
	m.box(Vector3(-12.0, 2.75, -64.0), Vector3(5.2, 0.3, 2.4), STEEL, Basis.IDENTITY, false)
	m.cover_box(Vector3(-35.0, 0.6, -64.0), Vector3(2.4, 1.2, 1.6), CONCRETE_DARK)
	IndustrialProps.forklift(m, Vector3(-27.0, 0.0, -61.0), 20.0)
	IndustrialProps.pallet_stack(m, Vector3(-38.0, 0.0, -50.0), 0.0, 2)
	IndustrialProps.pallet_stack(m, Vector3(-37.0, 0.0, -52.5), 90.0, 1)
	IndustrialProps.pallet_stack(m, Vector3(2.0, 0.0, -56.0), 0.0, 3, IndustrialMaterials.CONT_RUST)
	IndustrialProps.pallet(m, Vector3(-22.0, 0.0, -73.0), 10.0)
	IndustrialProps.barrels(m, Vector3(-3.0, 0.0, -73.5), 4)
	IndustrialProps.barrels(m, Vector3(-42.0, 0.0, -70.0), 3)
	m.loot(LootContainer.Kind.WEAPON_BOX, Vector3(-9.0, 0.0, -74.2), 0.0)
	m.loot(LootContainer.Kind.CRATE, Vector3(-31.5, 0.0, -66.8), 0.0)
	m.loot(LootContainer.Kind.TOOLBOX, Vector3(-39.0, 0.0, -55.0), 90.0)
	m.loot(LootContainer.Kind.MEDBAG, Vector3(-24.0, CATWALK_Y, -74.0), 0.0)


## 본관 블록 + 부속동. 남쪽 면에 큰 "03".
static func _main_block(m: IndustrialMap) -> void:
	m.span(8.0, 36.0, 0.0, 24.0, -80.0, -52.0, CONCRETE)
	m.span(36.0, 50.0, 0.0, 15.0, -76.0, -56.0, CONCRETE_DARK)
	m.span(7.6, 36.4, 22.0, 24.4, -80.4, -51.6, CONCRETE_DARK, false)
	# 가로 띠(색이 다른 패널 줄)와 창 줄
	for y: float in [3.0, 8.0]:
		m.window_strip(Vector3(10.0, 0, -51.97), Vector3(34.0, 0, -51.97), y, y + 1.8, Vector3(0, 0, 1), false)
	for y: float in [3.0, 8.0]:
		m.window_strip(Vector3(38.0, 0, -55.97), Vector3(48.0, 0, -55.97), y, y + 1.8, Vector3(0, 0, 1), false)
	m.span(8.0, 36.0, 11.0, 11.5, -52.1, -51.9, BRICK, false)
	m.span(8.0, 36.0, 21.0, 21.5, -52.1, -51.9, BRICK, false)
	# 지붕 위 설비
	for rect: Rect2 in [Rect2(10, -78, 4, 4), Rect2(18, -70, 6, 3), Rect2(28, -62, 5, 5), Rect2(12, -60, 3, 3)]:
		m.box(Vector3(rect.position.x + rect.size.x * 0.5, 25.4, rect.position.y + rect.size.y * 0.5),
				Vector3(rect.size.x, 2.0, rect.size.y), STEEL, Basis.IDENTITY, false)
	# 건물 벽을 타고 오르는 수직 배관
	for x: float in [11.0, 12.2, 31.0]:
		m.cylinder(Vector3(x, 11.0, -51.7), 0.22, 0.22, 22.0, RUST, 8, Basis.IDENTITY, Vector3.ZERO, true, false)
	# 외부 캣워크 (장식, 지지대 포함)
	m.span(10.0, 34.0, 9.0, 9.2, -52.0, -50.2, STEEL, false)
	m.span(10.0, 34.0, 9.9, 9.96, -50.3, -50.2, STEEL, false, false)
	for x: float in [10.0, 16.0, 22.0, 28.0, 34.0]:
		m.box(Vector3(x, 9.5, -50.25), Vector3(0.06, 1.0, 0.06), STEEL, Basis.IDENTITY, false, false)
		m.beam(Vector3(x, 9.0, -51.0), Vector3(x, 4.0, -50.0), 0.15, STEEL)
	# 큰 "03" 표시 (희미하게 바랜 흰 페인트)
	var label := Label3D.new()
	label.text = "03"
	label.font = FONT
	label.font_size = 256
	label.pixel_size = 0.052
	label.position = Vector3(22.0, 16.5, -51.9)
	label.modulate = Color(0.64, 0.67, 0.7, 0.78)
	label.outline_size = 0
	label.shaded = false
	label.double_sided = false
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(label)


static func _stacks(m: IndustrialMap) -> void:
	var specs: Array[Vector3] = [Vector3(12.0, 46.0, -84.0), Vector3(20.0, 38.0, -84.0),
			Vector3(28.0, 52.0, -84.0), Vector3(34.0, 34.0, -84.0)]
	var index: int = 0
	for spec: Vector3 in specs:
		var h: float = spec.y
		var r_bottom: float = 2.3
		var r_top: float = 1.4
		m.cylinder(Vector3(spec.x, h * 0.5, spec.z), r_top, r_bottom, h, IndustrialMaterials.CONCRETE_DARK, 14)
		m.collider(Vector3(spec.x, 4.0, spec.z), Vector3(3.8, 8.0, 3.8))
		if index == 2:
			# 빨강·흰 띠: 꼭대기 16 m
			for band: int in range(4):
				var y0: float = h - 16.0 + 4.0 * float(band)
				var r_low: float = lerpf(r_bottom, r_top, y0 / h) + 0.04
				var r_high: float = lerpf(r_bottom, r_top, (y0 + 4.0) / h) + 0.04
				var mat: StringName = BAND_RED if band % 2 == 0 else BAND_WHITE
				m.cylinder(Vector3(spec.x, y0 + 2.0, spec.z), r_high, r_low, 4.0, mat, 14)
		if index == 0 or index == 2:
			m.smoke_points.append(Vector3(spec.x, h + 0.5, spec.z))
		# 꼭대기 테두리
		m.cylinder(Vector3(spec.x, h + 0.25, spec.z), r_top + 0.2, r_top + 0.2, 0.5, STEEL, 14, Basis.IDENTITY,
				Vector3.ZERO, false)
		index += 1
	# 굴뚝을 잇는 가로 연도 (배관)
	m.pipe_x(12.0, 34.0, 8.0, -82.0, 0.8, RUST, 10)
	m.pipe_x(12.0, 34.0, 11.0, -81.0, 0.5, STEEL, 8)


## 홀 북쪽 뒤뜰: 세로 탱크, 배관, 작은 창고 컨테이너, 루팅.
static func _north_yard(m: IndustrialMap) -> void:
	for x: float in [-30.0, -20.0]:
		m.cylinder(Vector3(x, 4.5, -82.0), 4.0, 4.0, 9.0, RUST, 18, Basis.IDENTITY, Vector3(7.2, 9.0, 7.2))
		m.cover_markers(x, -82.0, 4.0, 4.0, 0.0, 0.8)
	m.pipe_x(-30.0, -20.0, 7.0, -82.0, 0.35, STEEL, 8)
	# 부속동 옆 큰 저장 탱크 (콘셉트의 오른쪽 탱크)
	m.cylinder(Vector3(62.0, 6.5, -70.0), 9.0, 9.0, 13.0, IndustrialMaterials.CORRUGATED, 24, Basis.IDENTITY,
			Vector3(17.0, 13.0, 17.0))
	m.cylinder(Vector3(62.0, 13.2, -70.0), 9.3, 9.3, 0.5, STEEL, 24, Basis.IDENTITY, Vector3.ZERO, false)
	IndustrialProps.container(m, -38.0, -82.5, IndustrialMaterials.CONT_TEAL, 0, true)
	IndustrialProps.barrels(m, Vector3(-14.0, 0.0, -80.0), 3)
	m.loot(LootContainer.Kind.CRATE, Vector3(-25.0, 0.0, -78.0), 0.0)
