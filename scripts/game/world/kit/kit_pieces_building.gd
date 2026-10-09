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
