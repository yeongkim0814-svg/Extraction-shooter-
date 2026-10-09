class_name RaidSummary
extends RefCounted
## 레이드 결과 집계: 가지고 나간 FIR(Found in Raid) 아이템의 가치와 시간 표기. 순수 계산이라 UI·씬과 무관하다.


## 결과 화면에 보여 줄 한 판의 요약.
class Report:
	var outcome: RaidSession.Outcome = RaidSession.Outcome.NONE
	var elapsed: float = 0.0
	var kills: int = 0
	var containers_searched: int = 0
	## 가지고 나간(사망 시엔 보안 컨테이너에 남은) FIR 아이템 가치.
	var value: int = 0
	## 사망으로 잃은 아이템 수.
	var lost_count: int = 0


## 세션이 끝난 뒤(탈출/사망/시간 초과) 요약을 만든다. 사망 처리가 끝난 인벤토리를 기준으로 센다.
static func build_report(session: RaidSession, kills: int, containers_searched: int) -> Report:
	var report := Report.new()
	report.outcome = session.outcome
	report.elapsed = session.elapsed
	report.kills = kills
	report.containers_searched = containers_searched
	report.value = carried_value(session.inventory)
	report.lost_count = session.lost_item_ids.size()
	return report


## 결과 화면 제목.
static func outcome_title(outcome: RaidSession.Outcome) -> String:
	match outcome:
		RaidSession.Outcome.EXTRACTED:
			return "탈출 성공"
		RaidSession.Outcome.KILLED:
			return "사망"
		RaidSession.Outcome.TIMED_OUT:
			return "시간 초과"
	return "-"


## 인벤토리에 남아 있는 found_in_raid 아이템의 합계 (기준가 × 수량). 컨테이너 안의 아이템도 모두 센다.
static func carried_value(inventory: Inventory) -> int:
	var total: int = 0
	for item: ItemInstance in inventory.get_items():
		if item.found_in_raid:
			total += item.def.base_price * item.stack_count
	return total


## 초를 "mm:ss"로 (올림 없이 내림, 음수는 0).
static func format_time(seconds: float) -> String:
	var whole: int = maxi(int(seconds), 0)
	return "%02d:%02d" % [whole / 60, whole % 60]


## 남은 시간 표기용: 올림해서 "mm:ss" (0.2초 남아도 00:01).
static func format_remaining(seconds: float) -> String:
	return format_time(ceilf(maxf(seconds, 0.0)))
