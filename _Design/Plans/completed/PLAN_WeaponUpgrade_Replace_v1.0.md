# PLAN_WeaponUpgrade_Replace_v1.0
```yaml
date:    2026-03-28
sprint:  SPRINT-4
status:  ACTIVE
designs: [무기 시스템 기획 v1.2.md, 레벨업 시스템 기획 v1.2.md]
```

## GOAL
> 무기 강화 로직 구현 — DT에 Lv2/Lv3 무기 데이터를 추가하고, CurveTable 기반 데미지 스케일링 + EquipmentSubsystem 내부 강화 판정 + 슬롯 가득 시 교체 UI를 통해 무기를 교체할 수 있도록 한다.

## SCOPE
```yaml
new_files:
  - Content/Data/DT_WeaponDamageCurve          # UCurveTable 에셋
  - Source/RoastStaffGAS/Public/UI/WeaponReplaceWidget.h
  - Source/RoastStaffGAS/Private/UI/WeaponReplaceWidget.cpp
  - Content/UI/Widgets/WBP_WeaponReplaceWidget

modified_files:
  - Content/ExternalSource/DT_Weapon.csv        # Lv2/Lv3 행 추가
  - Source/RoastStaffGAS/Public/Subsystems/GameDataSubsystem.h
  - Source/RoastStaffGAS/Private/Subsystems/GameDataSubsystem.cpp
  - Source/RoastStaffGAS/Public/Subsystems/EquipmentSubsystem.h
  - Source/RoastStaffGAS/Private/Subsystems/EquipmentSubsystem.cpp
  - Source/RoastStaffGAS/Public/Character/Player/RSPlayerController.h
  - Source/RoastStaffGAS/Private/Character/Player/RSPlayerController.cpp
  - Source/RoastStaffGAS/Private/UI/LevelUpWeaponSelectWidget.cpp

new_datatables:
  - DT_WeaponDamageCurve (UCurveTable)

new_tags: []
```

## FLOW

### Phase B — 강화 로직 (EquipWeapon 내부)
```
[진입점: LevelUpSubsystem → EquipmentSubsystem::EquipWeapon(WeaponID)]
    │
    ▼
[Step 1: GDS.GetWeaponData(WeaponID) → BaseType, WeaponLevel 파악]
    │
    ▼
[Step 2: 동일 BaseType 슬롯 탐색 + NextLevelWeaponID != None 체크]
    ├─ 발견 ──→ [Step 3: UpgradeWeapon(SlotIndex, NextLevelWeaponID)]
    │                 └─ ClearSlot(SlotIndex)
    │                 └─ CommitSlot(SlotIndex, NextWeaponID)  ← 동일 인덱스 유지
    │                 └─ GDS.GetSkillExecutionData(SkillID, WeaponID, WeaponLevel)
    │                       └─ GetWeaponDamageFromCurve(WeaponID, WeaponLevel) → Amount
    │                       └─ SetByCaller → GE_Damage 주입
    │                 └─ DONE
    └─ 미발견 ──→ [Step 4: GetEmptySlotIndex()]
                    ├─ 빈 슬롯 있음 ──→ [Step 5: CommitSlot(EmptyIdx, WeaponID)] → DONE
                    └─ 슬롯 가득 ───→ [Step 6: PendingWeaponID = WeaponID]
                                           └─ OnSlotFull.Broadcast(WeaponID) → DONE

[Phase C 진입: PlayerController::OnSlotFullHandler(PendingWeaponID)]
    │
    ▼
[WeaponReplaceWidget::OpenWithData(슬롯3개, PendingWeaponID)]
    │
    ├─ 슬롯 카드 클릭 → SelectedSlotIndex 갱신 → 확인 버튼 활성화
    │
    └─ 확인 클릭 ──→ EquipmentSubsystem::UpgradeWeapon(SelectedSlotIndex, PendingWeaponID)
                          └─ ClearSlot → CommitSlot → CloseWidget → 게임 재개
```

## SCHEMA

### DT_WeaponDamageCurve (UCurveTable)
```
RowName            | X=1 (Lv1) | X=2 (Lv2)  | X=3 (Lv3)
-------------------|-----------|------------|----------
FIRESTAFF          | 기존값     | 기존×1.7   | 기존×2.8
ICESTAFF           | 기존값     | 기존×1.7   | 기존×2.8
... (7종 동일 패턴)

Interpolation Mode: Constant
RowName 규칙: EWeaponBaseType DisplayName 기준 (예: FIRESTAFF, ICESTAFF) — Lv2/Lv3도 같은 RowName 공유
              이유: WeaponLevel 파라미터로 X축 조회하므로 Row는 무기 종류별 1개면 충분
```

### DT_Weapon.csv 추가 행 규칙
```
WeaponID:           WPN_[TYPENAME]_Lv2, WPN_[TYPENAME]_Lv3
BaseType:           Lv1과 동일
WeaponLevel:        2 또는 3
SkillID:            Lv1과 동일 ID 재사용 (CurveTable이 수치 차이 담당)
NextLevelWeaponID:  Lv2 → WPN_[TYPENAME]_Lv3 / Lv3 → None
Lv1 행 수정:        NextLevelWeaponID = WPN_[TYPENAME]_Lv2 (기존 None → 연결)
```

