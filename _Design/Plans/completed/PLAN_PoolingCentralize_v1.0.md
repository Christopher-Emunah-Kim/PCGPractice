# PLAN_PoolingCentralize_v1.0
```yaml
date:    2026-04-08
sprint:  SPRINT-5
status:  ACTIVE
designs:
  - 스테이지_스폰 시스템 기획 v1.3.md
  - 인트로_트랜지션 시스템 기획 v1.0.md
  - UI관리 시스템 기획 v1.1.md
```

## GOAL
> 분산된 풀링 초기화 책임을 PoolingSubsystem으로 중앙화하고, Tick 기반 AsyncPreWarm + 로딩 화면 연동으로 스테이지 진입 초반 히치를 제거한다.

## SCOPE
```yaml
new_files:
  - Source/RoastStaffGAS/Public/Subsystems/PoolingSubsystem.h   # FPoolPreWarmRequest 추가
modified_files:
  - Source/RoastStaffGAS/Public/Subsystems/PoolingSubsystem.h
  - Source/RoastStaffGAS/Private/Subsystems/PoolingSubsystem.cpp
  - Source/RoastStaffGAS/Public/System/EnemySpawner.h
  - Source/RoastStaffGAS/Private/System/EnemySpawner.cpp
  - Source/RoastStaffGAS/Public/Core/RSGameMode.h
  - Source/RoastStaffGAS/Private/Core/RSGameMode.cpp
  - Source/RoastStaffGAS/Public/Character/Player/RSPlayerController.h
  - Source/RoastStaffGAS/Private/Character/Player/RSPlayerController.cpp
  - Source/RoastStaffGAS/Public/Component/EquipmentComponent.h
  - Source/RoastStaffGAS/Private/Component/EquipmentComponent.cpp
  - Source/RoastStaffGAS/Public/Core/Transition/RSTransitionGameMode.h   # MODULE-7 DEFERRED
  - Source/RoastStaffGAS/Private/Core/Transition/RSTransitionGameMode.cpp # MODULE-7 DEFERRED
new_datatables: []
new_tags: []
```

## FLOW
```
[TRANSITION 레벨]
  TransitionGameMode::BeginPlay()
    ├── UIManager->OpenUIByID(LOADING)
    └── PreloadAssetsAsync() → StreamableManager 비동기 로드
          └── 완료 → StartLevelStreaming() → LoadStreamLevel(visible=false)
                └── OnLevelPreloadCompleted()
                      └── (FinishLoading 호출 제거) → OpenNextLevelLatent()
                            ← LoadingWidget은 UIManager(GameInstanceSubsystem)에 생존

[새 스테이지 World]
  RSGameMode::BeginPlay()
    ├── BuildPreWarmList()
    │     ├── GDS->GetWaveDataByStage(StageID) → EnemyID 목록
    │     ├── GDS->GetEnemyData(EnemyID) → EnemyClass
    │     ├── EnemySpawner->GetEnemyProjectileClass() + GetProjectilePoolCount()
    │     └── DamageFloatingWidgetClass (고정 수량, EditDefaultsOnly)
    ├── PoolingSubsystem->RequestAsyncPreWarm(PreWarmList)
    └── PoolingSubsystem->OnPreWarmComplete 구독
          └── EnableInput() + UIManager->GetWidget(EUIID::LOADING)->FinishLoading()

[Tick (PoolingSubsystem)]
  PreWarmQueue에서 N개씩 꺼내 SpawnPooledActor / CreateWidget
  GetPreWarmProgress() → RSGameMode가 폴링 → LoadingWidget->SetLoadingProgress()
  완료 → OnPreWarmComplete.Broadcast()

[무기 장착 시]
  EquipmentComponent::EquipWeapon(WeaponID)
    └── GDS->GetSkillExecutionData() → ProjectileClass / SummonClass
    └── PoolingSubsystem->InitializePool(ChildClass, N)
```

## SCHEMA
```
신규 DataTable 없음. 기존 DT_Enemy / DT_WaveData / DT_Skill 활용.
```

## EDGE_CASES
```
| 상황 | 처리 | 근거 |
|------|------|------|
| PreWarm 중 ReturnToPool 호출 | ActiveActors에 없으면 이중반납 경고 후 무시 (기존 로직) | 기존 방어 코드 |
| InitializePool 이미 존재하는 클래스 | FindOrAdd로 기존 버킷에 추가 (중복 스폰) — 필요 시 기존 수량 체크 추가 | 기존 구조 |
| PreWarm 완료 전 플레이어 입력 | EnableInput은 OnPreWarmComplete에서만 호출 — 로딩 화면이 입력 차단 | 설계 결정 |
| Widget CreateWidget 시 PC 미준비 | GetFirstLocalPlayerController()로 PC 획득, null 시 PreWarm 지연 | UE5 Widget 수명 |
| EquipWeapon 이미 풀 있는 클래스 | InitializePool은 추가 스폰 (오버 스폰 방지 로직 검토 필요) | MODULE-8 구현 시 판단 |
```

## REVIEW_NOTES
```
기획서 일관성:
  ✗ [HIGH] 인트로_트랜지션 v1.0 — LoadingWidget 종료 주체 충돌 (MODULE-7 DEFERRED 처리)
  ✗ [MED]  UI관리 v1.1 — EUIID.LOADING 레이어 자기모순 (PERSISTENT vs UMS 제외)
  △ [LOW]  스테이지_스폰 v1.3 — InitPool 호출 주체 미기재 (충돌 아님, 보완 권장)

누락 예외처리:
  - LoadingWidget Progress 구동 주체: RSGameMode가 Tick으로 UIManager->GetWidget(LOADING)->SetProgress 폴링
  - WidgetPool PreWarm 시 PC 미준비 대응 (EDGE_CASES 참조)

기획서 정정:
  - 인트로_트랜지션 v1.0: LoadingWidget 종료 흐름 갱신 필요 (MODULE-7 완료 후)
  - UI관리 v1.1: EUIID.LOADING 레이어 표기 통일 필요

Gemini 반영: 미실시
```

---
## REVIEW_STATUS
```
| 단계          | 상태 | 날짜 | 주요 지적 |
|---------------|------|------|-----------|
| Cross-Review  | -    | -    | -         |
| Senior-Review | -    | -    | -         |
| Learn-Report  | -    | -    | -         |

verdict:    PENDING
unresolved: []
```
