# 기술 아키텍처

## 1. 스택

- Unity 6 LTS, URP, Input System, UI Toolkit, Addressables, AI Navigation(NavMesh)
- 코어: 순수 C# (`netstandard2.1`, **C# 9** — Unity 6 컴파일러 한계. `LangVersion 9.0`으로 강제해 C# 10+ 문법 차단)
- 테스트: xUnit (`net8.0`), GitHub Actions
- 멀티(후속): Netcode for GameObjects + Unity Transport (웹은 WebSocket), 데디케이티드 서버

## 2. 플랫폼 제약이 만드는 규칙

| 제약 | 규칙 |
|---|---|
| WebGL은 스레드 없음 | 코어에서 `System.Threading`·`Task.Run` 금지 |
| WebGL은 동기 파일 IO 불가 | 저장은 `ISaveStorage` 추상화 (웹은 IndexedDB 경유) |
| IL2CPP 코드 스트리핑 | 코어에서 리플렉션 의존 금지, 직렬화는 명시적 DTO |
| 다운로드 크기 | Addressables로 맵·무기 에셋 스트리밍, 웹 초기 다운로드 ≤50MB |
| 모바일·웹 메모리 | 힙 1GB 이하, 모바일 웹(iOS Safari)은 최저 티어 |
| 모바일 GC 스파이크 | 코어 핫패스 할당 최소화 (매 프레임 할당 금지) |

## 3. 레이어

```
Core  (순수 C#, 엔진 참조 금지)
  Items · Inventory · Equipment · Weapons · Search · Raid · Loot · AI.Decision · Save · Commands
   ▲ 호출만
Game  (Unity MonoBehaviour 어댑터: Core 호출 + 씬 연결)
  Player · WeaponView · AIAgent(NavMesh·감지) · LootContainer · ExtractionZone
UI    (UI Toolkit: 인벤토리 · 수색 · HUD · 메뉴)
Net   (후속: 서버 권한)
```

- Core는 Unity를 모른다. Game/UI는 Core의 결과 이벤트를 구독해 화면을 갱신한다
- Unity 레이어에 게임 규칙을 넣지 않는다 (컨테이너에서 테스트 불가하기 때문)

## 4. 멀티플레이 대비 규칙 (PvE 단계부터 적용)

- 모든 상태 변경은 `ICommand → IGameAuthority.Execute → CommandResult + DomainEvent[]`
  - 지금은 `LocalAuthority`, 멀티 단계에서 서버 권한으로 교체
- 아이템 인스턴스 ID는 권한자가 발급 (`IIdGenerator`), 클라이언트 생성 금지 → 거래소 복제 방지의 기반
- 난수는 시드 주입 (`IRandom`) → 루팅·AI 판단 재현 가능, 테스트 결정적
- 시뮬레이션 로직(데미지 계산·탄도 판정·수색 시간)은 Core에 두어 서버에서 동일 코드 실행

## 5. 저장소 구조

```
src/ExtractionShooter.Core/
  Items/ Inventory/ Equipment/ Weapons/ Search/ Raid/ Loot/ AI/ Save/ Commands/
tests/ExtractionShooter.Core.Tests/
UnityProject/
  Assets/_Project/
    Art/ Audio/ Prefabs/ Scenes/ Settings/(URP 티어 에셋) Addressables/
    Scripts/Game/ Scripts/UI/ Scripts/AI/ Scripts/Weapons/ Scripts/Editor/
    Scripts/Core/  → src/ExtractionShooter.Core 연결 (asmdef ES.Core, noEngineReferences)
docs/
.github/workflows/core-tests.yml
```

asmdef: `ES.Core`(엔진 비참조), `ES.Game`, `ES.UI`, `ES.AI`, `ES.Editor`.

아이템 정의 데이터: Unity에서는 ScriptableObject로 작성 → 런타임에 Core `ItemDef`로 변환. Core 테스트는 빌더로 정의를 생성한다.

## 6. Core 모듈 설계

