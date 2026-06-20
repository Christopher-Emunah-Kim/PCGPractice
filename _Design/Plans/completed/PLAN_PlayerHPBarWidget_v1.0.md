# PLAN_PlayerHPBarWidget_v1.0
```yaml
date:    2026-03-28
sprint:  SPRINT-1
status:  ACTIVE
designs: [UI관리 시스템 기획 v1.0.md, 캐릭터 시스템 기획 v1.2.md]
```

## GOAL
> PlayerHPBarWidget을 WBP_HUD의 자식 위젯으로 구현 — Player ASC의 HP 어트리뷰트 변화를 감지해 PBar_Health/Ghost 보간 업데이트 + Anim_LowHealth + Anim_HitShake(신규) 재생.

## SCOPE
```yaml
new_files:
  - Source/RoastStaffGAS/Public/UI/Player/PlayerHPBarWidget.h
  - Source/RoastStaffGAS/Private/UI/Player/PlayerHPBarWidget.cpp
modified_files: []
new_datatables: []
new_tags: []
```

## FLOW
```
[ASC GE 적용]
    │
    ▼
OnCurrentHPChanged(Data)
    ├─ HP 감소 ──→ TriggerHitShake() ──→ Anim_HitShake PlayAnimation
    ├─ TargetHealth 갱신 + PBar_Health 즉시 갱신
    ├─ GhostDelayTimer 리셋
    └─ CheckLowHealthState()
          ├─ HP% ≤ LowHealthThreshold ──→ Anim_LowHealth PlayAnimation
          └─ HP% >  LowHealthThreshold ──→ StopAnimation(Anim_LowHealth)

NativeTick(DeltaTime)
    └─ UpdateGhostBar(DeltaTime)
          ├─ GhostDelayTimer > 0 ──→ Timer 차감, RETURN
          └─ Timer 소진 ──→ FInterpTo(GhostHealth → TargetHealth) ──→ PBar_Ghost 갱신

[바인딩 진입점]
PlayerHPBarWidget::NativeConstruct()
    └─ SetTimerForNextTick(BindToPlayerASC)  ← 1프레임 지연 (Pawn 타이밍 방어)
          └─ GetOwningPlayer()->GetPawn<ARSPlayerCharacter>()
                ├─ null ──→ KHS_WARN + return
                └─ GetAbilitySystemComponent() → BindToASC(ASC)
```

## SCHEMA
> DataTable 변경 없음 — 기존 UBaseAttributeSet.CurrentHP / MaxHP 재활용

## EDGE_CASES
```
| 상황 | 처리 | 근거 |
|------|------|------|
| BeginPlay 시점 Pawn null | OnPossess 오버라이드에서 바인딩 재시도 | 서버 Possess 순서 불확정 |
| MaxHP = 0 | CalcPercent() 내 MaxHP≤0 방어 → 0.0f 반환 | 0 나누기 방지 |
| Anim_HitShake 중복 재생 | IsAnimationPlaying() 체크 후 처음부터 재시작 | 기획서 미정의 → 보수적 처리 |
| LowHealth 탈출 | LowHealthThreshold 단순 초과 시 StopAnimation | EnemyHPBarWidget과 동일 규칙 |
| WBP_PlayerHPBar null | BindPlayerHPBar() 내 null 검사 후 return | BindWidget 미연결 방어 |
```

## MODULES

### [MODULE-1] PlayerHPBarWidget 핵심 로직 | P0
신규: `PlayerHPBarWidget.h`, `PlayerHPBarWidget.cpp`
- [ ] BindToASC(UAbilitySystemComponent*) 구현 — 초기값 조회 + 델리게이트 구독
- [ ] OnCurrentHPChanged() 구현 — TargetHealth 갱신, PBar_Health 즉시 갱신, GhostDelayTimer 리셋
- [ ] OnMaxHPChanged() 구현 — CurrentMaxHealth 갱신
- [ ] UpdateGhostBar(DeltaTime) 구현 — GhostDelayTimer 소진 후 FInterpTo → PBar_Ghost 보간
- [ ] NativeTick() 오버라이드 — UpdateGhostBar 호출
- [ ] NativeDestruct() 오버라이드 — ASC 델리게이트 RemoveAll 정리
- [ ] CheckLowHealthState() 구현 — HP비율 ≤ LowHealthThreshold 시 Anim_LowHealth 재생
- [ ] CalcPercent() 헬퍼 — MaxHP=0 방어
- [ ] 헤더 선언 — BindToASC public, private 멤버(CachedASC, TargetHealth, GhostHealth, CurrentMaxHealth, GhostDelayTimer, bIsLowHealth), UPROPERTY 파라미터(GhostDelayTime, InterpSpeed_Ghost, LowHealthThreshold)

### [MODULE-2] HitShake 트리거 | P0
수정: `PlayerHPBarWidget.h`, `PlayerHPBarWidget.cpp`
- [ ] TriggerHitShake() 구현 — Anim_HitShake 유효 시 PlayAnimation (이미 재생 중이면 재시작)
- [ ] OnCurrentHPChanged() 내 HP 감소 조건 시 TriggerHitShake() 호출 삽입

### [MODULE-3] RSHUDWidget 연동 | P0
수정: `RSHUDWidget.h`, `RSHUDWidget.cpp`
- [ ] UPROPERTY(meta=(BindWidget)) TObjectPtr<UPlayerHPBarWidget> WBP_PlayerHPBar 추가
- [ ] BindPlayerHPBar(UAbilitySystemComponent* InASC) public 선언
- [ ] BindPlayerHPBar() 구현 — null 검사 후 WBP_PlayerHPBar->BindToASC(InASC) 호출

### [MODULE-4] RSPlayerController 바인딩 호출 | P0
수정: `RSPlayerController.h`, `RSPlayerController.cpp`
- [ ] BeginPlay에서 HUD 오픈 후 GetPawn<ARSPlayerCharacter>() → ASC 획득 → BindPlayerHPBar(ASC)
- [ ] Pawn null 시 OnPossess() 오버라이드 추가 — 지연 바인딩 수행

### [~MODULE-5] Txt_PlayerName 업데이트 로직 | P2 | DEFERRED
이유: 캐릭터 이름 시스템 미구현. BP에서만 텍스트 지정. 이후 별도 처리.

## REVIEW_NOTES
```
기획서 일관성: ✓
  - CurrentHP/MaxHP → UBaseAttributeSet 정의 확인 (캐릭터 시스템 기획 v1.2)
  - PlayerHPBarWidget은 WBP_HUD 자식(NONE 레이어) → UIManager 미경유 — UI관리 기획 v1.0 정합
누락 예외처리: Pawn null 지연 바인딩 추가
기획서 정정: 없음
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
