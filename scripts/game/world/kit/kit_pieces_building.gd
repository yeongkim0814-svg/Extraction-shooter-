class_name KitPiecesBuilding
extends RefCounted
## 건물 모듈 부품 (4 m 그리드). 넓은 면은 단색 재질(조용한 면), 띠·모서리·턱만 트림 재질 (ART.md 11.3).
## 벽 규약: 벽 두께 중심선이 X축, 앞면(바깥) = +Z, 원점 = 아래 가운데. 높이 4 m (공장 홀은 두 단 쌓기).

const WALL_W: float = 4.0
const WALL_H: float = 4.0
const WALL_T: float = 0.35
## 아래 굽(걸레받이) 높이·돌출, 위 갓돌 높이·돌출.
const PLINTH_H: float = 0.6
const PLINTH_OUT: float = 0.03
const CAP_H: float = 0.18
const CAP_OUT: float = 0.05


static func build(piece: StringName, kb: KitBuild) -> bool:
	match piece:
		&"wall_4m":
			wall_4m(kb)
		&"wall_4m_window":
			wall_4m_window(kb)
		&"wall_4m_door":
			wall_4m_door(kb)
		&"door_steel":
			door_steel(kb)
		&"wall_4m_shutter":
			wall_4m_shutter(kb)
		&"wall_4m_damaged":
			wall_4m_damaged(kb)
		&"wall_corner":
			wall_corner(kb)
		&"pillar_steel":
			pillar_steel(kb)
		&"roof_truss_8m":
			roof_truss_8m(kb)
		&"roof_panel_4m":
			roof_panel_4m(kb)
		&"skylight_4m":
			skylight_4m(kb)
		&"floor_slab_4m":
			floor_slab_4m(kb)
		&"stairs_steel_2m":
			stairs_steel_2m(kb)
		&"catwalk_4m":
			catwalk_4m(kb)
		&"railing_4m":
			railing_4m(kb)
		&"loading_dock_4m":
			loading_dock_4m(kb)
		_:
			return false
	return true


## 기본 벽 4 m: 콘크리트 굽 + 단색 몸통 + 갓돌. 이어 붙임 자리 SNAP_L/SNAP_R.
static func wall_4m(kb: KitBuild) -> void:
	wall_shell(kb, 0.0, WALL_H)
	kb.collide_box(Transform3D(Basis.IDENTITY, Vector3(0.0, WALL_H * 0.5, 0.0)), Vector3(WALL_W, WALL_H, WALL_T))
	kb.marker("SNAP_L", Transform3D(Basis.IDENTITY, Vector3(-WALL_W * 0.5, 0.0, 0.0)))
	kb.marker("SNAP_R", Transform3D(Basis.IDENTITY, Vector3(WALL_W * 0.5, 0.0, 0.0)))


## 벽 겉모양 (충돌 없음): y0..y1 구간에 굽(y0 = 0일 때만)·몸통·갓돌(y1 = WALL_H일 때만).
static func wall_shell(kb: KitBuild, y0: float, y1: float, x0: float = -WALL_W * 0.5, x1: float = WALL_W * 0.5) -> void:
	var w: float = x1 - x0
	var cx: float = (x0 + x1) * 0.5
	var body_lo: float = y0
	var body_hi: float = y1
	if y0 <= 0.0:
		kb.block(KitMaterials.CONCRETE_WALL, Vector3(cx, 0.0, 0.0), Vector3(w, PLINTH_H, WALL_T + PLINTH_OUT * 2.0), -1.0, false,
				KitLayout.SILL)
		body_lo = PLINTH_H
	if y1 >= WALL_H:
		kb.block(KitMaterials.SILL, Vector3(cx, WALL_H - CAP_H, 0.0), Vector3(w, CAP_H, WALL_T + CAP_OUT * 2.0), -1.0, false)
		body_hi = WALL_H - CAP_H
	if body_hi > body_lo:
		kb.block(KitMaterials.FLAT_CONCRETE, Vector3(cx, body_lo, 0.0), Vector3(w, body_hi - body_lo, WALL_T), 0.0, false)


