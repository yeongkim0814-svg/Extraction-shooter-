class_name KitPiecesProp
extends RefCounted
## 소품 부품. 원점 = 바닥 중심.


static func build(piece: StringName, kb: KitBuild) -> bool:
	match piece:
		&"barrel":
			barrel(kb, KitMaterials.METAL_CHIPPED)
		&"barrel_red":
			barrel(kb, KitMaterials.PIPE_RED)
		&"barrel_teal":
			barrel(kb, KitMaterials.PIPE_TEAL)
		&"pallet":
			pallet(kb)
		&"crate_wood":
			crate_wood(kb)
		&"crate_military":
			crate_military(kb)
		&"locker_steel":
			locker_steel(kb)
		&"drawer_cabinet":
			drawer_cabinet(kb)
		&"electrical_cabinet":
			electrical_cabinet(kb)
		&"cable_tray_4m":
			cable_tray_4m(kb)
		&"ladder_wall_4m":
			ladder_wall_4m(kb)
		&"lamp_wall":
			lamp_wall(kb)
		&"lamp_fluoro":
			lamp_fluoro(kb)
		&"lamp_emergency":
			lamp_emergency(kb)
		&"fire_extinguisher":
			fire_extinguisher(kb)
		&"lamp_sodium":
			lamp_sodium(kb)
		_:
			return false
	return true


## 200 L 드럼통 (지름 0.58 m, 높이 0.88 m): 둘레 감기 도장 + 테 두 줄 + 윗면 뚜껑. body = 몸통 재질 (기본 칠 벗겨진 올리브, 빨강·청록 변형).
static func barrel(kb: KitBuild, body: StringName) -> void:
	var r: float = 0.29
	var h: float = 0.88
	kb.cylinder(body, Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, 0.0)), r, h, 14, 0.02, false, false)
	for y: float in [h * 0.33, h * 0.66]:
		kb.cylinder(body, Transform3D(Basis.IDENTITY, Vector3(0.0, y, 0.0)), r + 0.012, 0.03, 14, 0.0, false, false)
	kb.cylinder(KitMaterials.FLAT_METAL, Transform3D(Basis.IDENTITY, Vector3(0.12, h + 0.008, 0.08)), 0.03, 0.016, 8, 0.0, false, false)
	kb.collide_box(Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, 0.0)), Vector3(r * 1.9, h, r * 1.9))


## 나트륨 갓 램프 (천장 매달기): 원점 = 천장 고정점, 아래로 매달린다. 빛 자리 LIGHT_sodium (전구 위치).
static func lamp_sodium(kb: KitBuild) -> void:
	kb.strut(KitMaterials.FLAT_METAL, Vector3.ZERO, Vector3(0.0, -0.9, 0.0), 0.025)
	kb.cylinder(KitMaterials.PIPE_TEAL, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.98, 0.0)), 0.07, 0.16, 10, 0.01, false, false)
	# 갓: 위가 좁고 아래가 넓은 원뿔대
	kb.use(KitMaterials.PIPE_TEAL)
	kb.mesh.add_cylinder(Transform3D(Basis.IDENTITY, Vector3(0.0, -1.14, 0.0)), 0.32, 0.18, 16, 0.0, 0.1)
	kb.cylinder(KitMaterials.FLUORO_SODIUM, Transform3D(Basis.IDENTITY, Vector3(0.0, -1.2, 0.0)), 0.06, 0.08, 10, 0.0, false, false)
	kb.marker("LIGHT_sodium", Transform3D(Basis.IDENTITY, Vector3(0.0, -1.28, 0.0)))


## 나무 팔레트 1.2 x 0.144 x 0.8: 윗판 5장(틈 있음), 받침 블록 3줄 x 3, 아랫판 3장.
static func pallet(kb: KitBuild) -> void:
	var w: StringName = KitMaterials.FLAT_WOOD
	for i: int in range(5):
		KitParts.plain(kb, w, Vector3(-0.53 + 0.265 * float(i), 0.122, 0.0), Vector3(0.14, 0.022, 0.8))
	for rz: float in [-0.34, 0.0, 0.34]:
		for bx: float in [-0.52, 0.0, 0.52]:
			KitParts.plain(kb, w, Vector3(bx, 0.022, rz), Vector3(0.14, 0.1, 0.12))
	for bx: float in [-0.53, 0.0, 0.53]:
		KitParts.plain(kb, w, Vector3(bx, 0.0, 0.0), Vector3(0.14, 0.022, 0.8))
	kb.collide_box(KitParts.at(Vector3(0.0, 0.072, 0.0)), Vector3(1.2, 0.144, 0.8))


