class_name KitCatalog
extends RefCounted
## 부품 목록 (ART.md 11.5). 이름 -> 분류, 그리고 이름으로 KitBuild를 채우는 정의 함수.
## 분류별 정의는 kit_pieces_<분류>.gd에 있고, 여기서는 목록과 분배만 한다.
## tools/build_kit.gd가 모든 부품을 scenes/kit/<분류>/<이름>.tscn으로 굽는다.

const BUILDING: StringName = &"building"
const LARGE: StringName = &"large"
const PROP: StringName = &"prop"
const DRESSING: StringName = &"dressing"

## 이름 -> 분류. 새 부품은 여기에 한 줄 + 분류 파일에 정의 하나.
const PIECES: Dictionary[StringName, StringName] = {
	# BUILDING
	&"wall_4m": BUILDING,
	&"wall_4m_window": BUILDING,
	&"wall_4m_door": BUILDING,
	&"door_steel": BUILDING,
	&"wall_4m_shutter": BUILDING,
	&"wall_4m_shutter_open": BUILDING,
	&"wall_4m_damaged": BUILDING,
	&"wall_corner": BUILDING,
	&"pillar_steel": BUILDING,
	&"roof_truss_8m": BUILDING,
	&"roof_panel_4m": BUILDING,
	&"skylight_4m": BUILDING,
	&"floor_slab_4m": BUILDING,
	&"stairs_steel_2m": BUILDING,
	&"catwalk_4m": BUILDING,
	&"railing_4m": BUILDING,
	&"loading_dock_4m": BUILDING,
	# LARGE
	&"container_20ft_red": LARGE,
	&"container_20ft_teal": LARGE,
	&"tank_vertical": LARGE,
	&"pipe_rack_8m": LARGE,
	&"chimney": LARGE,
	&"truck_flatbed": LARGE,
	&"forklift": LARGE,
	&"guard_booth": LARGE,
	# PROP
	&"barrel": PROP,
	&"barrel_red": PROP,
	&"barrel_teal": PROP,
	&"pallet": PROP,
	&"crate_wood": PROP,
	&"crate_military": PROP,
	&"locker_steel": PROP,
	&"drawer_cabinet": PROP,
	&"electrical_cabinet": PROP,
	&"cable_tray_4m": PROP,
	&"ladder_wall_4m": PROP,
	&"lamp_sodium": PROP,
	&"lamp_wall": PROP,
	&"lamp_fluoro": PROP,
	&"lamp_emergency": PROP,
	&"fire_extinguisher": PROP,
	# DRESSING
	&"rubble_small": DRESSING,
	&"rubble_large": DRESSING,
	&"debris_planks": DRESSING,
	&"cable_hanging_4m": DRESSING,
	&"puddle_2m": DRESSING,
}


static func names() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(PIECES.keys())
	return out


static func category_of(piece: StringName) -> StringName:
	return PIECES.get(piece, &"")


## 부품 하나를 만든다. 없는 이름이면 null.
static func build(piece: StringName) -> KitBuild:
	if not PIECES.has(piece):
		push_warning("부품 없음: " + String(piece))
		return null
	var kb := KitBuild.new(piece)
	var ok: bool = false
	match PIECES[piece]:
		BUILDING:
			ok = KitPiecesBuilding.build(piece, kb)
		LARGE:
			ok = KitPiecesLarge.build(piece, kb)
		PROP:
			ok = KitPiecesProp.build(piece, kb)
		DRESSING:
			ok = KitPiecesDressing.build(piece, kb)
	if not ok:
		push_warning("부품 정의 없음: " + String(piece))
		return null
	return kb
