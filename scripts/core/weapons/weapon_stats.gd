class_name WeaponStats
extends RefCounted
## 무기 스탯 이름. 스탯은 Dictionary[StringName, float]로 다뤄 새 스탯을 데이터만으로 추가할 수 있게 한다.

const DAMAGE_MULT := &"damage_mult"   # 탄 데미지 배율
const FIRE_RATE := &"fire_rate"       # 분당 발사 수
const RECOIL := &"recoil"             # 반동 (낮을수록 좋음)
const ERGONOMICS := &"ergonomics"     # 조작성 (높을수록 좋음: ADS·재장전 속도)
const SPREAD := &"spread"             # 탄 퍼짐 각도(도) (낮을수록 좋음)
const WEIGHT := &"weight"             # kg
const LOUDNESS := &"loudness"         # 총성 크기 배율 (소음기 < 1)
const RANGE := &"range"               # 유효 사거리 (m)

## 스탯마다 허용 하한. 배율 적용 후 이 값 아래로 내려가지 않는다.
const MIN_VALUES: Dictionary[StringName, float] = {
	DAMAGE_MULT: 0.1,
	FIRE_RATE: 1.0,
	RECOIL: 0.0,
	ERGONOMICS: 0.0,
	SPREAD: 0.0,
	WEIGHT: 0.0,
	LOUDNESS: 0.05,
	RANGE: 1.0,
}