## 나무 상자 1.0 x 0.8 x 0.8: 모서리 기둥·테두리 + 틈 있는 널 + 뚜껑 널. 루팅 가능.
static func crate_wood(kb: KitBuild) -> void:
	var w: StringName = KitMaterials.FLAT_WOOD
	var l: float = 1.0
	var h: float = 0.8
	var d: float = 0.8
	var b: float = 0.06
	# 속(어두운 심)이 널 틈으로 비친다
	KitParts.plain(kb, KitMaterials.FLAT_CONCRETE_DARK, Vector3(0.0, 0.04, 0.0), Vector3(l - 0.1, h - 0.1, d - 0.1))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			KitParts.plain(kb, w, Vector3(sx * (l * 0.5 - b * 0.5), 0.0, sz * (d * 0.5 - b * 0.5)), Vector3(b, h, b))
	# 위·아래 테두리
	for y: float in [0.0, h - b]:
		for sz: float in [-1.0, 1.0]:
			KitParts.plain(kb, w, Vector3(0.0, y, sz * (d * 0.5 - b * 0.5)), Vector3(l - b * 2.0, b, b))
		for sx: float in [-1.0, 1.0]:
			KitParts.plain(kb, w, Vector3(sx * (l * 0.5 - b * 0.5), y, 0.0), Vector3(b, b, d - b * 2.0))
	# 옆널: 가로 널 셋씩 네 면
	for i: int in range(3):
		var y: float = 0.1 + 0.2 * float(i)
		for sz: float in [-1.0, 1.0]:
			KitParts.plain(kb, w, Vector3(0.0, y, sz * (d * 0.5 - 0.01)), Vector3(l - b * 2.0, 0.15, 0.02))
		for sx: float in [-1.0, 1.0]:
			KitParts.plain(kb, w, Vector3(sx * (l * 0.5 - 0.01), y, 0.0), Vector3(0.02, 0.15, d - b * 2.0))
	# 뚜껑 널 셋
	for rz: float in [-0.26, 0.0, 0.26]:
		KitParts.plain(kb, w, Vector3(0.0, h - 0.02, rz), Vector3(l - 0.04, 0.03, 0.24))
	kb.collide_box(KitParts.at(Vector3(0.0, h * 0.5, 0.0)), Vector3(l, h, d))
	kb.marker("LOOT", KitParts.at(Vector3(0.0, h, 0.0)))
	kb.meta["loot_kind"] = "crate"


## 군용 탄약 상자 1.2 x 0.45 x 0.5: 몸통 + 뚜껑, 세로 리브, 양 끝 손잡이, 걸쇠 둘. 루팅 가능.
static func crate_military(kb: KitBuild) -> void:
	var m: StringName = KitMaterials.METAL_CHIPPED
	kb.block(m, Vector3.ZERO, Vector3(1.2, 0.32, 0.5), KitBuild.BEVEL_SMALL, false)
	kb.block(m, Vector3(0.0, 0.32, 0.0), Vector3(1.22, 0.13, 0.52), KitBuild.BEVEL_SMALL, false)
	for x: float in [-0.4, 0.0, 0.4]:
		for sz: float in [-1.0, 1.0]:
			KitParts.plain(kb, m, Vector3(x, 0.04, sz * 0.255), Vector3(0.04, 0.26, 0.015))
	var f: StringName = KitMaterials.FLAT_METAL
	for sx: float in [-1.0, 1.0]:
		KitParts.plain(kb, f, Vector3(sx * 0.62, 0.2, 0.0), Vector3(0.03, 0.025, 0.24))
		for sz: float in [-1.0, 1.0]:
			KitParts.plain(kb, f, Vector3(sx * 0.605, 0.17, sz * 0.11), Vector3(0.03, 0.05, 0.025))
	for x: float in [-0.35, 0.35]:
		KitParts.plain(kb, f, Vector3(x, 0.26, 0.265), Vector3(0.07, 0.1, 0.02))
	kb.collide_box(KitParts.at(Vector3(0.0, 0.225, 0.0)), Vector3(1.24, 0.45, 0.52))
	kb.marker("LOOT", KitParts.at(Vector3(0.0, 0.45, 0.0)))
	kb.meta["loot_kind"] = "military_crate"


