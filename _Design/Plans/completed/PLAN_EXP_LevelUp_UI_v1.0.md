# PLAN_EXP_LevelUp_UI_v1.0
```yaml
date:    2026-03-28
sprint:  SPRINT-1
status:  ACTIVE
designs: [레벨업 시스템 기획 v1.2.md, AI_에너미 시스템 기획 v1.1.md, UI관리 시스템 기획 v1.0.md, 캐릭터 시스템 기획 v1.2.md, 게임 데이터 시스템 기획 v1.1.md]
```

## GOAL
> 에너미 사망 시 스테이지 시스템 경유로 경험치를 레벨업 시스템에 전달하고, PlayerStatusBarWidget의 EXP 바에 Lerp 애니메이션과 함께 표시한다.

## SCOPE
```yaml
new_files:      []
modified_files:
  - Source/RoastStaffGAS/Public/Subsystems/LevelUpSubsystem.h
  - Source/RoastStaffGAS/Private/Subsystems/LevelUpSubsystem.cpp
  - Source/RoastStaffGAS/Private/Subsystems/StageManagerSubsystem.cpp
  - Source/RoastStaffGAS/Public/UI/Player/PlayerStatusBarWidget.h
  - Source/RoastStaffGAS/Private/UI/Player/PlayerStatusBarWidget.cpp
new_datatables: []
new_tags:       []
```

## FLOW

### MODULE-1: LevelUpSubsystem EXP 수신

```
[AEnemyBaseCharacter::HandleDeath()]
    │
    └─ OnEnemyKilledDel.Broadcast(EnemyID)
          │
          └─ StageManagerSubsystem::OnEnemyKilled(EnemyID)  [기존 구독, 수정]
                ├─ KillCount 증가  [기존 로직 유지]
                └─ LevelUpSubsystem->OnEnemyKilled(EnemyID)  [신규 호출 추가]
                      │
                      └─ GDS.GetEnemyData(EnemyID) → FEnemyStaticData::DropEXP
                            ├─ 실패(EnemyID 없음) → UE_LOG(Warning) + RETURN
                            └─ 성공 → AddEXP(DropEXP)
                                  └─ GE_AddEXP → ASC 적용
                                        └─ PostGameplayEffectExecute
                                              └─ OnEXPChangedDel.Broadcast(NewEXP, Level)
                                                    └─ LevelUpSubsystem::OnEXPChanged
                                                          └─ CheckLevelUp(NewEXP, Level)
                                                                ├─ NewEXP < MaxEXP → 종료
                                                                └─ NewEXP >= MaxEXP → ApplyLevelUp
                                                                      ├─ [1] Level += 1  (GE 적용)
                                                                      └─ [2] EXP = carry-over  (GE 적용)
                                                                            ※ 순서 필수: Level 먼저, EXP 나중
```

### MODULE-2: PlayerStatusBarWidget EXP 바

```
[ASC 어트리뷰트 변경 델리게이트]
    ├─ GetGameplayAttributeValueChangeDelegate(EXP)
    │     └─ OnEXPAttrChanged(Data)
    │           └─ ASC에서 CurrentLevel 조회
    │                 └─ GDS.GetLevelCurveValue("RequiredEXP", Level, MaxEXP)
    │                       ├─ MaxEXP <= 0 → Warning + RETURN
    │                       └─ TargetEXPPercent = NewEXP / MaxEXP
    │                             └─ bIsLerpingEXP = true
    │
    └─ GetGameplayAttributeValueChangeDelegate(Level)
          └─ OnLevelAttrChanged(Data)
                └─ LerpStartPercent = PBar_Exp->GetPercent()  ← Lerp 시작점 캐시
                   CurrentLevel 캐시 업데이트

[NativeTick(DeltaTime)]
    └─ bIsLerpingEXP == true?
          ├─ No → 건너뜀
          └─ Yes → CurrentEXPPercent = FMath::FInterpTo(CurrentEXPPercent, TargetEXPPercent, DeltaTime, EXPLerpSpeed)
                        └─ PBar_Exp->SetPercent(CurrentEXPPercent)
                              └─ |Current - Target| < Threshold → bIsLerpingEXP = false

[BindToASC 초기화]
    └─ 현재 EXP/Level 어트리뷰트 값으로 PBar_Exp 즉시 초기값 렌더링 (Lerp 없이)

[NativeDestruct]
    └─ CachedASC 유효 시 EXP/Level 델리게이트 Remove
```

## SCHEMA
```
DataTable: DT_CurveTable
| CurveName    | 타입  | 설명                   |
|--------------|-------|------------------------|
| RequiredEXP  | float | 해당 레벨의 최대 EXP   | ← 확인 완료
| MaxHP        | float | 해당 레벨의 최대 HP    |
```

## EDGE_CASES
```
| 상황                          | 처리                                          | 기획서 근거                      |
|-------------------------------|-----------------------------------------------|----------------------------------|
| EnemyID가 GDS에 없음          | Warning 로그 후 RETURN (EXP 0 적용 안 함)     | 방어적 코딩 원칙                 |
| MaxEXP <= 0                   | Warning 로그 후 RETURN (퍼센트 계산 불가)     | 방어적 코딩 원칙                 |
| 최대 레벨(20) 도달 후 EXP 획득 | 기획서: 경험치 누적 중단. EXP 바 100% 고정   | 레벨업 시스템 기획 v1.2 §최대레벨 |
| 레벨업 시 EXP 연출            | carry-over percent로 즉시 Lerp 시작 (100% 연출 없음) | 기획서 미정의 → 단순 처리      |
| EXPLerpSpeed                  | EditDefaultsOnly, BP에서 조정 가능하게 노출   | 기획서 미정의                    |
```

## REVIEW_NOTES
```
기획서 일관성: ✓ (기획서 "스테이지 시스템이 적ID를 레벨업 시스템에 전달" 준수)
누락 예외처리: MaxEXP <= 0 방어, EnemyID 없음 방어
기획서 정정:   없음
Gemini 반영:   미진행
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
