# [SR] 2026-04-15 PassiveSlotUI
> PLAN_PassiveSlotUI_v1.0 | 대상 파일 5개

## 반복패턴

- [UPROPERTY 누락] IMPROVED — 이번 세션 모든 멤버 정상 적용 (LoadedPassiveIcon 포함)
- [AddDynamic 위치] RESOLVED — NativeOnInitialized 정확히 준수
- [nullptr guard 없는 역참조] RECURRING (1회) — SlotContainerWidget NativeConstruct 신규 발견
- [include 대소문자 혼용] RECURRING (1회) — UI/Ingame vs UI/InGame 혼용

---

## 통과

- PassiveSlotWidget.h: BindWidget + LoadedPassiveIcon UPROPERTY() 강참조 정상
- NativeOnInitialized: Super 선행 + AddDynamic + Ovl_Tooltip Hidden 초기화 순서 정상
- ensureMsgf: 모든 BindWidget에 guard 적용 (PassiveSlotWidget, SlotContainerWidget)
- GetPassiveSlotWidget switch: default → KHS_WARN + return nullptr
- UpdatePassiveSlots: loop + nullptr check + UpdateSlot/ClearSlot 분기 정상
- OnPassiveSlotChanged: GetWidgetByID 사용 (이미 열린 HUD에 올바른 패턴)
- EndPlay: OnPassiveSlotChangedDel.RemoveDynamic 정상 등록

---

## 이슈

### HIGH [CODE] — 자동수정 대상

**📌 [SR][CODE] | SlotContainerWidget.cpp:27-35 | NativeConstruct ensureMsgf 후 Skill/Weapon 슬롯 nullptr 역참조**

내용: ensureMsgf는 Shipping에서 false 반환 시 실행을 멈추지 않음. SkillSlotWidget_0->InitSlot(0) 등 5개 호출이 nullptr 역참조 위험. 패시브 슬롯은 if (PassiveSlot) guard로 안전하나 Skill/Weapon은 guard 없음 — 패턴 불일관성.

수정: if guard 추가 또는 nullable 패턴으로 통일.

### MED

**PassiveSlotWidget.cpp:55-61 — Icon null 시 기존 브러시 유지**

UpdateSlot에서 PassiveData.Icon이 null이면 Img_PassiveIcon의 브러시가 갱신되지 않음. 패시브 교체 시나리오에서 아이콘 오염 가능. ClearSlot()에서 아이콘 리셋하거나 else 브랜치에서 빈 브러시 세팅 권장.

### LOW

1. PLAN에 Bdr_Tooltip(UBorder)로 기재, 실구현은 Ovl_Tooltip(UOverlay) — PLAN 갱신 필요.
2. SlotContainerWidget.cpp: UI/Ingame(소문자 g) vs UI/InGame(대문자 G) 혼용 — 대문자 G로 통일.

---

## 평가

```
기획서정합: 4/5 | UMG: 4/5 | 메모리: 5/5 | OOP: 4/5 | 컨벤션: 4/5
```
