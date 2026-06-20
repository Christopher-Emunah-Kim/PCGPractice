# PLAN_AsyncLoadOpt_v1.0
```yaml
date:    2026-04-23
sprint:  SPRINT-OPT
status:  ACTIVE
designs: []   # 기술 최적화 — 기획서 불필요
```

## GOAL
> GameThread 블로킹 동기 로드 3개 지점(BT 343ms, SkillFX 콜드 로드, PullVortex FX)을 제거하여 웨이브 시작·스킬 발동 구간 프레임 드롭을 해소한다.

## SCOPE
```yaml
new_files: []
modified_files:
  - Source/RoastStaffGAS/Public/Data/RuntimeDataStructs.h          # 완료
  - Source/RoastStaffGAS/Private/Subsystems/GameDataSubsystem.cpp  # 완료
  - Source/RoastStaffGAS/Private/Subsystems/RuntimeDataSubsystem.cpp
  - Source/RoastStaffGAS/Public/System/EnemySpawner.h
  - Source/RoastStaffGAS/Private/System/EnemySpawner.cpp
  - Source/RoastStaffGAS/Private/Core/Transition/RSTransitionGameMode.cpp  # 버그픽스: StartLevelStreaming 조기 호출 제거
  - Source/RoastStaffGAS/Private/Character/Enemy/EnemyBaseCharacter.cpp    # GC 스파이크: SetWidgetClass 중복 호출 방지
  - Source/RoastStaffGAS/Public/UI/Enemy/EnemyHPBarWidget.h                # GC 스파이크: UnbindFromASC 추가
  - Source/RoastStaffGAS/Private/UI/Enemy/EnemyHPBarWidget.cpp             # GC 스파이크: UnbindFromASC 구현
new_datatables: []
new_tags: []
```

## INTEGRATION_POINTS
```yaml
owner:       AEnemySpawner
entry:       AEnemySpawner::InitPools() ← UStageManagerSubsystem::StartStage
depends_on:  UGameDataSubsystem, URuntimeDataSubsystem, ARSTransitionGameMode
ref_pattern: 기존 ClassCache 패턴 (EnemyClass.LoadSynchronous() → ClassCache.Add) — BTCache도 동일 구조
arch_impact: |
  CLASS_REGISTRY: AEnemySpawner 추가 (책임: 에너미 클래스·BT 캐시 관리 및 스폰)
  INTEGRATION_MAP: AEnemySpawner::InitPools → BTCache 빌드 항목 추가
```

## FLOW
```
[진입점: ARSTransitionGameMode::PreloadAssetsAsync]
    │
    ├─ GatherPreloadCharacterAssets()
    │       └─ FCharacterPreloadBundle.Mesh + AnimBP + SkillFXList(신규)
    │               → OutPaths에 SkillFX 소프트 경로 추가 (MODULE-1)
    ▼
[RequestAsyncLoad → StartLevelStreaming → OpenNextLevel]
    │
    ▼
[게임 레벨: UStageManagerSubsystem::StartStage]
    │
    ├─ AEnemySpawner::InitPools(EnemyIDs)
    │       └─ EnemyClass.LoadSynchronous() → ClassCache  (기존)
    │       └─ BehaviorTree.LoadSynchronous() → BTCache   (신규, MODULE-2)
    ▼
[AEnemySpawner::SpawnEnemy → Enemy::InitializeEnemy → StartEnemyAI]
    │
    └─ EnemyData.BehaviorTree.LoadSynchronous()
           → BTCache 강참조로 GC 방지 → FindObject 경로 → 0ms
```

## SCHEMA
DataTable 변경 없음.

## EDGE_CASES
| 상황 | 처리 |
|------|------|
| BehaviorTree가 null인 EnemyID | IsNull() 체크 후 스킵. ClassCache는 정상 등록 유지 |
| SkillFX가 null인 스킬 슬롯 | IsNull() 체크 후 AddUnique 스킵 |
| EnemySpawner 재사용(스테이지 재시작) | InitPools 재호출 시 BTCache.Empty() + ClassCache.Empty() 동시 클리어 필요 |

## REVIEW_NOTES
```
기획서 일관성: 해당 없음 (기술 최적화)
Gemini 반영: API 키 만료 — 내부 검증으로 대체. 지적 사항 2개 무관 판정, 1개(BTCache 카운트 로그) 계획에 포함됨.
```

---
## REVIEW_STATUS
```
| 단계          | 상태    | 날짜       | 주요 지적         |
|---------------|---------|------------|-------------------|
| Cross-Review  | SKIP    | 2026-04-23 | API 키 만료       |
| Senior-Review | PENDING | -          | -                 |
| Learn-Report  | PENDING | -          | -                 |

verdict:    PENDING
unresolved: []
```

---
## MODULE

- [ ] MODULE-1: SkillFX 프리로드 (RuntimeDataSubsystem.cpp 잔여)
- [ ] MODULE-2: BT 강참조 캐시 (EnemySpawner.h/.cpp)