## 벽 모듈 공통: 이어 붙임 자리.
static func _snap(kb: KitBuild, half: float = WALL_W * 0.5) -> void:
	kb.marker("SNAP_L", KitParts.at(Vector3(-half, 0.0, 0.0)))
	kb.marker("SNAP_R", KitParts.at(Vector3(half, 0.0, 0.0)))


## 창 벽: 구멍 2.4 x 1.5, 창턱 높이 1.2. 강철 틀 + 십자 창살 + 유리(일부 깨짐/없음) + 튀어나온 콘크리트 턱.
static func wall_4m_window(kb: KitBuild) -> void:
	var x0: float = -1.2
	var x1: float = 1.2
	var y0: float = 1.2
	var y1: float = 2.7
	_opening_shell(kb, x0, x1, y0, y1)
	_collide_opening(kb, x0, x1, y0, y1)
	# 강철 틀 (구멍 안쪽에 맞춰 두름) + 십자 창살
	var fw: float = 0.06
	KitParts.frame(kb, KitMaterials.METAL_PLATE, x0, x1, y0, y1, fw, 0.14)
	KitParts.slab(kb, KitMaterials.METAL_PLATE, Vector3(0.0, (y0 + y1) * 0.5, 0.0), Vector3(0.05, y1 - y0, 0.08))
	KitParts.slab(kb, KitMaterials.METAL_PLATE, Vector3(0.0, (y0 + y1) * 0.5, 0.0), Vector3(x1 - x0, 0.05, 0.08))
	# 유리: 왼쪽 위·아래 온전, 오른쪽 위는 깨져 삼각 조각만, 오른쪽 아래는 없음
	var cy: float = (y0 + y1) * 0.5
	var pw: float = (x1 - x0) * 0.5 - 0.05
	var ph: float = (y1 - y0) * 0.5 - 0.05
	KitParts.slab(kb, KitMaterials.FLAT_GLASS, Vector3(-pw * 0.5 - 0.025, cy + ph * 0.5 + 0.025, 0.0), Vector3(pw, ph, 0.012))
	KitParts.slab(kb, KitMaterials.FLAT_GLASS, Vector3(-pw * 0.5 - 0.025, cy - ph * 0.5 - 0.025, 0.0), Vector3(pw, ph, 0.012))
	var cx: float = pw * 0.5 + 0.025
	var cyu: float = cy + ph * 0.5 + 0.025
	var shard := PackedVector2Array([Vector2(-pw * 0.5, -ph * 0.5), Vector2(pw * 0.5, -ph * 0.5), Vector2(-pw * 0.1, ph * 0.45)])
	kb.prism(KitMaterials.FLAT_GLASS, KitParts.at(Vector3(cx, cyu, 0.0)), shard, 0.012)
	var shard2 := PackedVector2Array([Vector2(pw * 0.5, ph * 0.5), Vector2(pw * 0.5, ph * 0.1), Vector2(pw * 0.15, ph * 0.5)])
	kb.prism(KitMaterials.FLAT_GLASS, KitParts.at(Vector3(cx, cyu, 0.0)), shard2, 0.012)
	# 콘크리트 턱 (바깥으로 튀어나옴). 윗면이 벽 아래 조각 윗면(1.2)과 겹치지 않게 1 cm 올린다
	kb.block(KitMaterials.SILL, Vector3(0.0, y0 - 0.07, 0.15), Vector3(x1 - x0 + 0.24, 0.08, 0.5), 0.0, false)
	_snap(kb)


## 문 벽: 틈 1.0 x 2.1 (x = +1.0). 강철 문틀 + 콘크리트 인방. 문짝은 따로 (door_steel).
static func wall_4m_door(kb: KitBuild) -> void:
	var cx: float = 1.0
	var fw: float = 0.07
	var x0: float = cx - 0.5 - fw
	var x1: float = cx + 0.5 + fw
	var top: float = 2.1 + fw
	_opening_shell(kb, x0, x1, 0.0, top)
	_collide_opening(kb, x0, x1, 0.0, top)
	KitParts.frame(kb, KitMaterials.DOOR_STEEL, cx - 0.5, cx + 0.5, 0.0, 2.1, fw, WALL_T + 0.02, 0.0, false)
	# 콘크리트 인방: 문틀 위, 벽 양쪽으로 약간 튀어나옴
	kb.block(KitMaterials.SILL, Vector3(cx, top, 0.0), Vector3(1.5, 0.14, WALL_T + 0.08), 0.0, false)
	_snap(kb)