## 강철 사물함 0.9 x 1.9 x 0.5 (쌍문): 회색 몸통 + 문짝 둘 + 위쪽 환기 틈 + 손잡이. 루팅 가능.
static func locker_steel(kb: KitBuild) -> void:
	kb.block(KitMaterials.CABINET_GREY, Vector3.ZERO, Vector3(0.9, 1.9, 0.5), KitBuild.BEVEL_SMALL, false)
	for sx: float in [-1.0, 1.0]:
		var x: float = sx * 0.22
		KitParts.plain(kb, KitMaterials.DOOR_STEEL, Vector3(x, 0.06, 0.25), Vector3(0.42, 1.76, 0.015))
		KitParts.plain(kb, KitMaterials.VENT, Vector3(x, 1.5, 0.265), Vector3(0.3, 0.22, 0.008))
		KitParts.plain(kb, KitMaterials.FLAT_METAL, Vector3(sx * 0.05, 0.95, 0.265), Vector3(0.025, 0.14, 0.03))
	kb.collide_box(KitParts.at(Vector3(0.0, 0.95, 0.0)), Vector3(0.9, 1.9, 0.5))
	kb.marker("LOOT", KitParts.at(Vector3(0.0, 0.95, 0.3)))
	kb.meta["loot_kind"] = "locker"


## 서류함 0.6 x 1.3 x 0.65: 서랍 넷, 손잡이. 루팅 가능.
static func drawer_cabinet(kb: KitBuild) -> void:
	kb.block(KitMaterials.CABINET_GREY, Vector3.ZERO, Vector3(0.6, 1.3, 0.65), KitBuild.BEVEL_SMALL, false)
	for i: int in range(4):
		var y: float = 0.06 + 0.305 * float(i)
		KitParts.plain(kb, KitMaterials.CABINET_GREY, Vector3(0.0, y, 0.325), Vector3(0.54, 0.28, 0.02))
		KitParts.plain(kb, KitMaterials.FLAT_METAL, Vector3(0.0, y + 0.19, 0.345), Vector3(0.2, 0.025, 0.03))
	kb.collide_box(KitParts.at(Vector3(0.0, 0.65, 0.0)), Vector3(0.6, 1.3, 0.65))
	kb.marker("LOOT", KitParts.at(Vector3(0.0, 0.65, 0.34)))
	kb.meta["loot_kind"] = "drawers"


## 전기함 0.8 x 1.8 x 0.4: 콘크리트 받침, 쌍문, 환기구·경고 표지, 위로 나가는 전선관 (0.7 m 더). 루팅 없음.
static func electrical_cabinet(kb: KitBuild) -> void:
	kb.block(KitMaterials.CONCRETE_WALL, Vector3.ZERO, Vector3(0.86, 0.1, 0.46), 0.0, false)
	kb.block(KitMaterials.CABINET_GREY, Vector3(0.0, 0.1, 0.0), Vector3(0.8, 1.7, 0.4), KitBuild.BEVEL_SMALL, false)
	for sx: float in [-1.0, 1.0]:
		KitParts.plain(kb, KitMaterials.CABINET_GREY, Vector3(sx * 0.19, 0.18, 0.2), Vector3(0.37, 1.54, 0.015))
	KitParts.plain(kb, KitMaterials.FLAT_METAL, Vector3(0.05, 0.9, 0.212), Vector3(0.025, 0.16, 0.025))
	KitParts.plain(kb, KitMaterials.VENT, Vector3(-0.19, 0.3, 0.212), Vector3(0.26, 0.2, 0.008))
	KitParts.plain(kb, KitMaterials.SIGN, Vector3(0.19, 1.3, 0.212), Vector3(0.14, 0.14, 0.008))
	kb.cylinder(KitMaterials.FLAT_METAL, KitParts.at(Vector3(-0.25, 2.15, 0.0)), 0.035, 0.7, 8, 0.0, false, false)
	kb.collide_box(KitParts.at(Vector3(0.0, 0.9, 0.0)), Vector3(0.86, 1.8, 0.46))


