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
	&"wall_4m": BUILDING,
	&"barrel": PROP,
	&"lamp_sodium": PROP,
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
