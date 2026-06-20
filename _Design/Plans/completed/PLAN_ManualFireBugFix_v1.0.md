# PLAN_ManualFireBugFix_v1.0
```yaml
date:    2026-03-27
sprint:  SPRINT-현재
status:  ACTIVE
designs: []   # 버그 픽스 — 별도 기획서 없음
```

## GOAL
> `bRetriggerInstancedAbility = false` 기본값으로 인해 수동 모드 클릭 시 GAS가 무음 실패하는 버그를 수정한다.

## SCOPE
```yaml
new_files: []
modified_files:
  - Source/RoastStaffGAS/Private/GAS/Abilities/GA_ProjectileAttack.cpp
  - Source/RoastStaffGAS/Public/Data/RuntimeDataStructs.h
  - Source/RoastStaffGAS/Private/Subsystems/EquipmentSubsystem.cpp
new_datatables: []
new_tags: []
```

## ROOT_CAUSE
```
GA_Base 생성자: InstancingPolicy = InstancedPerActor
GA_ProjectileAttack 생성자: bRetriggerInstancedAbility = false (기본값)

GAS InternalTryActivateAbility 내부:
  if (Spec->IsActive())
    → bRetriggerInstancedAbility=false → return false (무음 실패)

자동 모드: Cooldown(0.5s~) 간격 → GA가 완전히 종료된 후 재발동 → 성공
수동 모드: 사용자 클릭(~0.1s) → GA가 IsActive() 상태일 가능성 → 무음 실패
```

## FLOW
```
[수동 클릭]
    │
    ▼
[RequestManualFire]
    │ ActiveSlotIndex != -1 && MoveType != SUMMON
    ▼
[FireSlot(ActiveSlotIndex, AimLocation)]
    │
    ├─ [MODULE-2 추가] LastManualFireTime 게이트 (0.1s)
    │     └─ 0.1s 미만 → return (스팸 방지)
    │
    ▼
[TriggerAbilityFromGameplayEvent]
    │
    ├─ [MODULE-1 픽스] bRetriggerInstancedAbility = true
    │     → Spec->IsActive() → EndAbility 후 재발동 허용
    │
    ├─ 성공 → 투사체 스폰 + EndAbility
    └─ 실패 → [MODULE-2 추가] KHS_WARN 로그
```

## MODULES

### MODULE-1: bRetriggerInstancedAbility 픽스
**파일**: `GA_ProjectileAttack.cpp`
**변경**: 생성자에 `bRetriggerInstancedAbility = true` 추가
**이유**: InstancedPerActor + bRetriggerInstancedAbility=false 조합이 수동 발사 무음 실패의 직접 원인

### MODULE-2: FireSlot 진단 + LastManualFireTime 게이트
**파일**: `RuntimeDataStructs.h`, `EquipmentSubsystem.cpp`
**변경 1**: `FWeaponSlotInstanceData`에 `float LastManualFireTime = 0.f` 추가
**변경 2**: `FireSlot`에서 `TriggerAbilityFromGameplayEvent` 반환값 체크 + 실패 시 `KHS_WARN`
**변경 3**: `RequestManualFire`에서 0.1s 게이트 (`GetWorld()->GetTimeSeconds() - Slot.LastManualFireTime`)
**이유**: 0.1s 최소 간격 의도를 코드로 명시 + 실패 진단 가능성 확보

## EDGE_CASES
```
| 상황 | 처리 | 근거 |
|------|------|------|
| IsActive() 상태에서 재트리거 | GAS가 EndAbility 후 재발동 | bRetriggerInstancedAbility=true |
| 0.1s 미만 연속 클릭 | LastManualFireTime 게이트로 스킵 | 설계 의도 |
| FireSlot 실패 | KHS_WARN 로그 출력 | 진단 목적 |
```

## REVIEW_NOTES
```
기획서 일관성: ✓ (버그 픽스, 기획서 변경 불필요)
누락 예외처리: 없음
기획서 정정: 없음
Gemini 반영: 해당없음
```

---
## REVIEW_STATUS
```
| 단계          | 상태 | 날짜       | 주요 지적         |
|---------------|------|------------|-------------------|
| Cross-Review  | -    | -          | -                 |
| Senior-Review | -    | -          | -                 |
| Learn-Report  | -    | -          | -                 |

verdict:   PENDING
unresolved: []
```