## 케이블 트레이 4 m x 0.4 x 0.1: 격자 바닥 + 옆판 + 케이블 가닥, 양 끝 달대 0.6 m. 원점 = 트레이 바닥 가운데. 충돌 없음.
static func cable_tray_4m(kb: KitBuild) -> void:
	kb.block(KitMaterials.GRATE, Vector3.ZERO, Vector3(4.0, 0.012, 0.4), 0.0, false)
	for sz: float in [-1.0, 1.0]:
		KitParts.plain(kb, KitMaterials.FLAT_METAL, Vector3(0.0, 0.0, sz * 0.2), Vector3(4.0, 0.1, 0.015))
	var zs: Array[float] = [-0.1, 0.0, 0.09]
	for i: int in range(3):
		KitParts.cyl_x(kb, KitMaterials.CABLE, Vector3(0.0, 0.035, zs[i]), 0.022, 3.96, 8)
	for sx: float in [-1.0, 1.0]:
		var x: float = sx * 1.85
		for sz: float in [-1.0, 1.0]:
			kb.cylinder(KitMaterials.FLAT_METAL, KitParts.at(Vector3(x, 0.35, sz * 0.2)), 0.01, 0.7, 6, 0.0, false, false)
		KitParts.plain(kb, KitMaterials.FLAT_METAL, Vector3(x, -0.02, 0.0), Vector3(0.05, 0.02, 0.44))
		KitParts.plain(kb, KitMaterials.FLAT_METAL, Vector3(x, 0.68, 0.0), Vector3(0.1, 0.02, 0.44))


## 벽 사다리 4 m x 0.5: 노란 세로대 둘, 0.3 m마다 쇠 가로대, 벽 고정쇠. 벽 면 = z 0, 사다리는 +Z로 0.15 띄운다.
static func ladder_wall_4m(kb: KitBuild) -> void:
	var zr: float = 0.16
	for sx: float in [-1.0, 1.0]:
		kb.block(KitMaterials.BEAM_YELLOW, Vector3(sx * 0.25, 0.0, zr), Vector3(0.04, 4.0, 0.04), 0.0, false)
	for i: int in range(13):
		kb.block(KitMaterials.FLAT_METAL, Vector3(0.0, 0.2 + 0.3 * float(i), zr), Vector3(0.5, 0.025, 0.025), 0.0, false)
	for y: float in [0.5, 1.7, 2.9, 3.7]:
		for sx: float in [-1.0, 1.0]:
			kb.block(KitMaterials.FLAT_METAL, Vector3(sx * 0.25, y, zr * 0.5 - 0.01), Vector3(0.03, 0.04, zr - 0.02), 0.0, false)
			kb.block(KitMaterials.FLAT_METAL, Vector3(sx * 0.25, y, 0.0), Vector3(0.07, 0.07, 0.01), 0.0, false)
	kb.collide_box(KitParts.at(Vector3(0.0, 2.0, 0.09)), Vector3(0.5, 4.0, 0.16))


## 벽등(방폭등): 원점 = 벽 고정점, +Z로 튀어나온다. 빛 자리 LIGHT_wall.
static func lamp_wall(kb: KitBuild) -> void:
	KitParts.slab(kb, KitMaterials.FLAT_METAL, Vector3(0.0, 0.0, 0.015), Vector3(0.2, 0.16, 0.03))
	kb.box(KitMaterials.FLAT_METAL, KitParts.at(Vector3(0.0, 0.0, 0.08)), Vector3(0.18, 0.12, 0.1), 0.03, false)
	kb.box(KitMaterials.FLUORO_SODIUM, KitParts.at(Vector3(0.0, 0.0, 0.14)), Vector3(0.14, 0.09, 0.03), 0.0, false)
	for sx: float in [-1.0, 1.0]:
		kb.strut(KitMaterials.FLAT_METAL, Vector3(sx * 0.06, -0.05, 0.16), Vector3(sx * 0.06, 0.05, 0.16), 0.012)
	kb.marker("LIGHT_wall", KitParts.at(Vector3(0.0, 0.0, 0.17)))