## 구멍 둘레 벽 겉모양만 (충돌 없음). y0 <= 0이면 문.
static func _opening_shell(kb: KitBuild, x0: float, x1: float, y0: float, y1: float) -> void:
	wall_shell(kb, 0.0, WALL_H, -WALL_W * 0.5, x0)
	wall_shell(kb, 0.0, WALL_H, x1, WALL_W * 0.5)
	if y0 > 0.001:
		wall_shell(kb, 0.0, y0, x0, x1)
	wall_shell(kb, y1, WALL_H, x0, x1)


## 구멍 둘레 충돌 상자.
static func _collide_opening(kb: KitBuild, x0: float, x1: float, y0: float, y1: float) -> void:
	var hw: float = WALL_W * 0.5
	kb.collide_box(KitParts.at(Vector3((-hw + x0) * 0.5, WALL_H * 0.5, 0.0)), Vector3(x0 + hw, WALL_H, WALL_T))
	kb.collide_box(KitParts.at(Vector3((x1 + hw) * 0.5, WALL_H * 0.5, 0.0)), Vector3(hw - x1, WALL_H, WALL_T))
	if y0 > 0.001:
		kb.collide_box(KitParts.at(Vector3((x0 + x1) * 0.5, y0 * 0.5, 0.0)), Vector3(x1 - x0, y0, WALL_T))
	kb.collide_box(KitParts.at(Vector3((x0 + x1) * 0.5, (y1 + WALL_H) * 0.5, 0.0)), Vector3(x1 - x0, WALL_H - y1, WALL_T))


## 강철 문짝 0.95 x 2.08 x 0.05. 원점 = 경첩 쪽 아래 (Y축으로 돌릴 수 있게). 문짝은 +X로 뻗는다.
static func door_steel(kb: KitBuild) -> void:
	var w: float = 0.95
	var h: float = 2.08
	var t: float = 0.05
	kb.block(KitMaterials.DOOR_STEEL, Vector3(w * 0.5, 0.0, 0.0), Vector3(w, h, t), 0.0, true)
	# 손잡이 (양면) + 잠금판, 경첩 세 개
	for sz: float in [-1.0, 1.0]:
		KitParts.slab(kb, KitMaterials.FLAT_METAL, Vector3(w - 0.12, 1.0, sz * (t * 0.5 + 0.02)), Vector3(0.14, 0.03, 0.025))
		KitParts.slab(kb, KitMaterials.FLAT_METAL, Vector3(w - 0.06, 1.0, sz * (t * 0.5 + 0.01)), Vector3(0.05, 0.14, 0.02))
	for y: float in [0.25, 1.04, 1.83]:
		kb.cylinder(KitMaterials.FLAT_METAL, KitParts.at(Vector3(0.0, y, 0.0)), 0.022, 0.12, 8, 0.0, false, false)


