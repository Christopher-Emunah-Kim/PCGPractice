# PLAN_LevelUpSubsystemReinit_v1.0
```yaml
date:    2026-05-06
sprint:  SPRINT-current
status:  ACTIVE
designs: []
```

## GOAL
> LevelUpSubsystem에 DeinitializeSubsystem()을 추가해 로비→스테이지 재진입 시 EXP 구독 누락 버그를 수정한다.

## SCOPE
```yaml
new_files:      []
modified_files:
  - Source/RoastStaffGAS/Public/Subsystems/LevelUpSubsystem.h
  - Source/RoastStaffGAS/Private/Subsystems/LevelUpSubsystem.cpp
  - Source/RoastStaffGAS/Private/Core/RSGameMode.cpp
new_datatables: []
new_tags:       []
```

## INTEGRATION_POINTS
```yaml
owner:       ARSGameMode::OnResultConfirmed
entry:       ULevelUpSubsystem::DeinitializeSubsystem (신규)
depends_on:  UPlayerAttributeSet::OnEXPChangedDel
ref_pattern: UEquipmentSubsystem::DeinitializeSubsystem — ASC nullptr + bIsInitialized 리셋 패턴 동일 적용
arch_impact: INTEGRATION_MAP — ARSGameMode::OnResultConfirmed → ULevelUpSubsystem::DeinitializeSubsystem 항목 추가
```

## FLOW
```
ARSGameMode::OnResultConfirmed()
    │
    ▼
EquipSys->DeinitializeSubsystem()   ← 기존
    │
    ▼
LevelUpSys->DeinitializeSubsystem() ← 신규
    ├─ AttributeSet 유효 → RemoveDynamic(OnEXPChanged)
    ├─ ASC = nullptr
    ├─ AttributeSet = nullptr
    ├─ bIsInitialized = false
    └─ bIsLevelingUp  = false
    │
    ▼
GI->OpenNextLevelByName(OUTGAME)

[2회차 스테이지 진입]
RSPlayerCharacter::InitializeAbilitySystem()
    └─ LevelUpSys->InitializeSubsystem(ASC, AttributeSet, EffectClass)
          └─ bIsInitialized == false → 구독 정상 연결 ✅
```

## EDGE_CASES
```
| 상황 | 처리 | 근거 |
|------|------|------|
| DeinitializeSubsystem 호출 시 AttributeSet이 null | ensureMsgf 없이 IsValid 체크 후 RemoveDynamic 스킵 | 방어적 처리 |
| bIsLevelingUp = true 상태에서 씬 전환 | false로 리셋하여 다음 세션 레벨업 UI 오픈 가능 | 정상화 |
```

## REVIEW_NOTES
```
기획서 일관성: ✓ (버그픽스, 기획서 무관)
누락 예외처리: AttributeSet null 체크
기획서 정정:   없음
Gemini 반영:   해당 없음
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
