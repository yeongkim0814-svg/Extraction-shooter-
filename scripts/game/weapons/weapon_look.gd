class_name WeaponLook
extends RefCounted
## 부품 외형 표(플레이스홀더). 부품 id별로 단순 도형 조각, 자식 소켓 위치, 총구 끝, 조준선 높이를 한곳에 모았다.
## 좌표는 m, 총구 방향 −Z, 리시버 원점 = 그립 중심, 다른 부품 원점 = 그 부품이 꽂히는 소켓 위치 (ART.md §4).
## 나중에 부품마다 .glb가 생기면 scene_overrides[부품 id] = "res://…/part.tscn"만 채우면 플레이스홀더 대신 쓰인다
## (코어 WeaponPartDef는 건드리지 않는다. 씬 안의 Marker3D "SOCKET_<소켓 이름>"이 소켓 위치).

enum Shape { BOX, CYLINDER }

## 부품 id → 씬 경로. 비어 있으면 플레이스홀더.
static var scene_overrides: Dictionary[StringName, String] = {}

const METAL := Color(0.27, 0.285, 0.31)
const METAL_LIGHT := Color(0.38, 0.4, 0.43)
const METAL_DARK := Color(0.15, 0.16, 0.175)
const POLYMER := Color(0.2, 0.21, 0.23)
const FURNITURE := Color(0.31, 0.29, 0.26)
const LENS := Color(0.2, 0.5, 0.7)
const DOT := Color(1.0, 0.15, 0.1)

static var _table: Dictionary[StringName, PartLook] = {}


## 도형 한 조각.
class Piece:
	var shape: Shape = Shape.BOX
	## BOX: 가로·세로·길이(Z). CYLINDER: x = 반지름, z = 길이(Z축 방향).
	var size: Vector3 = Vector3.ONE
	var pos: Vector3 = Vector3.ZERO
	var color: Color = METAL
	var pitch_deg: float = 0.0
	## 조명 없이 밝게 (조준점·렌즈).
	var glow: bool = false

	func local_bounds() -> AABB:
		var half: Vector3 = size * 0.5
		if shape == Shape.CYLINDER:
			half = Vector3(size.x, size.x, size.z * 0.5)
		return AABB(pos - half, half * 2.0)


## 부품 하나의 외형.
class PartLook:
	var pieces: Array[Piece] = []
	var sockets: Dictionary[StringName, Vector3] = {}
	## 이 부품의 가장 앞쪽 끝 (총구 화염 위치 후보). Vector3.INF면 해당 없음.
	var tip: Vector3 = Vector3.INF
	## 이 부품이 정하는 조준선 높이 (부품 원점 기준). INF면 해당 없음.
	var sight_y: float = INF
	## 확대 조준경처럼 ADS에서 시야를 가리는 부품이면 ADS 중 숨긴다.
	var hide_in_ads: bool = false

	func add(piece: Piece) -> PartLook:
		pieces.append(piece)
		return self

	func socket(socket_name: StringName, at: Vector3) -> PartLook:
		sockets[socket_name] = at
		return self


static func box(size: Vector3, pos: Vector3, color: Color = METAL, pitch_deg: float = 0.0) -> Piece:
	var piece := Piece.new()
	piece.size = size
	piece.pos = pos
	piece.color = color
	piece.pitch_deg = pitch_deg
	return piece


static func cyl(radius: float, length: float, pos: Vector3, color: Color = METAL) -> Piece:
	var piece := Piece.new()
	piece.shape = Shape.CYLINDER
	piece.size = Vector3(radius, 0.0, length)
	piece.pos = pos
	piece.color = color
	return piece


static func glow_box(size: Vector3, pos: Vector3, color: Color) -> Piece:
	var piece: Piece = box(size, pos, color)
	piece.glow = true
	return piece


## 부품 정의의 외형. id 표 → 종류별 기본 → 회색 상자 순.
static func for_part(def: WeaponPartDef) -> PartLook:
	if _table.is_empty():
		_build_table()
	if _table.has(def.id):
		return _table[def.id]
	var type_key := StringName("type:" + String(def.part_type))
	if _table.has(type_key):
		return _table[type_key]
	return _table[&"type:unknown"]


static func has_look(part_id: StringName) -> bool:
	if _table.is_empty():
		_build_table()
	return _table.has(part_id)