## 셔터 벽: 구멍 3.2 x 3.4, 말아 올린 셔터가 반쯤 열림 (아랫단 1.1 m). 위에 말이통, 양옆 레일, 문턱에 경고 띠.
static func wall_4m_shutter(kb: KitBuild) -> void:
	var x0: float = -1.6
	var x1: float = 1.6
	var top: float = 3.4
	_opening_shell(kb, x0, x1, 0.0, top)
	# 충돌: 양옆·위 + 셔터 커튼 (1.1 m 아래로 숙여 지나갈 수 있다)
	_collide_opening(kb, x0, x1, 0.0, top)
	# 셔터 커튼: 슬랫 띠 네 장을 쌓아 줄이 늘어지지 않게
	var bottom: float = 1.1
	var segs: int = 4
	var seg_h: float = (3.3 - bottom) / float(segs)
	for i: int in range(segs):
		KitParts.plain(kb, KitMaterials.SHUTTER, Vector3(0.0, bottom + seg_h * float(i), 0.0), Vector3(x1 - x0 - 0.16, seg_h, 0.04))
	KitParts.plain(kb, KitMaterials.FLAT_METAL, Vector3(0.0, bottom - 0.08, 0.0), Vector3(x1 - x0 - 0.12, 0.08, 0.08))
	kb.collide_box(KitParts.at(Vector3(0.0, (bottom + 3.3) * 0.5, 0.0)), Vector3(x1 - x0, 3.3 - bottom, 0.08))
	# 말이통 (벽 바깥쪽 위)
	kb.block(KitMaterials.METAL_PLATE, Vector3(0.0, 3.3, 0.16), Vector3(x1 - x0 + 0.3, 0.45, 0.3), KitBuild.BEVEL_SMALL, false)
	# 양옆 레일
	for sx: float in [-1.0, 1.0]:
		KitParts.plain(kb, KitMaterials.FLAT_METAL, Vector3(sx * (x1 - 0.04), 0.0, 0.0), Vector3(0.08, 3.3, 0.16))
	# 문턱 경고 띠
	KitParts.plain(kb, KitMaterials.HAZARD, Vector3(0.0, 0.0, 0.34), Vector3(x1 - x0, 0.02, 0.3))
	_snap(kb)


## 파손 벽: wall_4m와 같은 외곽 + 들쭉날쭉한 구멍 (약 1.65 x 1.45) + 바닥 잔해. 구멍 모양은 고정.
static func wall_4m_damaged(kb: KitBuild) -> void:
	# 구멍 외곽 (반시계). 인덱스 0 = 가장 왼쪽, 5 = 가장 오른쪽 꼭짓점. 0..5 = 아래 사슬, 5..10..0 = 위 사슬
	var hole: Array[Vector2] = [Vector2(-0.7, 1.75), Vector2(-0.55, 1.3), Vector2(-0.1, 1.05), Vector2(0.35, 1.2), Vector2(0.9, 1.0),
			Vector2(0.95, 1.7), Vector2(0.7, 2.1), Vector2(0.75, 2.4), Vector2(0.2, 2.25), Vector2(-0.15, 2.45), Vector2(-0.5, 2.15)]
	var lo_x: float = hole[0].x
	var hi_x: float = hole[5].x
	var body_lo: float = PLINTH_H
	var body_hi: float = WALL_H - CAP_H
	wall_shell(kb, 0.0, WALL_H, -WALL_W * 0.5, lo_x)
	wall_shell(kb, 0.0, WALL_H, hi_x, WALL_W * 0.5)
	wall_shell(kb, 0.0, body_lo, lo_x, hi_x)
	wall_shell(kb, body_hi, WALL_H, lo_x, hi_x)
	# 가운데 열: 구멍 아래 / 위 다각형 두 개로 압출
	var below := PackedVector2Array([Vector2(lo_x, body_lo), Vector2(hi_x, body_lo)])
	for i: int in range(5, -1, -1):
		below.append(hole[i])
	var above := PackedVector2Array()
	for i: int in range(5, hole.size()):
		above.append(hole[i])
	above.append(hole[0])
	above.append(Vector2(lo_x, body_hi))
	above.append(Vector2(hi_x, body_hi))
	kb.prism(KitMaterials.FLAT_CONCRETE, KitParts.at(Vector3.ZERO), KitParts.ccw(below), WALL_T)
	kb.prism(KitMaterials.FLAT_CONCRETE, KitParts.at(Vector3.ZERO), KitParts.ccw(above), WALL_T)
	# 구멍 가장자리에 삐져나온 녹슨 철근
	kb.strut(KitMaterials.RUST, Vector3(0.9, 1.05, 0.05), Vector3(1.1, 1.5, 0.35), 0.025)
	kb.strut(KitMaterials.RUST, Vector3(-0.5, 2.15, 0.0), Vector3(-0.6, 2.7, 0.3), 0.025)
	kb.strut(KitMaterials.RUST, Vector3(0.3, 1.2, 0.05), Vector3(0.1, 1.6, 0.45), 0.025)
	# 충돌: 양옆 기둥, 구멍 아래(최저 1.0)·위(최고 2.45)는 통짜로
	var hw: float = WALL_W * 0.5
	kb.collide_box(KitParts.at(Vector3((-hw + lo_x) * 0.5, WALL_H * 0.5, 0.0)), Vector3(lo_x + hw, WALL_H, WALL_T))
	kb.collide_box(KitParts.at(Vector3((hi_x + hw) * 0.5, WALL_H * 0.5, 0.0)), Vector3(hw - hi_x, WALL_H, WALL_T))
	kb.collide_box(KitParts.at(Vector3((lo_x + hi_x) * 0.5, 0.5, 0.0)), Vector3(hi_x - lo_x, 1.0, WALL_T))
	kb.collide_box(KitParts.at(Vector3((lo_x + hi_x) * 0.5, (2.45 + WALL_H) * 0.5, 0.0)), Vector3(hi_x - lo_x, WALL_H - 2.45, WALL_T))
	# 바닥 잔해 (앞쪽 +Z)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4101
	for i: int in range(7):
		var size := Vector3(rng.randf_range(0.2, 0.45), rng.randf_range(0.12, 0.28), rng.randf_range(0.2, 0.4))
		KitParts.chunk(kb, KitMaterials.FLAT_CONCRETE_DARK, rng, Vector2(rng.randf_range(-0.9, 1.3), rng.randf_range(0.35, 0.85)),
				size, 0.0, 22.0, i % 3 == 0)
	kb.collide_box(KitParts.at(Vector3(0.2, 0.15, 0.6)), Vector3(2.0, 0.3, 0.7))
	_snap(kb)