### Items
- `ItemDef`: id, 이름, `Width`×`Height`, `MaxStack`, `CanRotate`, 카테고리, 무게, `BasePrice`, `Tradeable`, 효과 목록(`IItemEffect`)
- `ItemInstance`: 권한자 발급 id, def, `StackCount`, 위치, `Rotated`, `FoundInRaid`, (컨테이너형이면) 내부 그리드

### Inventory
- `GridContainer(width, height)`: `int[,]` 점유맵 + 아이템 목록
- 점유 크기: `Rotated ? (H, W) : (W, H)`
- 연산: `CanPlace` / `TryPlace` / `Remove` / `Move`(같은 컨테이너 내 이동은 자기 자신 무시, 원자적) / `TryAutoPlace`(행 우선, 두 방향 시도) / `Merge` / `Split`
- 컨테이너 간 이동: 목적지 실패 시 원위치 복구 (롤백)
- 중첩 규칙: 배낭 안 배낭 금지, 자기 자신 안으로 넣기 금지
- 불변식: 점유맵 = 아이템 목록에서 재계산한 맵 (무작위 테스트로 검증)

### Equipment
- `EquipmentSlots`: 슬롯별 허용 카테고리 검증, 장착 시 리그·배낭 그리드 제공

### Weapons
- `WeaponPartDef`: 부품 정의, 자식 소켓 목록, 스탯 수정치(가산·배율), 크기 기여분
- `WeaponAssembly`: 부품 트리
- `CompatibilityRules`: 소켓 타입 + 허용 목록 + 충돌 규칙
- `StatCalculator`: 트리 전체 합산 → 반동·인체공학·무게·정확도·소음
- `AssemblySize`: 부품 구성에 따른 인벤토리 크기
- `Magazine`: 탄을 담는 컨테이너
- `DamageModel`: 탄 관통력 vs 방탄 등급

### Search
- `SearchState`: 컨테이너별 공개 진행도 (공개된 아이템 수)
- `SearchTimeCalculator`: 기본값 × 크기·희귀도 계수
- 중단·재개 규칙 (이동·피격·사격 시 중단), 수색 소음 이벤트 발행

### Raid
- `RaidSession` 상태머신: Hideout → Loadout → Raid → Extracted | Dead → Results
- `ExtractionRule` (상시·조건부, 대기 시간), `DeathResolver` (소실 처리, 보안 컨테이너 보존)
- `RaidResultTransfer`: 스태시 이전, 공간 부족 시 소실 경고

### Loot
- `LootTable`: 가중치 기반, 시드 고정

### AI.Decision
- 블랙보드 + 상태 전이 규칙 (순찰·의심·교전·엄폐·수색·복귀). 엔진 비의존 → 컨테이너에서 테스트
- 감지(레이캐스트·시야각)·이동(NavMesh)은 Game 레이어

### Save
- `SaveData` DTO + 버전 필드 + 마이그레이션 체인
- JSON 변환은 Unity 레이어(Newtonsoft 패키지)가 담당 → Core 외부 의존성 0

## 7. 테스트 전략

- Core: xUnit. 엣지케이스 단위 테스트 + 고정 시드 무작위 배치 테스트로 불변식 검증
  - 인벤토리 엣지케이스: 경계에 딱 맞는 배치, 1×1 틈 채우기, 회전해야만 들어가는 경우, 가득 찬 컨테이너, 제거 후 재배치, 스택 병합 잔량 분할, 직렬화 왕복 후 점유맵 동일성
- Unity 레이어: 로직 없이 Core 호출만. 마일스톤별 수동 확인 체크리스트를 `docs/`에 둠
- CI: PR마다 `dotnet test`

## 8. 성능 예산 요약

[ART.md](ART.md)의 폴리곤·텍스처 예산과 품질 티어를 따른다. 코드 측:
- 매 프레임 GC 할당 0 목표 (Unity Profiler로 확인)
- AI 감지는 프레임 분산 (에이전트당 매 프레임이 아닌 주기적 갱신)
- 물리 레이캐스트는 레이어 마스크 필수
