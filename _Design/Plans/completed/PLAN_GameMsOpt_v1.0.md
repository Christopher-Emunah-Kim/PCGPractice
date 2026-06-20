# PLAN_GameMsOpt_v1.0
```yaml
date:    2026-04-24
sprint:  SPRINT-OPT
status:  ACTIVE
designs: []   # 기술 최적화 — 기획서 불필요
```

## GOAL
> AIC/BT/CMC/SkeletalMesh Tick 빈도 감소 + 거리 기반 동적 조정으로 GameThread ms를 줄인다.
> 근거리 전투 품질은 유지하고, 원거리·화면 밖 적에게만 최적화를 적용한다.

## SCOPE
```yaml
new_files: []
modified_files:
  - Source/RoastStaffGAS/Public/Character/Enemy/EnemyAIController.h
  - Source/RoastStaffGAS/Private/Character/Enemy/EnemyAIController.cpp
  - Source/RoastStaffGAS/Public/Character/Enemy/EnemyBaseCharacter.h
  - Source/RoastStaffGAS/Private/Character/Enemy/EnemyBaseCharacter.cpp
new_datatables: []
new_tags: []
```

## MODULES

### MODULE-1 AIC + BT Tick 간격 (P0)
- AIC 생성자: `PrimaryActorTick.TickInterval = 0.1f`
- `StartAI()`: BT 컴포넌트 `SetComponentTickInterval(0.2f)`

### MODULE-2 거리 기반 CMC + Anim Tick 조정 (P1)
- `AdjustPawnTickRates(APawn*, float)` — AIC Tick에서 호출
- 거리 구간: < 1500 / 1500~3000 / > 3000 cm

### MODULE-3 VisibilityBasedAnimTickOption (보너스)
- `EnemyBaseCharacter` 생성자: `OnlyTickPoseWhenRendered`
