# PLAN_PauseBugFix_v1.0
> 시작: 2026-05-06 | 기획서: 없음 (버그 수정)

## 목표
WeaponSelectWidget 열림 중 TimeDilation=0 상태에서도
쿨타임 타이머 감소 / 캐릭터 마우스 회전이 계속 동작하는 버그 수정.

## 아키텍처
```
RSBaseWidget.bPausesGame (EditDefaultsOnly, 기본값 false)
    └─ UIManagerSubsystem::IsAnyPausingUIOpen()  ← PopupUIStack 순회
            ├─ RSPlayerController::PlayerTick     → true면 HandleMouseAim() 스킵
            ├─ WeaponSlotWidget::NativeTick       → true면 UpdateCooldown() 스킵
            └─ CharacterSkillSlotWidget::NativeTick → true면 UpdateCooldown() 스킵

WBP_LevelUpWeaponSelectWidget  bPausesGame = true  (에디터)
WBP_WeaponReplaceWidget        bPausesGame = true  (에디터)
```

## 설계 결정
- bPausesGame 기본값 false → 기존 위젯 동작 변경 없음 (opt-in)
- bIsModal과 동일한 EditDefaultsOnly bool 패턴
- 기존 TimeDilation=0/1 진입·해제 로직은 변경 없음
- WBP_WeaponReplaceWidget도 bPausesGame=true: 레벨업UI→교체UI 전환 시 이미 멈춘 상태이므로 "열려있는 동안 멈춤" 의미로 일관성 유지

## 모듈

### MODULE-1 RSBaseWidget bPausesGame 필드 추가 [P0]
수정: Source/RoastStaffGAS/Public/UI/RSBaseWidget.h
- [ ] bIsModal 아래에 bPausesGame = false 추가 (EditDefaultsOnly, Category="UI")

### MODULE-2 UIManagerSubsystem::IsAnyPausingUIOpen 구현 [P0]
수정:
- Source/RoastStaffGAS/Public/Subsystems/UIManagerSubsystem.h
- Source/RoastStaffGAS/Private/Subsystems/UIManagerSubsystem.cpp
- [ ] h: public 영역 HasOpenPopupUI 근처에 bool IsAnyPausingUIOpen() const 선언
- [ ] cpp: PopupUIStack 순회 — IsOpen() && bPausesGame 인 항목이 있으면 true 반환

### MODULE-3 RSPlayerController::PlayerTick 조건 추가 [P0]
수정: Source/RoastStaffGAS/Private/Character/Player/RSPlayerController.cpp
- [ ] PlayerTick: GET_GI_SUBSYSTEM_FROM으로 UMS 획득 → IsAnyPausingUIOpen() true면 return (HandleMouseAim 스킵)
- [ ] 매 프레임 호출이므로 조건 통과 시 로그 생략

### MODULE-4 SlotWidget NativeTick 쿨타임 조건 추가 [P0]
수정:
- Source/RoastStaffGAS/Private/UI/InGame/WeaponSlotWidget.cpp
- Source/RoastStaffGAS/Private/UI/InGame/CharacterSkillSlotWidget.cpp
- [ ] WeaponSlotWidget::NativeTick: UMS 획득 → IsAnyPausingUIOpen() true면 UpdateCooldown() 스킵
- [ ] CharacterSkillSlotWidget::NativeTick: 동일 패턴

### MODULE-5 에디터 bPausesGame 설정 [P0]
- [ ] WBP_LevelUpWeaponSelectWidget — Class Defaults > UI > bPausesGame = true
- [ ] WBP_WeaponReplaceWidget — Class Defaults > UI > bPausesGame = true

## 상태
ACTIVE