## 천장 형광등 1.3 m: 원점 = 천장 고정점, 사슬 0.4 m로 매달린다. 빛 자리 LIGHT_fluoro.
static func lamp_fluoro(kb: KitBuild) -> void:
	for sx: float in [-1.0, 1.0]:
		kb.strut(KitMaterials.FLAT_METAL, Vector3(sx * 0.5, 0.0, 0.0), Vector3(sx * 0.5, -0.4, 0.0), 0.012)
		KitParts.slab(kb, KitMaterials.FLAT_METAL, Vector3(sx * 0.5, -0.005, 0.0), Vector3(0.06, 0.01, 0.06))
	kb.box(KitMaterials.FLAT_METAL, KitParts.at(Vector3(0.0, -0.435, 0.0)), Vector3(1.3, 0.07, 0.16), 0.0, false)
	KitParts.cyl_x(kb, KitMaterials.FLUORO, Vector3(0.0, -0.49, 0.0), 0.02, 1.2, 8)
	kb.marker("LIGHT_fluoro", KitParts.at(Vector3(0.0, -0.52, 0.0)))


## 비상등 0.35 x 0.15 x 0.1: 원점 = 벽 고정점, +Z로 튀어나온다. 회색 상자 + 파란 발광 렌즈 둘. 빛 자리 LIGHT_emergency.
static func lamp_emergency(kb: KitBuild) -> void:
	kb.box(KitMaterials.CABINET_GREY, KitParts.at(Vector3(0.0, 0.0, 0.05)), Vector3(0.35, 0.15, 0.1), 0.015, false)
	for sx: float in [-1.0, 1.0]:
		kb.box(KitMaterials.EMERGENCY, KitParts.at(Vector3(sx * 0.1, 0.0, 0.105)), Vector3(0.09, 0.07, 0.02), 0.0, false)
	kb.marker("LIGHT_emergency", KitParts.at(Vector3(0.0, 0.0, 0.13)))


## 소화기 0.6 m: 빨간 몸통, 쇠 목·밸브, 호스, 벽 받침(뒤 -Z). 원점 = 몸통 바닥 가운데.
static func fire_extinguisher(kb: KitBuild) -> void:
	kb.cylinder(KitMaterials.PIPE_RED, KitParts.at(Vector3(0.0, 0.24, 0.0)), 0.08, 0.48, 10, 0.02, false, false)
	kb.cylinder(KitMaterials.FLAT_METAL, KitParts.at(Vector3(0.0, 0.52, 0.0)), 0.025, 0.08, 8, 0.0, false, false)
	kb.block(KitMaterials.FLAT_METAL, Vector3(0.0, 0.54, 0.0), Vector3(0.1, 0.045, 0.04), 0.0, false)
	kb.strut(KitMaterials.FLAT_METAL, Vector3(0.05, 0.58, 0.0), Vector3(-0.04, 0.6, 0.0), 0.02)
	var hose: Array[Vector3] = [Vector3(0.05, 0.54, 0.0), Vector3(0.11, 0.48, 0.0), Vector3(0.115, 0.34, 0.0), Vector3(0.09, 0.22, 0.0)]
	for i: int in range(hose.size() - 1):
		kb.strut(KitMaterials.FLAT_RUBBER, hose[i], hose[i + 1], 0.018)
	KitParts.plain(kb, KitMaterials.FLAT_METAL, Vector3(0.0, 0.1, -0.1), Vector3(0.12, 0.3, 0.02))
	kb.cylinder(KitMaterials.FLAT_METAL, KitParts.at(Vector3(0.0, 0.3, 0.0)), 0.088, 0.03, 10, 0.0, false, false)
	kb.collide_box(KitParts.at(Vector3(0.0, 0.3, -0.02)), Vector3(0.2, 0.6, 0.24))
