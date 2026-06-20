# PLAN_PassiveSlotUI_v1.0
> 작성일: 2026-04-15
> 기획서: _Design/References/Systems/게임 시스템 개선안 v1.0.md
> 목표: 패시브 슬롯 UI — PassiveSlotWidget 신규 + SlotContainerWidget 확장 + PC stub 구현

---

## 아키텍처 흐름

```
PassiveSlotSubsystem::TryAddPassive()
  → OnPassiveSlotChangedDel.Broadcast()
  → ARSPlayerController::OnPassiveSlotChanged()   ← stub → 구현 (MODULE-3)
    → UMS->GetWidgetByID(EUIID::HUD) → URSHUDWidget
    → GetSlotContainerWidget() → USlotContainerWidget
    → UpdatePassiveSlots(PassiveSys->GetEquippedPassives())
      → PassiveSlotWidget[0..7]::UpdateSlot(PassiveID) or ClearSlot()
        → GDS->GetPassiveData() → FPassiveStaticData
        → Img_PassiveIcon: 아이콘 로드
        → Txt_PassiveName / Txt_PassiveDesc: 텍스트 세팅
        → Btn_PassiveSlot hover → Ovl_Tooltip Visible / Hidden
```

---

## 설계 결정

| # | 결정 | 내용 |
|---|------|------|
| SD1 | 빈 슬롯 처리 | Hidden (not Collapsed) — 레이아웃 공간 유지 |
| SD2 | 슬롯 수 | 8개 프리할당, MAX_SLOTS=4까지만 채움 |
| SD3 | 툴팁 위치 | 아이콘 위쪽 고정 (마우스 따라다니지 않음) |
| SD4 | 툴팁 내용 | DisplayName + Description |
| SD5 | hover 바인딩 | NativeOnInitialized (NativeConstruct 금지) |
| SD6 | 아이콘 로드 | LoadSynchronous (CharacterSkillSlotWidget 패턴 동일) |

---

## 통합 지점

| 역할 | 소유 | 진입점 |
|------|------|--------|
| 슬롯 UI 호스팅 | USlotContainerWidget | UpdatePassiveSlots() |
| 데이터 갱신 트리거 | ARSPlayerController | OnPassiveSlotChanged() — delegate 이미 연결됨 |
| 데이터 조회 | UGameDataSubsystem | GetPassiveData(FName) → FPassiveStaticData |

---

## 모듈 목록

### MODULE-1 [P0] PassiveSlotWidget 신규
> `Source/RoastStaffGAS/Public/UI/InGame/PassiveSlotWidget.h` (신규)
> `Source/RoastStaffGAS/Private/UI/InGame/PassiveSlotWidget.cpp` (신규)

**BindWidget:**
- `Btn_PassiveSlot` — UButton (hover wrapper)
- `Img_PassiveIcon` — UImage (패시브 아이콘)
- `Ovl_Tooltip` — UBorder (툴팁 컨테이너, 아이콘 위쪽)
- `Txt_PassiveName` — UTextBlock (DisplayName)
- `Txt_PassiveDesc` — UTextBlock (Description)

**인터페이스:**
- `UpdateSlot(FName PassiveID)`
- `ClearSlot()`
- `OnSlotHovered()` / `OnSlotUnhovered()` (UFUNCTION, private)

**태스크:**
- [ ] 클래스 선언 + BindWidget 멤버
- [ ] NativeOnInitialized: hover 바인딩 + Ovl_Tooltip Hidden 초기화
- [ ] UpdateSlot: GDS 조회 → 아이콘 로드 → 텍스트 → Visible
- [ ] ClearSlot: Hidden
- [ ] OnSlotHovered / OnSlotUnhovered

### MODULE-2 [P0] SlotContainerWidget 확장
> `Source/RoastStaffGAS/Public/UI/InGame/SlotContainerWidget.h` (수정)
> `Source/RoastStaffGAS/Private/UI/InGame/SlotContainerWidget.cpp` (수정)

**추가 멤버:**
- `PassiveSlotWidget_0 ~ PassiveSlotWidget_7` (BindWidget, TObjectPtr<UPassiveSlotWidget>)
- `static constexpr int32 MAX_PASSIVE_SLOTS = 8`

**추가 함수:**
- `void UpdatePassiveSlots(const TArray<FName>& EquippedPassiveIDs)`
- `UPassiveSlotWidget* GetPassiveSlotWidget(int32 SlotIndex) const`

**태스크:**
- [ ] PassiveSlotWidget_0~7 BindWidget 8개 추가
- [ ] UpdatePassiveSlots 구현 (index < Num → UpdateSlot / else → ClearSlot)
- [ ] GetPassiveSlotWidget accessor (switch, 범위 초과 시 KHS_WARN)
- [ ] NativeConstruct: 8개 ensureMsgf + ClearSlot() 초기화

### MODULE-3 [P0] RSPlayerController stub → 구현
> `Source/RoastStaffGAS/Private/Character/Player/RSPlayerController.cpp` (수정)

**변경:**
- `OnPassiveSlotChanged()` stub 제거
- 기존 RefreshSkillSlotUI 패턴: UMS→HUD→SlotContainer→UpdatePassiveSlots()
- `#include "UI/InGame/PassiveSlotWidget.h"` 추가 (SlotContainerWidget.cpp에)

**태스크:**
- [ ] stub 제거 → 실구현
- [ ] SlotContainerWidget.cpp에 include 추가

### [에디터] WBP 작업
- [ ] WBP_PassiveSlot 신규 (UPassiveSlotWidget 기반) — BindWidget 5개 배치
- [ ] WBP_SlotContainer — PassiveSlotWidget_0~7 배치

---

## REVIEW_STATUS

| 단계 | 상태 | 날짜 | HIGH 요약 |
|------|------|------|-----------|
| Senior-Review | DONE | 2026-04-15 | [CODE] SlotContainerWidget.cpp NativeConstruct: ensureMsgf 후 Skill/Weapon 슬롯 nullptr guard 없음 — 자동수정 대상 |
| Learn-Report | DONE | 2026-04-15 | ensureMsgf-nullptr-guard, include-case-sensitivity, LoadSynchronous-GC |
