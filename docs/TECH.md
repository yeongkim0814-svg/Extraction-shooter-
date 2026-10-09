# 기술 아키텍처

## 1. 스택

- **Godot 4.7.x** (stable 고정, 사용자·컨테이너·CI 모두 같은 버전)
- 언어: **GDScript, 정적 타입 강제** (`debug/gdscript/warnings/untyped_declaration = error`)
  - C#을 쓰지 않는 이유: Godot 4의 C# 프로젝트는 웹 내보내기를 지원하지 않음
- 렌더러: Android = **Mobile**, 웹 = **Compatibility** (웹은 Compatibility만 지원)
- 테스트: **GUT** (Godot Unit Test) 애드온, 헤드리스 실행
- 데이터: 커스텀 `Resource` 클래스 + `.tres` 텍스트 파일
- 멀티(후속): Godot 고수준 멀티플레이 API, 네이티브는 ENet, 웹은 WebSocket/WebRTC, 헤드리스 데디케이티드 서버

## 2. 작업 흐름 (태블릿 + 클라우드)

| | 사용자 (갤럭시 탭, Godot 안드로이드 에디터) | Claude (클라우드 컨테이너, 헤드리스 Godot) |
|---|---|---|
| 작성 | 씬 배치, 레벨 그레이박스, 머티리얼 조정, 모델 임포트 | 코드, 데이터(`.tres`), 씬 파일(`.tscn`), 테스트 |
| 검증 | 탭에서 직접 플레이 (터치 조작감·체감 성능) | GUT 자동 테스트, 웹 빌드를 Chromium에서 실행해 스크린샷·콘솔 확인 |
| 동기화 | Git (탭: Termux 또는 Git 클라이언트 앱) | Git |

- `.tscn`·`.tres`·`project.godot`은 텍스트라 Git diff·병합 가능. 같은 씬을 양쪽에서 동시에 편집하지 않는다 (씬 단위로 작업 분담)
- `.godot/` 폴더(임포트 캐시)는 커밋하지 않는다

## 3. 플랫폼 제약이 만드는 규칙

| 제약 | 규칙 |
|---|---|
| 웹 스레드 | 단일 스레드 웹 내보내기 사용 (SharedArrayBuffer 불필요 → 일반 웹호스팅·itch.io 배포 가능). 코어에서 `Thread` 사용 금지 |
| 웹 렌더러 | Compatibility 기능 범위 안에서 그래픽 설계 ([ART.md](ART.md)) |
| 저장 | `user://` 경로 사용 (웹은 IndexedDB, Android는 앱 저장소로 자동 매핑) |
| 다운로드 크기 | 맵·무기 에셋을 추가 `.pck`로 분리, `HTTPRequest`로 받아 `ProjectSettings.load_resource_pack`으로 로드. 웹 초기 다운로드 ≤50MB 목표 |
| 메모리 | 모바일 웹 최하위 티어, 텍스처 압축 ETC2/ASTC(모바일)·S3TC(데스크톱 웹) |
| GC 없음, 할당 비용 | GDScript는 참조 카운팅. 매 프레임 `Array`·`Dictionary` 생성 금지, 그리드 점유맵은 `PackedInt32Array` |

## 4. 레이어

```
core/   (RefCounted 기반 순수 로직. Node·씬 트리 의존 금지 → 헤드리스 테스트 가능)
  items · inventory · equipment · weapons · search · raid · loot · ai_decision · save · commands
   ▲ 호출만
game/   (Node 어댑터: core 호출 + 씬 연결)
  player · weapon_view · ai(EnemyAgent·AiDirector: NavigationAgent3D·감지·사격) · loot_container · extraction_zone
ui/     (Control 노드: 인벤토리 · 수색 · HUD · 메뉴 · 터치 컨트롤)
net/    (후속: 서버 권한)
```

- core는 씬 트리를 모른다. game/ui는 core의 시그널(이벤트)을 받아 화면을 갱신한다
- 인벤토리 드래그앤드롭은 Control의 내장 `_get_drag_data` / `_can_drop_data` / `_drop_data` 사용. 터치는 `emulate_mouse_from_touch`로 같은 경로를 탄다

## 5. 멀티플레이 대비 규칙 (PvE 단계부터 적용)

- 모든 상태 변경은 `Command → GameAuthority.execute() → CommandResult + 이벤트 목록`
  - 지금은 `LocalAuthority`, 멀티 단계에서 서버 권한(RPC로 Command 전송, 서버만 실행)으로 교체
- 아이템 인스턴스 ID는 권한자가 발급 (`IdGenerator`), 클라이언트 생성 금지 → 거래소 복제 방지의 기반
- 난수는 시드 주입 (`RandomNumberGenerator`를 주입) → 루팅·AI 판단 재현 가능, 테스트 결정적
- 시뮬레이션(데미지·탄도 판정·수색 시간)은 core에 두어 서버에서 동일 코드 실행