## EDGE_CASES
```
| 상황                                  | 처리                                         | 기획서 근거                  |
|---------------------------------------|----------------------------------------------|------------------------------|
| 동일 BaseType Lv3 슬롯 존재 시        | NextLevelWeaponID=None → 강화 스킵 → 슬롯가득 분기 | 기획서: Lv3은 최고 단계     |
| 슬롯 가득 + 진화 가능 (스텁)          | 진화 체크 DEFERRED — 현재 강화/교체로만 처리  | 기획서: 진화 별도 시스템     |
| WeaponReplaceWidget 확인 없이 닫기    | 닫기 버튼 없음 — 강제 선택 UI                | 기획서: 교체 UI 스킵 불가    |
| GetWeaponDamageFromCurve 조회 실패    | KHS_WARN + return 0.f + fallback AttackParamData.Amount | 방어적 처리  |
| GetSkillExecutionData WeaponID=None   | fallback: 기존 AttackParamData.Amount 사용   | 비무기 스킬(AI 등) 호환      |
| 연속 레벨업으로 교체 UI 중첩 시       | DEFERRED — 이번 범위 제외                    | 기획서 미정의               |
```

## MODULES

### Phase A — 데이터
```
MODULE-0: DT_WeaponDamageCurve CurveTable 생성
  에디터: Miscellaneous → Curve Table (Float) 생성
  RowName = EWeaponBaseType DisplayName (예: FIRESTAFF, ICESTAFF)
  X축 = WeaponLevel (1/2/3), Y축 = Damage
  Interpolation: Constant
  수치: Lv1=기존값, Lv2=기존×1.7, Lv3=기존×2.8

MODULE-1: DT_Weapon CSV Lv2/Lv3 행 추가
  신규 14행 (7종 × 2레벨)
  SkillID: Lv1과 동일 재사용
  Lv1 행 NextLevelWeaponID 수정 (None → Lv2 ID)
  에디터 DT 리임포트 후 총 21행 확인
```

### Phase B — 백엔드
```
MODULE-2: GDS CurveTable 등록 + GetWeaponDamageFromCurve
  - UPROPERTY() UCurveTable* WeaponDamageCurveTable
  - Initialize에서 에셋 로드
  - float GetWeaponDamageFromCurve(FName WeaponID, int32 WeaponLevel) const

MODULE-3: GDS GetSkillExecutionData 시그니처 변경
  - 파라미터 추가: FName WeaponID, int32 WeaponLevel
  - WeaponID != None && Level > 0 → CurveTable 조회
  - fallback: 기존 AttackParamData.Amount (WeaponID=None 호출부 보호)
  - 호출부 Grep 필수: GetSkillExecutionData

MODULE-4: EquipmentSubsystem ClearSlot 헬퍼 분리
  - void ClearSlot(int32 SlotIndex)
  - GA ClearAbility + 오브젝트 Destroy + SlotData 초기화

MODULE-5: EquipWeapon 강화 판정 내재화 + OnSlotFull 델리게이트
  - EquipWeapon 내부 처리 순서: 강화체크 → 빈슬롯 → 슬롯가득
  - void UpgradeWeapon(int32 SlotIndex, FName NextWeaponID)
    → ClearSlot(SlotIndex) + CommitSlot(SlotIndex, NextWeaponID)
  - DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnSlotFull, FName, PendingWeaponID)
  - UPROPERTY BlueprintAssignable FOnSlotFull OnSlotFull
```

### Phase C — UI
```
MODULE-6: WeaponReplaceWidget 신규
  - URSBaseWidget 상속, UILayer=POPUP, bIsModal=true
  - void OpenWithData(슬롯데이터 배열, FName PendingWeaponID)
  - 슬롯 카드 3개 + 확인 버튼 (닫기 버튼 없음 — 스킵 불가)
  - 슬롯 테두리 색: Lv1=흰색, Lv2=녹색, Lv3=금색
  - NativeOnInitialized에 AddDynamic 배치 (취약패턴 방지)
  - 확인 → EquipmentSubsystem::UpgradeWeapon(SelectedSlot, PendingWeaponID) → CloseUI

MODULE-7: RSPlayerController OnSlotFull 연결
  - OnSlotFull.AddDynamic → OnSlotFullHandler(FName PendingWeaponID)
  - UIManagerSubsystem으로 WeaponReplaceWidget 오픈
  - SetPause(true) + SetInputMode UI + SetShowMouseCursor(true)  ← 쌍으로 작성
  - WeaponReplaceWidget 완료 후 → SetPause(false) + GameOnly 모드 복원

MODULE-8: LevelUpWeaponSelectWidget 단순화
  - EquipAndClose 내 EquipWeapon(SelectedWeaponID) 단순 호출
  - 강화 체크 로직 불필요 (EquipmentSubsystem 내부 처리)
  - CardState 시각 표시 확인 (New/Lv1ToLv2/Lv2ToLv3/Lv3Max 텍스트+테두리)
```

## REVIEW_NOTES
```
기획서 일관성: ✓
  - 교체 UI 스킵 불가 (닫기 버튼 없음) 기획서 준수
  - 강화 체크 우선순위: 강화 → 빈슬롯 → 교체 기획서 준수
  - 진화 시스템 이번 범위 제외 기획서 준수

누락 예외처리:
  - 연속 레벨업 + 교체 UI 중첩 케이스 DEFERRED
  - 소환형 무기 Lv2/Lv3 GA 분리 필요 여부 DEFERRED

기획서 정정:   없음
Gemini 반영:   미진행
```

---
## REVIEW_STATUS
```
| 단계          | 상태 | 날짜       | 주요 지적 |
|---------------|------|------------|-----------|
| Cross-Review  | -    | -          | -         |
| Senior-Review | DONE | 2026-03-30 | HIGH#2 TimeDilation 교체UI 누락(DEFERRED), HIGH#3 RowName 문서 오류(수정완료) |
| Learn-Report  | -    | -          | -         |

verdict:    SR_ISSUES
unresolved: [HIGH#2 TimeDilation 교체UI 미적용 — TODO P1]
```
