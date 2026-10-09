class_name KitPiecesDressing
extends RefCounted
## 장식 부품 (잔해·종이·케이블·식물 카드 등). 원점 = 바닥 중심.


static func build(piece: StringName, _kb: KitBuild) -> bool:
	match piece:
		_:
			return false