## 6. 저장소 구조

```
project.godot
export_presets.cfg          # Web, Android 프리셋
addons/gut/                 # 테스트 프레임워크
scripts/
  core/  items/ inventory/ equipment/ weapons/ search/ raid/ loot/ ai_decision/ save/ commands/
  game/  ui/  net/(후속)
data/                       # .tres: 아이템·무기 부품·루팅 테이블·AI 프로필
scenes/                     # .tscn: 맵·플레이어·무기·UI
assets/
  models/ textures/ materials/ shaders/ audio/ fonts/
tests/
  unit/                     # core 단위 테스트 (GUT)
  integration/              # 씬 로드·노드 연결 테스트 (헤드리스)
tools/                      # 컨테이너용 스크립트: Godot 설치, 웹 빌드, 스크린샷
docs/
.github/workflows/tests.yml
```

## 7. core 모듈 설계

### items
- `ItemDef` (Resource): id, 이름, `width`×`height`, `max_stack`, `can_rotate`, 카테고리, 무게, `base_price`, `tradeable`, 효과 목록(`ItemEffect` 리소스 배열: 지혈·회복·진통·버프 조합)
- `ItemInstance`: 권한자 발급 id, def, `stack_count`, 위치, `rotated`, `found_in_raid`, (컨테이너형이면) 내부 그리드

### inventory
- `GridContainer` (core 클래스, UI의 Control `GridContainer`와 이름 충돌 피하려 `ItemGrid`로 명명): `PackedInt32Array` 점유맵 + 아이템 목록
- 점유 크기: `rotated ? (h, w) : (w, h)`
- 연산: `can_place` / `try_place` / `remove` / `move`(같은 그리드 내 이동은 자기 자신 무시, 원자적) / `try_auto_place`(행 우선, 두 방향 시도) / `merge` / `split`
- 그리드 간 이동: 목적지 실패 시 원위치 복구 (롤백)
- 중첩 규칙: 배낭 안 배낭 금지, 자기 자신 안으로 넣기 금지
- 불변식: 점유맵 = 아이템 목록에서 재계산한 맵 (고정 시드 무작위 테스트로 검증)

### equipment
- `EquipmentSlots`: 슬롯별 허용 카테고리 검증, 장착 시 리그·배낭 그리드 제공

### weapons
- `WeaponPartDef` (Resource): 자식 소켓 목록, 스탯 수정치(가산·배율), 크기 기여분, 모델 씬 경로
- `WeaponAssembly`: 부품 트리 (노드는 소켓 이름 경로로 지정). 호환성 검사(소켓 종류·허용 목록·양방향 충돌), 스탯 합산 `compute_stats()`((기본 + 가산) × 배율, 스탯별 하한), 인벤토리 크기 `compute_size()`를 함께 담당
- `WeaponStats`: 스탯 이름 상수 (스탯은 Dictionary라 데이터만으로 추가 가능)
- `AmmoDef`: 구경·데미지·관통력·산탄 수
- `Magazine`: 탄을 한 발씩 기록 (탄종 혼합, 마지막에 넣은 탄부터 발사)
- `DamageModel`: 탄 관통력 vs 방탄 등급

### search
- `SearchState`: 컨테이너별 공개 진행도
- `SearchTimeCalculator`: 기본값 × 크기·희귀도 계수
- 중단·재개 규칙, 수색 소음 이벤트 발행

### raid
- `RaidSession` 상태머신: Hideout → Loadout → Raid → Extracted | Dead → Results
- `ExtractionPoint` + `ExtractionTracker`(대기 시간·조건 플래그), `DeathResolver`(보안 컨테이너만 보존)
- 레이드 중에는 `Inventory.stash_locked`로 스태시를 잠근다. 소지품은 탈출 후에도 장비에 그대로 남으므로 별도 이전 단계가 없다
- 월드 컨테이너(시체·상자, M8): `GameAuthority.register_container(grid, title)`가 키(`loot_<번호>`)를 발급하고, `OpenContainerCommand`/`CloseContainerCommand`로 인벤토리에 루트 그리드로 붙였다 뗀다 (`Inventory.attach_external`). 붙어 있는 동안은 일반 이동 명령으로 플레이어 컨테이너와 아이템을 옮길 수 있다. 인벤토리 화면은 스태시가 없으면 오른쪽 절반에 열린 컨테이너를 보여 준다