static func _build_table() -> void:
	# --- 소총 ---
	var rifle: PartLook = PartLook.new()
	rifle.add(box(Vector3(0.04, 0.07, 0.24), Vector3(0, 0.02, -0.08), METAL))
	rifle.add(box(Vector3(0.02, 0.008, 0.2), Vector3(0, 0.059, -0.09), METAL_DARK))
	rifle.add(box(Vector3(0.028, 0.085, 0.035), Vector3(0, -0.058, 0.01), POLYMER, -15.0))
	rifle.add(box(Vector3(0.006, 0.02, 0.008), Vector3(-0.013, 0.07, 0.02), METAL_DARK))
	rifle.add(box(Vector3(0.006, 0.02, 0.008), Vector3(0.013, 0.07, 0.02), METAL_DARK))
	rifle.socket(&"barrel", Vector3(0, 0.03, -0.2)).socket(&"handguard", Vector3(0, 0.03, -0.2))
	rifle.socket(&"stock", Vector3(0, 0.025, 0.04)).socket(&"optic", Vector3(0, 0.063, -0.07))
	rifle.socket(&"magazine", Vector3(0, -0.015, -0.085))
	rifle.sight_y = 0.07
	_table[&"rifle_receiver"] = rifle

	var barrel_short: PartLook = PartLook.new()
	barrel_short.add(cyl(0.0105, 0.22, Vector3(0, 0, -0.11), METAL_LIGHT))
	barrel_short.add(cyl(0.0128, 0.03, Vector3(0, 0, -0.205), METAL_DARK))
	barrel_short.socket(&"muzzle", Vector3(0, 0, -0.22))
	barrel_short.tip = Vector3(0, 0, -0.22)
	_table[&"barrel_short"] = barrel_short

	var barrel_long: PartLook = PartLook.new()
	barrel_long.add(cyl(0.0105, 0.34, Vector3(0, 0, -0.17), METAL_LIGHT))
	barrel_long.add(cyl(0.0128, 0.03, Vector3(0, 0, -0.325), METAL_DARK))
	barrel_long.socket(&"muzzle", Vector3(0, 0, -0.34))
	barrel_long.tip = Vector3(0, 0, -0.34)
	_table[&"barrel_long"] = barrel_long

	var handguard: PartLook = PartLook.new()
	handguard.add(box(Vector3(0.046, 0.05, 0.14), Vector3(0, 0, -0.07), METAL))
	handguard.add(box(Vector3(0.014, 0.006, 0.14), Vector3(0, 0.028, -0.07), METAL_DARK))
	handguard.socket(&"grip", Vector3(0, -0.025, -0.09))
	_table[&"handguard_rail"] = handguard

	var grip: PartLook = PartLook.new()
	grip.add(box(Vector3(0.024, 0.07, 0.026), Vector3(0, -0.035, 0), POLYMER))
	_table[&"grip_vertical"] = grip

	var stock_fixed: PartLook = PartLook.new()
	stock_fixed.add(box(Vector3(0.032, 0.07, 0.17), Vector3(0, -0.012, 0.09), POLYMER))
	stock_fixed.add(box(Vector3(0.036, 0.09, 0.02), Vector3(0, -0.015, 0.18), METAL_DARK))
	_table[&"stock_fixed"] = stock_fixed

	var stock_folding: PartLook = PartLook.new()
	stock_folding.add(box(Vector3(0.018, 0.022, 0.15), Vector3(0, -0.004, 0.075), METAL))
	stock_folding.add(box(Vector3(0.028, 0.06, 0.015), Vector3(0, -0.02, 0.157), METAL_DARK))
	_table[&"stock_folding"] = stock_folding

	var mag: PartLook = PartLook.new()
	mag.add(box(Vector3(0.024, 0.12, 0.04), Vector3(0, -0.06, 0), METAL_DARK, -8.0))
	_table[&"mag_30"] = mag

	var red_dot: PartLook = PartLook.new()
	red_dot.add(box(Vector3(0.03, 0.01, 0.07), Vector3(0, 0.005, 0), METAL_DARK))
	red_dot.add(box(Vector3(0.004, 0.032, 0.05), Vector3(-0.013, 0.026, 0), METAL_DARK))
	red_dot.add(box(Vector3(0.004, 0.032, 0.05), Vector3(0.013, 0.026, 0), METAL_DARK))
	red_dot.add(box(Vector3(0.03, 0.004, 0.05), Vector3(0, 0.044, 0), METAL_DARK))
	red_dot.add(glow_box(Vector3(0.004, 0.004, 0.002), Vector3(0, 0.027, -0.018), DOT))
	red_dot.sight_y = 0.027
	_table[&"optic_reddot"] = red_dot

	var scope: PartLook = PartLook.new()
	scope.add(box(Vector3(0.02, 0.014, 0.07), Vector3(0, 0.007, 0), METAL_DARK))
	scope.add(cyl(0.02, 0.17, Vector3(0, 0.034, 0), METAL))
	scope.add(cyl(0.027, 0.045, Vector3(0, 0.034, -0.1), METAL_DARK))
	scope.add(cyl(0.024, 0.03, Vector3(0, 0.034, 0.1), METAL_DARK))
	var lens: Piece = cyl(0.022, 0.002, Vector3(0, 0.034, -0.1235), LENS)
	lens.glow = true
	scope.add(lens)
	scope.sight_y = 0.034
	scope.hide_in_ads = true
	_table[&"optic_scope4x"] = scope

	var suppressor: PartLook = PartLook.new()
	suppressor.add(cyl(0.0165, 0.17, Vector3(0, 0, -0.085), METAL_DARK))
	suppressor.add(cyl(0.0185, 0.012, Vector3(0, 0, -0.015), METAL))
	suppressor.tip = Vector3(0, 0, -0.17)
	_table[&"suppressor"] = suppressor

	# --- 샷건 ---
	var shotgun: PartLook = PartLook.new()
	shotgun.add(box(Vector3(0.045, 0.07, 0.2), Vector3(0, 0.02, -0.07), METAL))
	shotgun.add(box(Vector3(0.02, 0.008, 0.16), Vector3(0, 0.059, -0.07), METAL_DARK))
	shotgun.add(cyl(0.014, 0.38, Vector3(0, 0.04, -0.29), METAL_LIGHT))
	shotgun.add(cyl(0.012, 0.3, Vector3(0, 0.012, -0.25), METAL))
	shotgun.add(box(Vector3(0.05, 0.045, 0.13), Vector3(0, 0.014, -0.3), FURNITURE))
	shotgun.add(box(Vector3(0.034, 0.075, 0.2), Vector3(0, -0.005, 0.14), FURNITURE))
	shotgun.add(box(Vector3(0.028, 0.085, 0.035), Vector3(0, -0.058, 0.01), FURNITURE, -15.0))
	shotgun.add(box(Vector3(0.005, 0.012, 0.006), Vector3(0, 0.061, -0.475), METAL_DARK))
	shotgun.socket(&"optic", Vector3(0, 0.063, -0.07))
	shotgun.tip = Vector3(0, 0.04, -0.48)
	shotgun.sight_y = 0.066
	_table[&"shotgun_receiver"] = shotgun

	# --- 권총 ---
	var pistol: PartLook = PartLook.new()
	pistol.add(box(Vector3(0.028, 0.034, 0.12), Vector3(0, 0.002, -0.02), POLYMER))
	pistol.add(box(Vector3(0.03, 0.034, 0.17), Vector3(0, 0.04, -0.045), METAL))
	pistol.add(box(Vector3(0.03, 0.085, 0.045), Vector3(0, -0.045, 0.025), POLYMER, -12.0))
	pistol.add(box(Vector3(0.006, 0.01, 0.006), Vector3(0, 0.062, -0.125), METAL_DARK))
	pistol.add(box(Vector3(0.006, 0.01, 0.008), Vector3(-0.009, 0.062, 0.03), METAL_DARK))
	pistol.add(box(Vector3(0.006, 0.01, 0.008), Vector3(0.009, 0.062, 0.03), METAL_DARK))
	pistol.socket(&"muzzle", Vector3(0, 0.04, -0.13)).socket(&"optic", Vector3(0, 0.057, -0.05))
	pistol.tip = Vector3(0, 0.04, -0.13)
	pistol.sight_y = 0.067
	_table[&"pistol_receiver"] = pistol

	# --- 종류별 기본 (표에 없는 새 부품이 최소한 보이게) ---
	var unknown: PartLook = PartLook.new()
	unknown.add(box(Vector3(0.03, 0.03, 0.06), Vector3(0, 0, -0.03), METAL_LIGHT))
	_table[&"type:unknown"] = unknown
