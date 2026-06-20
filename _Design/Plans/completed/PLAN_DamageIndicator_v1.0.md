# PLAN_DamageIndicator_v1.0
```yaml
date:    2026-04-29
status:  ACTIVE
designs: []
```

## GOAL
> 플레이어 피격 시 HUD 전면에 붉은 비네트 Image가 나타났다 UMG 애니메이션으로 Fade Out하는 데미지 인디케이터 구현.

## SCOPE
```yaml
new_files:      []
modified_files:
  - Source/RoastStaffGAS/Public/UI/RSHUDWidget.h
  - Source/RoastStaffGAS/Private/UI/RSHUDWidget.cpp
  - Source/RoastStaffGAS/Public/Character/Player/RSPlayerController.h
  - Source/RoastStaffGAS/Private/Character/Player/RSPlayerController.cpp
  - Source/RoastStaffGAS/Private/Character/BaseCharacter.cpp
new_datatables: []
new_tags:       []
```

## INTEGRATION_POINTS
```yaml
owner:       ARSPlayerController (D1 — 입력+UI 단일 제어점)
entry:       ABaseCharacter::OnCurrentHPChangedForDamage — SpawnFloatingDamage 직후
depends_on:  URSHUDWidget, UIManagerSubsystem
ref_pattern: ARSPlayerController::OnPassiveSlotChanged → UMS->GetWidgetByID(EUIID::HUD)
arch_impact: >
  INTEGRATION_MAP 추가:
  ABaseCharacter::OnCurrentHPChangedForDamage → ARSPlayerController::FlashHUDDamageIndicator
  | 플레이어 피격 시 (IsPlayerControlled() 체크 — 적 배제)
```

## FLOW
```
GAS AttributeSet HP 감소
    │
    ▼
ABaseCharacter::OnCurrentHPChangedForDamage(Data)
    │  Damage = OldValue - NewValue > 0
    │  IsPlayerControlled() 체크 → false면 Flash 스킵
    │
    ▼
ARSPlayerController::SpawnFloatingDamage()   (기존)
ARSPlayerController::FlashHUDDamageIndicator() (추가)
    │
    ▼
UMS->GetWidgetByID(EUIID::HUD) → URSHUDWidget
    │
    ▼
URSHUDWidget::FlashDamageIndicator()
    StopAnimation(Anim_DamageFlash)   ← 연속 피격 대응
    PlayAnimation(Anim_DamageFlash)
```

## EDGE_CASES
```
| 상황 | 처리 |
|------|------|
| 연속 피격 | StopAnimation 후 PlayAnimation으로 처음부터 재생 |
| 적 캐릭터 피격 | IsPlayerControlled() false → Flash 호출 자체 스킵 |
| Anim_DamageFlash 미할당 | KHS_WARN 출력 후 early return |
| HUD 위젯 없음 | KHS_WARN 출력 후 early return |
```

---
## REVIEW_STATUS
```
| 단계          | 상태 | 날짜 | 주요 지적 |
|---------------|------|------|-----------|
| Senior-Review | -    | -    | -         |

verdict:    PENDING
unresolved: []
```