- 레이드 흐름(M9, game 계층): `RaidController`(`scripts/game/raid/`)가 `AiTest`를 확장한 레이드 씬 루트다. 맵 구성 → 내비메시 굽기 → 컨테이너 내용물 굴림 → 적 스폰 → 탈출 지점 연결을 하고, 매 프레임 `GameAuthority.tick_searches`를 부르며 수색 소음(반경 8 m, 0.5초 간격)을 `AiDirector`로 넘기고 사격·피격·이동으로 수색을 중단시킨다. `RaidSession`이 시간·탈출·사망을 관리하고, 끝나면 `RaidSummary`(core, 반출 FIR 가치·시간 표기)로 집계해 결과 화면(`scenes/ui/raid_results.tscn`)을 띄운다
- 월드 컨테이너·수색: `LootContainer`(종류별 도형·그리드 크기·이름 글자)가 레이드 시작 때 `RaidLoot`(종류별 `LootTable`)로 내용물을 굴려 `register_container`로 수색 가능 컨테이너로 등록한다. 인벤토리 화면은 공개 전 아이템을 `?` 블록으로 그리고(진행 중인 칸은 `SearchState.current_progress` 고리), `DropResolver`·`InventoryActions`는 공개 전 아이템을 선택·이동 불가(`NOT_REVEALED`)로 판정한다. 시체·컨테이너·레버의 상호작용 대상 선택은 `InteractionFinder`(순수 선택 함수 + 노드 조회)
- 산업단지 맵: `IndustrialMap`이 코드로 상자 지오메트리를 만든다. 충돌은 상자마다 `StaticBody3D`+`BoxShape3D`, 눈에 보이는 면은 재질별 하나의 `ArrayMesh`로 합쳐 메시 인스턴스를 약 10개로 줄였다(탱크 4개만 별도 원기둥). 내비메시는 충돌 상자 면에서 동기로 굽는다(셀 0.4 m). 엄폐 지점은 `cover_point` 그룹 마커

### loot
- `LootTable` (Resource): 가중치 기반, 시드 고정

### ai_decision
- 블랙보드 + 상태 전이 규칙 (순찰·의심·교전·엄폐·수색·복귀) → 헤드리스 테스트
- 감지(레이캐스트·시야각)·이동(`NavigationAgent3D`)은 game 레이어
- M8 코어 추가: `AiPerception`(시야 원뿔·시야 거리 보정·청각·총소리/발소리 반경, 정적 함수)과 `AiGunner`(연사·쉬는 시간·탄창·재장전·조준 퍼짐 수렴, 시간은 delta·난수는 주입). 수치는 `AiProfile`
- M8 game 계층(`scripts/game/ai/`): `EnemyAgent`(블랙보드를 채우고 상태별로 이동·사격·엄폐 실행, 죽으면 시체 + 루팅 컨테이너 등록), `AiDirector`(소음을 반경 안의 적에게 전달, 플레이어 총소리·발소리 연결). 엄폐 지점은 씬의 `cover_point` 그룹 Marker3D, 내비메시는 테스트 씬이 시작할 때 구운 것을 쓴다
- 적 사격 레이 마스크는 월드(1)+사격 대상(2)+플레이어(4). 플레이어는 `HitTarget`으로 `health`를 공유한다

### content
- `ContentDatabase`: 아이템·부품·탄종 정의를 id로 조회 (저장 로드·네트워크 동기화용)

### save
- 저장 데이터는 Dictionary DTO + `version` 필드 + 마이그레이션 체인, `JSON`으로 직렬화해 `user://`에 기록

## 8. 테스트·빌드

- 단위 테스트: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
  - 인벤토리 엣지케이스: 경계에 딱 맞는 배치, 1×1 틈 채우기, 회전해야만 들어가는 경우, 가득 찬 그리드, 제거 후 재배치, 스택 병합 잔량 분할, 직렬화 왕복 후 점유맵 동일성
- 통합 테스트: 씬을 헤드리스로 로드해 노드 연결·시그널 배선 확인
- 웹 스모크 테스트: 웹 내보내기 → 로컬 서버 → Playwright(Chromium)로 실행, 콘솔 에러 0 확인 + 스크린샷
- CI: PR마다 GitHub Actions에서 헤드리스 Godot으로 GUT 실행
- 수동: 마일스톤별 탭 체크리스트(터치 조작감·프레임)를 `docs/`에 둠

## 9. 성능 예산 (코드 측)

[ART.md](ART.md)의 폴리곤·텍스처 예산과 품질 티어를 따른다.
- 매 프레임 할당 최소화 (Godot 프로파일러로 확인)
- AI 감지는 프레임 분산 (에이전트별 주기 갱신)
- 물리 레이캐스트는 충돌 레이어·마스크 필수
- 핫패스는 정적 타입 GDScript로 작성 (타입 지정 시 실행 속도 향상)
