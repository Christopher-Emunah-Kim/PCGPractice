---
name: ensureMsgf 후 nullptr guard 없는 역참조
description: ensureMsgf로 BindWidget 확인 후 if guard 없이 직접 역참조 — Shipping에서 크래시
type: feedback
---

ensureMsgf는 에디터/Dev 빌드에서 실행을 멈추지 않는다. 포인터가 null인 상태에서 흐름이 계속되면 역참조 크래시 발생.

**발견 위치:** SlotContainerWidget.cpp NativeConstruct (2026-04-15)
- PassiveSlotWidget 추가 시 if guard 패턴을 적용했으나, 기존 Skill/Weapon 슬롯은 guard 없이 직접 역참조.
- 이번 변경으로 두 패턴이 같은 함수 안에 공존하며 불일관성이 드러남.

**Why:** ensureMsgf는 assertion tool이지, flow-guard가 아니다. false 반환 시 실행이 계속되므로 그 아래 역참조는 안전하지 않음.

**How to apply:** NativeConstruct/NativeOnInitialized에서 BindWidget 확인 후 반드시 if guard 또는 early return 추가. ensureMsgf + 역참조 패턴은 항상 의심.