## 모서리 기둥 0.5 x 4.0 x 0.5: 굽 + 몸통 + 갓돌 (wall_4m와 같은 띠).
static func wall_corner(kb: KitBuild) -> void:
	var s: float = 0.5
	kb.block(KitMaterials.CONCRETE_WALL, Vector3.ZERO, Vector3(s + PLINTH_OUT * 2.0, PLINTH_H, s + PLINTH_OUT * 2.0), -1.0, false,
			KitLayout.SILL)
	kb.block(KitMaterials.FLAT_CONCRETE, Vector3(0.0, PLINTH_H, 0.0), Vector3(s, WALL_H - CAP_H - PLINTH_H, s), 0.0, false)
	kb.block(KitMaterials.SILL, Vector3(0.0, WALL_H - CAP_H, 0.0), Vector3(s + CAP_OUT * 2.0, CAP_H, s + CAP_OUT * 2.0), -1.0, false)
	kb.collide_box(KitParts.at(Vector3(0.0, WALL_H * 0.5, 0.0)), Vector3(s, WALL_H, s))
	_snap(kb, s * 0.5)


## 철골 H 기둥 4 m: 바닥판(볼트 머리 넷) + 웹·플랜지 + 머리판.
static func pillar_steel(kb: KitBuild) -> void:
	var plate: float = 0.04
	kb.block(KitMaterials.METAL_PLATE, Vector3.ZERO, Vector3(0.5, plate, 0.5), 0.0, false)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			kb.cylinder(KitMaterials.FLAT_METAL, KitParts.at(Vector3(sx * 0.2, plate + 0.03, sz * 0.2)), 0.02, 0.06, 6, 0.0, false, false)
	var h: float = WALL_H - plate * 2.0
	# H 단면: 플랜지 둘 (Z 양쪽), 웹 하나 (가운데)
	for sz: float in [-1.0, 1.0]:
		kb.block(KitMaterials.BEAM_TEAL, Vector3(0.0, plate, sz * 0.135), Vector3(0.3, h, 0.03), 0.0, false)
	kb.block(KitMaterials.BEAM_TEAL, Vector3(0.0, plate, 0.0), Vector3(0.03, h, 0.24), 0.0, false)
	kb.block(KitMaterials.METAL_PLATE, Vector3(0.0, WALL_H - plate, 0.0), Vector3(0.42, plate, 0.42), 0.0, false)
	kb.collide_box(KitParts.at(Vector3(0.0, WALL_H * 0.5, 0.0)), Vector3(0.3, WALL_H, 0.3))


