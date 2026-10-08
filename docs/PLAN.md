# Extraction Shooter 구현 계획

## 0. 환경 제약 (확인 완료)

| 항목 | 상태 | 영향 |
|---|---|---|
| Unity 에디터 | 미설치, `download.unity3d.com` 프록시 403 차단, 라이선스 활성화·GPU·디스플레이도 없음 | 이 컨테이너에서 Unity 빌드·실행·씬 편집 불가 |
| .NET SDK | 미설치, `dot.net` / NuGet은 접근 가능 | **설치 후 순수 C# 로직의 빌드·테스트 가능** |
| Blender | 미설치 | 모델링은 로컬에서 하거나 외부 에셋 사용 |

**결론: 게임 로직은 Unity 비의존 순수 C#으로 분리하여 여기서 TDD로 검증하고, Unity 레이어(UI·씬·무기 프리팹)는 얇게 유지해 로컬 Unity에서 검증한다.**

## 1. 가정 (변경 시 알려 주세요)

- 엔진: Unity 6 LTS (C# 9 → 코어에서 C# 10+ 문법 금지, `LangVersion 9.0`으로 강제)
- 싱글플레이 우선. 단, 인벤토리 조작은 Command 패턴으로 만들어 이후 서버 권한 구조로 확장 가능하게 함
- 렌더 파이프라인 URP, 입력 Input System, 인벤토리 UI는 UI Toolkit
- 시점 FPS, 히트스캔 사격 우선

## 2. MVP 범위

포함: 테트리스형 인벤토리·스태시, 장비 슬롯, 레이드 1맵(루팅·탈출·사망 시 소실), 무기 3종(권총 / 소총 / 샷건), 단순 AI 적, 부착물 장착, 세이브/로드.
제외: 멀티플레이, 거래소, 퀘스트, 건강 시스템 세부 모델, 비직사각형 아이템.

## 3. 아키텍처

```
Extraction-shooter-/
├─ docs/PLAN.md
├─ src/ExtractionShooter.Core/      # 순수 C# (netstandard2.1, UnityEngine 참조 금지)
│   ├─ Items/        ItemDef, ItemInstance, Rotation
│   ├─ Inventory/    GridContainer, Placement, Commands, EquipmentSlots
│   ├─ Raid/         RaidSession, LootTable, ExtractionRules
│   ├─ Weapons/      WeaponDef, AttachmentDef, StatModifiers
│   └─ Save/         SaveData(DTO), Migrations
├─ tests/ExtractionShooter.Core.Tests/   # xUnit (net8.0)
└─ UnityProject/                     # 로컬 Unity 프로젝트
    └─ Assets/Scripts/Core/ → Core 소스 연결 (asmdef, noEngineReferences)
```

- Core는 Unity에서 asmdef로 소스 그대로 컴파일(심볼릭 링크 또는 복사 스크립트). DLL 빌드 단계 없음.
- 직렬화는 Core가 DTO까지만 책임지고, JSON 변환은 Unity 레이어(Newtonsoft 패키지)가 담당. Core에 외부 의존성 0.
- 상태 변경은 전부 `Command → Result(+Event)`로 통과. UI는 결과 이벤트를 구독만 한다.

## 4. 인벤토리 코어 설계 (핵심)

**데이터**
- `ItemDef`: id, 이름, `Width`×`Height`, `MaxStack`, `CanRotate`, 카테고리, 무게
- `ItemInstance`: 고유 id, def, `StackCount`, 위치 `(X, Y)`, `Rotated`, (컨테이너형이면) 내부 `GridContainer`
- 점유 크기: `Rotated ? (H, W) : (W, H)`
- `GridContainer(width, height)`: 셀마다 점유 아이템 id를 저장하는 `int[,]` + 아이템 목록

**연산 (모두 단위 테스트 대상)**
- `CanPlace(item, x, y, rotated, ignoreSelf)`: 경계 + 겹침 검사
- `TryPlace`, `Remove`, `Move`(같은 컨테이너 내 이동은 자기 자신 무시, **원자적**)
- `TryAutoPlace`: 행 우선 탐색, 회전 허용 시 두 방향 시도. O(W·H·w·h)로 충분
- 스택: `TryMerge`, `Split`, 같은 def끼리만 병합, MaxStack 초과분 처리
- 컨테이너 간 이동(배낭 ↔ 스태시): 목적지 배치 실패 시 원위치 복구(롤백)
- 중첩 컨테이너: 배낭 안에 배낭 금지 규칙, 컨테이너 아이템을 자기 자신 안으로 넣기 금지
- 장비 슬롯: 슬롯별 허용 카테고리 검증, 장착 시 배낭·리그가 추가 그리드를 제공

**엣지 케이스 목록**: 경계 정확히 맞는 배치, 1×1 틈 채우기, 회전해야만 들어가는 경우, 가득 찬 컨테이너, 제거 후 재배치, 스택 병합 시 잔량 분할, 직렬화 왕복 후 점유 맵 동일성.

## 5. 레이드 루프

상태: `Hideout(스태시) → Loadout → Raid → (Extracted | Dead) → Results → Hideout`

- 탈출 성공: 레이드 소지품을 스태시로 이전. 스태시 공간 부족 시 정책 필요(우선 "이전 불가 아이템은 소실 경고")
- 사망: 장비 슬롯·배낭 내용물 소실, 보안 컨테이너(옵션)만 보존
- `LootTable`: 가중치 기반 스폰, 시드 고정으로 재현 가능한 테스트
- 탈출 지점: 활성 조건, 대기 시간(타이머), 위치는 Unity 씬 쪽 책임, 규칙은 Core

## 6. 무기 시스템

- `WeaponDef`: 데미지, 연사속도, 반동, 탄창 규격, 사거리, 부착물 소켓 목록
- `AttachmentDef`: 소켓 종류, `StatModifiers`(가산/배율). 최종 스탯 = 기본 + 장착 부착물 합산 (Core에서 순수 계산, 테스트 가능)
- 탄약은 인벤토리 아이템. 장전 시 인벤토리에서 소비
- 사격: 히트스캔 → 이후 탄도 확장 검토
- 3종: 권총(인벤토리 2×1), 소총(5×2), 샷건(5×2)

## 7. 무기 모델링 파이프라인

**사양 (모델러와 코드가 공유하는 계약)**
- 단위 m, Y-up, 총구 방향 +Z, 원점은 그립 중심
- 소켓은 빈 오브젝트로 `SOCKET_Muzzle`, `SOCKET_Optic`, `SOCKET_Magazine`, `SOCKET_Ejection` 명명
- 트라이 예산: 1인칭 8~15k, 월드 드롭 모델 ≤3k. 텍스처 2K PBR
- 내보내기 FBX, 아이템 아이콘은 Unity 카메라로 RenderTexture 자동 생성(셀당 64px)

**제작 경로 (우선순위 순)**
1. CC0/라이선스 확인된 에셋으로 먼저 구현 (게임플레이 검증이 우선)
2. Higgsfield `generate_3d`로 블록아웃 (커넥터 재연결 필요, 토폴로지 품질 낮아 최종용 부적합)
3. Blender 수작업으로 교체

## 8. 마일스톤

| M | 내용 | 검증 위치 |
|---|---|---|
| M0 | 저장소 부트스트랩: `.gitignore`(Unity), 솔루션, Core/Tests 프로젝트, dotnet 설치, CI(`dotnet test`) | 여기 |
| M1 | 그리드 컨테이너: 배치·이동·회전·자동배치·스택 + 테스트 | 여기 |
| M2 | 아이템 정의, 장비 슬롯, 스태시, 컨테이너 간 이동 롤백, Command/Event | 여기 |
| M3 | 레이드 규칙(탈출·사망), 루팅 테이블, 세이브 DTO·버전 마이그레이션 | 여기 |
| M4 | Unity 프로젝트 골격(URP, Input System, asmdef 연결) | **로컬** |
| M5 | 인벤토리 UI(UI Toolkit 드래그앤드롭, 회전 키, 배치 가능 하이라이트) | **로컬** |
| M6 | FPS 컨트롤러 + 히트스캔 무기 + 탄약 소비 | **로컬** |
| M7 | 부착물 장착 UI + 스탯 반영, 무기 3종 모델 적용 | **로컬** |
| M8 | 레이드 씬: 루팅 컨테이너, 단순 AI, 탈출 지점, 결과 화면 | **로컬** |
| M9 | 세이브/로드 연동, 밸런싱, 폴리시 | **로컬** |

위험 순서(로직 → 표현)로 배치했다. M1~M3이 끝나면 게임의 규칙은 전부 테스트로 고정된다.

## 9. 테스트 전략

- Core: xUnit, 속성 기반 성격의 무작위 배치 테스트(고정 시드)로 "점유 맵 = 아이템 목록에서 재계산한 맵" 불변식 검증
- Unity 레이어: 로직을 넣지 않고 Core 호출만 하도록 유지. 수동 확인 체크리스트를 마일스톤마다 `docs/`에 둠
- CI: PR마다 `dotnet test` 실행

## 10. 위험과 미결정 사항

1. **Unity 레이어는 여기서 컴파일 검증 불가** → 얇게 유지, 로컬에서 에디터로 확인 필요. 컴파일 에러 로그를 공유받아 수정하는 방식으로 진행
2. Unity 프로젝트의 `ProjectSettings`/`Library`는 에디터가 생성 → M4는 로컬에서 빈 URP 프로젝트를 만들어 푸시하는 방식 권장
3. 스태시 가득 참 정책, 보안 컨테이너 포함 여부
4. 비직사각형 아이템(Tarkov는 직사각형 위주)을 후속 버전에 넣을지 — 넣을 계획이면 M1에서 셀 마스크 기반으로 설계해야 나중에 갈아엎지 않는다
5. 멀티플레이 계획 여부 — 있다면 Command 패턴 유지가 필수
