# PLAN_TransitionFinishLoading_v1.0
```yaml
date:    2026-04-09
sprint:  SPRINT-4
status:  ACTIVE
designs: [인트로_트랜지션 시스템 기획 v1.0.md]
```

## GOAL
> RSTransitionGameMode에서 잘못 호출되던 FinishLoading을 제거하고, LoadingWidget이 Stage 레벨의 PreWarm 완료 시점에 닫히도록 흐름을 수정한다.

## SCOPE
```yaml
new_files:      []
modified_files:
  - Source/RoastStaffGAS/Private/Core/Transition/RSTransitionGameMode.cpp
  - Source/RoastStaffGAS/Public/Core/Transition/RSTransitionGameMode.h
  - Source/RoastStaffGAS/Private/UI/Transition/RSLoadingWidget.cpp
  - Source/RoastStaffGAS/Public/UI/Transition/RSLoadingWidget.h
  - Source/RoastStaffGAS/Private/Core/RSGameMode.cpp
new_datatables: []
new_tags:       []
```

## FLOW
```
[Transition 레벨]
RSTransitionGameMode::BeginPlay()
    │
    ▼
UMS::OpenUIByID(LOADING) → LoadingWidget ON, Progress 0%
    │
    ▼
PreloadAssetsAsync() → 에셋 비동기 로드
    │
    ▼
StartLevelStreaming() → LoadStreamLevel (bIsLoadingLevel 제거)
    │
    ▼
OnLevelPreloadCompleted()
    ├─ FinishLoading() 호출 제거  ✂
    ├─ 1초 타이머 제거            ✂
    └─ GI::OpenNextLevelLatent()  (즉시 전환)

[Stage 레벨]
RSGameMode::BeginPlay() → InitializePreWarm()
    │
    ▼
RSGameMode::Tick() → UpdatePreWarmProgress()
    └─ GetPreWarmProgress() → SetLoadingProgress(0.0~1.0)
    │
    ▼
RSGameMode::OnPreWarmCompleted()
    ├─ GetLoadingWidget()->FinishLoading()  (SetProgress 1.0)
    ├─ UMS::CloseUIByID(LOADING)           ← 신규
    ├─ PC->EnableInput(PC)
    └─ StartStageFlow()
```

## SCHEMA
DataTable 변경 없음.

## EDGE_CASES
```
| 상황 | 처리 | 기획서 근거 |
|------|------|------------|
| PreWarmList 비어있을 때 (즉시 StartStageFlow) | OnPreWarmCompleted 미호출 → CloseUIByID 직접 호출 필요 | 기획서 예외 미정의, 방어 처리 |
| LoadingWidget이 이미 닫힌 상태에서 CloseUIByID 호출 | UMS가 nullptr 위젯 skip 처리 여부 확인 | - |
| OpenNextLevelLatent 후 TransitionGameMode 소멸 시 위젯 생존 보장 | UMS가 GI 서브시스템으로 PERSISTENT 레이어 유지 | 기획서: "캐시하여 생존" |
```

## REVIEW_NOTES
```
기획서 일관성: ✓
  - FakeProgress: 기획서 v1.1 제거 명시 → MODULE-1에서 제거
  - FinishLoading 호출 위치: 기획서는 스테이지 GameMode(PreWarm 완료 시) 명시 → 정합
  - LoadingWidget ON 위치: Transition::BeginPlay → 기획서 정합 (로비가 아님)
누락 예외처리: PreWarmList 비어있을 때 CloseUI 경로 처리 필요
기획서 정정:   없음
Gemini 반영:   -
```

---
## REVIEW_STATUS
```
| 단계          | 상태 | 날짜       | 주요 지적 |
|---------------|------|------------|-----------|
| Cross-Review  | -    | -          | -         |
| Senior-Review | -    | -          | -         |
| Learn-Report  | -    | -          | -         |

verdict:    PENDING
unresolved: []
```