## 지붕 트러스 8 m (X): 아래 현은 y = 0, 가운데 높이 1.2 m. 위 현·수직재·사재. 충돌 없음 (머리 위).
static func roof_truss_8m(kb: KitBuild) -> void:
	var t: float = 0.1
	var hh: float = 0.05
	var peak: float = 1.15
	var m: StringName = KitMaterials.BEAM_TEAL
	var bottom: Array[Vector3] = []
	var top: Array[Vector3] = []
	for i: int in range(5):
		var x: float = -4.0 + 2.0 * float(i)
		bottom.append(Vector3(x, hh, 0.0))
		top.append(Vector3(x, hh + (peak - hh) * (1.0 - absf(x) / 4.0), 0.0))
	kb.strut(m, bottom[0], bottom[4], t)
	for i: int in range(4):
		kb.strut(m, top[i], top[i + 1], t)
	for i: int in range(1, 4):
		kb.strut(m, bottom[i], top[i], t * 0.8)
	# 사재: 바깥쪽 아래 -> 위, 가운데 위 -> 아래 쪽으로 지그재그
	kb.strut(m, bottom[0], top[1], t * 0.8)
	kb.strut(m, top[1], bottom[2], t * 0.8)
	kb.strut(m, bottom[2], top[3], t * 0.8)
	kb.strut(m, top[3], bottom[4], t * 0.8)
	# 양 끝 받침판
	for sx: float in [-1.0, 1.0]:
		kb.block(KitMaterials.METAL_PLATE, Vector3(sx * 3.9, -0.02, 0.0), Vector3(0.3, 0.04, 0.3), 0.0, false)


## 지붕판 4 x 4 x 0.12: 윗면 FLAT_ROOF, 아랫면 골함석 (면마다 얇은 상자 따로).
static func roof_panel_4m(kb: KitBuild) -> void:
	kb.block(KitMaterials.METAL_CORRUGATED_TEAL, Vector3.ZERO, Vector3(4.0, 0.03, 4.0), 0.0, false)
	kb.block(KitMaterials.FLAT_METAL, Vector3(0.0, 0.03, 0.0), Vector3(3.96, 0.04, 3.96), 0.0, false)
	kb.block(KitMaterials.FLAT_ROOF, Vector3(0.0, 0.07, 0.0), Vector3(4.0, 0.05, 4.0), 0.0, false)
	kb.collide_box(KitParts.at(Vector3(0.0, 0.06, 0.0)), Vector3(4.0, 0.12, 4.0))


## 천창 4 x 4: 틀(FLAT_METAL) + 2 x 2 유리 (한 장 없음 -> 빛줄기가 들어온다).
static func skylight_4m(kb: KitBuild) -> void:
	var bar: float = 0.12
	var fh: float = 0.12
	var m: StringName = KitMaterials.FLAT_METAL
	KitParts.plain(kb, m, Vector3(0.0, 0.0, -2.0 + bar * 0.5), Vector3(4.0, fh, bar))
	KitParts.plain(kb, m, Vector3(0.0, 0.0, 2.0 - bar * 0.5), Vector3(4.0, fh, bar))
	KitParts.plain(kb, m, Vector3(-2.0 + bar * 0.5, 0.0, 0.0), Vector3(bar, fh, 4.0 - bar * 2.0))
	KitParts.plain(kb, m, Vector3(2.0 - bar * 0.5, 0.0, 0.0), Vector3(bar, fh, 4.0 - bar * 2.0))
	KitParts.plain(kb, m, Vector3.ZERO, Vector3(0.08, fh, 4.0 - bar * 2.0))
	KitParts.plain(kb, m, Vector3.ZERO, Vector3(4.0 - bar * 2.0, fh, 0.08))
	var pane: float = (4.0 - bar * 2.0 - 0.08) * 0.5
	var c: float = 0.04 + pane * 0.5
	# 유리: (-,-) (-,+) (+,-) 세 장. (+,+)는 없음
	for p: Vector2 in [Vector2(-c, -c), Vector2(-c, c), Vector2(c, -c)]:
		KitParts.slab(kb, KitMaterials.FLAT_GLASS, Vector3(p.x, fh * 0.5, p.y), Vector3(pane, 0.012, pane))


## 바닥 슬래브 4 x 4 x 0.3: 옆면 콘크리트 벽 재질 + 윗면 바닥 콘크리트 (살짝 들어간 턱).
static func floor_slab_4m(kb: KitBuild) -> void:
	kb.block(KitMaterials.CONCRETE_WALL, Vector3.ZERO, Vector3(4.0, 0.28, 4.0), KitBuild.BEVEL_SMALL, false)
	kb.block(KitMaterials.GROUND_CONCRETE, Vector3(0.0, 0.28, 0.0), Vector3(3.96, 0.02, 3.96), 0.0, false)
	kb.collide_box(KitParts.at(Vector3(0.0, 0.15, 0.0)), Vector3(4.0, 0.3, 4.0))


## 철제 직선 계단: 높이 2.0 m, 디딤판 10장 x 0.31 m = 3.1 m, 폭 1.0 m, 챌판 11단. 원점 = 맨 아래 앞(+Z로 올라간다), 위에 0.8 m 승강대.
## 디딤판 TREAD, 옆보 BEAM_YELLOW, 한쪽(+X) 손잡이.
static func stairs_steel_2m(kb: KitBuild) -> void:
	var rise: float = 2.0 / 11.0
	var run: float = 0.31
	var width: float = 1.0
	var slope: float = rise / run
	for k: int in range(1, 11):
		var z0: float = float(k - 1) * run
		kb.block(KitMaterials.TREAD, Vector3(0.0, float(k) * rise - 0.04, z0 + run * 0.5 - 0.01), Vector3(width - 0.08, 0.04, run + 0.04), 0.0, false)
	# 위 승강대
	kb.block(KitMaterials.TREAD, Vector3(0.0, 2.0 - 0.04, 3.1 + 0.4 - 0.01), Vector3(width - 0.08, 0.04, 0.82), 0.0, false)
	# 옆보: 코 끝선 바로 아래를 따라 기울인 상자
	var dir := Vector3(0.0, rise * 10.0, run * 10.0)
	var length: float = dir.length()
	var basis := Basis.looking_at(dir.normalized(), Vector3.UP)
	var drop: float = 0.1 / cos(atan(slope))
	var center := Vector3(0.0, rise + dir.y * 0.5 - drop, dir.z * 0.5)
	for sx: float in [-1.0, 1.0]:
		kb.box(KitMaterials.BEAM_YELLOW, Transform3D(basis, center + Vector3(sx * (width * 0.5 - 0.02), 0.0, 0.0)),
				Vector3(0.04, 0.2, length + 0.1), 0.0, false)
		kb.block(KitMaterials.BEAM_YELLOW, Vector3(sx * (width * 0.5 - 0.02), 1.8, 3.5), Vector3(0.04, 0.2, 0.8), 0.0, false)
	# 손잡이 (+X): 경사 구간 + 승강대 구간
	var hx: float = width * 0.5 - 0.02
	var hr: float = 0.9
	var a := Vector3(hx, rise + hr, 0.0)
	var b := Vector3(hx, rise + dir.y + hr, dir.z)
	kb.strut(KitMaterials.FLAT_METAL, a, b, 0.045)
	kb.strut(KitMaterials.FLAT_METAL, b, Vector3(hx, b.y, 3.9), 0.045)
	for pz: float in [0.0, 1.0, 2.0, 3.1, 3.9]:
		var py: float = rise + slope * minf(pz, 3.1)
		kb.strut(KitMaterials.FLAT_METAL, Vector3(hx, py - 0.02, pz), Vector3(hx, py + hr, pz), 0.035)
	# 충돌: 경사 상자 (윗면 = 코 끝선) + 승강대
	var cbasis := Basis.looking_at(Vector3(0.0, slope, 1.0).normalized(), Vector3.UP)
	kb.collide_box(Transform3D(cbasis, Vector3(0.0, rise + dir.y * 0.5 - 0.06 / cos(atan(slope)), dir.z * 0.5)), Vector3(width, 0.12, length))
	kb.collide_box(KitParts.at(Vector3(0.0, 1.95, 3.5)), Vector3(width, 0.1, 0.8))


## 캣워크 4 m x 폭 1.2: 원점 = 보행면 가운데 (윗면이 y = 0). 격자 바닥, 노란 옆보, 양쪽 난간 1.05 m, 발끝막이.
static func catwalk_4m(kb: KitBuild) -> void:
	var span: float = 4.0
	kb.block(KitMaterials.GRATE, Vector3(0.0, -0.05, 0.0), Vector3(span, 0.05, 1.14), 0.0, true, KitLayout.GRATE)
	for sz: float in [-1.0, 1.0]:
		var z: float = sz * 0.58
		kb.block(KitMaterials.BEAM_YELLOW, Vector3(0.0, -0.17, z), Vector3(span, 0.17, 0.05), 0.0, false)
		kb.block(KitMaterials.BEAM_YELLOW, Vector3(0.0, 0.0, z), Vector3(span, 0.1, 0.02), 0.0, false)
		KitParts.railing(kb, KitMaterials.BEAM_YELLOW, Vector3(-span * 0.5 + 0.03, 0.0, z), Vector3(span * 0.5 - 0.03, 0.0, z))
		kb.collide_box(KitParts.at(Vector3(0.0, 0.525, z)), Vector3(span, 1.05, 0.05))
	for x: float in [-1.97, 0.0, 1.97]:
		kb.block(KitMaterials.BEAM_YELLOW, Vector3(x, -0.15, 0.0), Vector3(0.06, 0.1, 1.14), 0.0, false)


## 독립 난간 4 m: 높이 1.05 m, 기둥 셋 (끝 + 가운데), 발판 판.
static func railing_4m(kb: KitBuild) -> void:
	KitParts.railing(kb, KitMaterials.BEAM_YELLOW, Vector3(-1.97, 0.0, 0.0), Vector3(1.97, 0.0, 0.0))
	for x: float in [-1.97, 0.0, 1.97]:
		kb.block(KitMaterials.BEAM_YELLOW, Vector3(x, 0.0, 0.0), Vector3(0.14, 0.02, 0.14), 0.0, false)
	kb.block(KitMaterials.BEAM_YELLOW, Vector3(0.0, 0.0, 0.0), Vector3(3.94, 0.1, 0.02), 0.0, false)
	kb.collide_box(KitParts.at(Vector3(0.0, 0.525, 0.0)), Vector3(4.0, 1.05, 0.06))


## 하역장 턱 4 x 3 (깊이) x 높이 1.2: 옆면 콘크리트 벽 재질, 윗면 바닥 콘크리트, 앞(+Z) 윗모서리 경고 띠, 고무 완충재 둘.
static func loading_dock_4m(kb: KitBuild) -> void:
	kb.block(KitMaterials.CONCRETE_WALL, Vector3.ZERO, Vector3(4.0, 1.18, 3.0), KitBuild.BEVEL_SMALL, false, KitLayout.SILL)
	kb.block(KitMaterials.GROUND_CONCRETE, Vector3(0.0, 1.18, 0.0), Vector3(3.96, 0.02, 2.96), 0.0, false)
	kb.block(KitMaterials.HAZARD, Vector3(0.0, 1.2, 1.3), Vector3(3.96, 0.01, 0.2), 0.0, false)
	for sx: float in [-1.0, 1.0]:
		kb.block(KitMaterials.FLAT_RUBBER, Vector3(sx * 1.2, 0.55, 1.5), Vector3(0.5, 0.4, 0.14), KitBuild.BEVEL_SMALL, false)
	kb.collide_box(KitParts.at(Vector3(0.0, 0.6, 0.0)), Vector3(4.0, 1.2, 3.0))
