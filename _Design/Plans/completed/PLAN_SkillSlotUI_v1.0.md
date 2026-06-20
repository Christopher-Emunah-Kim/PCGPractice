# PLAN_SkillSlotUI_v1.0
> 작성: 2026-04-14 | 기획서: 게임 시스템 개선안 v1.0 (PHASE 1 UX)
> 목표: 캐릭터 스킬 Q/E 슬롯 UI 추가 + 무기 슬롯 UX 개선 + SlotContainerWidget 통합

## 범위
- 캐릭터 스킬 슬롯 UI (CharacterSkillSlotWidget 신규)
- 무기 슬롯 빈 슬롯 숨김 처리 (UX)
- WeaponSlotContainerWidget → SlotContainerWidget 일반화
- 순서: 캐릭터 스킬(Q/E) → 무기 슬롯(3개)
- 쿨타임 처리: WeaponSlotWidget과 동일 패턴 (NativeTick 로컬 감소)

## 실행 순서
M-0 → M-1 → M-2 → M-3 → M-4 → M-5 → [에디터]

---

## [MODULE-0] SkillIcon 데이터 스키마 추가 (선행)
> 수정: DataTableStructs.h, RuntimeDataStructs.h, GameDataSubsystem.cpp

### FCharacterSkillStaticData (DataTableStructs.h)
```
추가: TSoftObjectPtr<UTexture2D> SkillIconSoftRef
```

### FCharacterSkillExecData (RuntimeDataStructs.h)
```
추가: TSoftObjectPtr<UTexture2D> SkillIconSoftRef
```

### GameDataSubsystem::GetCharacterSkillExecData() (cpp)
```
ExecData.SkillIconSoftRef = StaticData->SkillIconSoftRef  복사 추가
```

---

## [MODULE-1] SkillManagerSubsystem 쿨타임 데이터 보강
> 수정: SkillManagerSubsystem.h/.cpp

### FSkillSlotState (헤더, non-USTRUCT)
```
추가: float CooldownRemaining = 0.f
추가: float TotalCooldown = 0.f
```

### USkillManagerSubsystem
```
추가: DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnSkillSlotUpdated, int32, SlotIndex)
추가: UPROPERTY() FOnSkillSlotUpdated OnSkillSlotUpdatedDel   // public
추가: const FSkillSlotState* GetSkillSlotState(int32 SlotIndex) const  // public 조회
```

### StartCooldown() 수정
```
CooldownRemaining = Cooldown 값 초기화
TotalCooldown     = Cooldown 값 초기화
OnSkillSlotUpdatedDel.Broadcast(SlotIndex)
타이머 만료 콜백: bIsOnCooldown=false + OnSkillSlotUpdatedDel.Broadcast(SlotIndex)
```

### InitializeSkills() 수정
```
슬롯 초기화 완료 후 각 SlotIndex에 대해 OnSkillSlotUpdatedDel.Broadcast(i)  ← 초기 UI 갱신용
```

---

## [MODULE-2] CharacterSkillSlotWidget 신규
> 신규: Public/UI/Ingame/CharacterSkillSlotWidget.h
>       Private/UI/Ingame/CharacterSkillSlotWidget.cpp

### 인터페이스
```cpp
void InitSlot(int32 InSlotIndex);
void UpdateSlot(const FSkillSlotState* SlotState);
```

### BindWidget (WBP에서 이름 맞춤 필수)
```
Img_SkillIcon          — 스킬 아이콘 (에디터에서 직접 할당)
Img_CooldownOverlay    — 쿨타임 오버레이 (머티리얼 인스턴스)
Txt_CooldownRemaining  — 남은 쿨타임 텍스트
```
> 키 힌트(Q/E), 테두리는 에디터 담당 (코드 없음)

### 동작
```
UpdateSlot():
  - SlotState == nullptr or SkillID == NAME_None → SetVisibility(Collapsed)  ← 빈 슬롯 숨김
  - 쿨타임 중: TotalCooldown/CooldownRemaining 로컬 복사, bIsCooldownActive = true
  - 쿨타임 없음: bIsCooldownActive = false, 오버레이 Collapsed

NativeTick() → UpdateCooldown():
  - WeaponSlotWidget::UpdateCooldown()와 동일 패턴
  - CooldownMID->SetScalarParameterValue("Percent", Remaining/Total)
  - <= 0이면 bIsCooldownActive = false, 오버레이 Collapsed
```

---

## [MODULE-3] SlotContainerWidget 일반화
> 삭제: Public/UI/WeaponSlotContainerWidget.h  Private/UI/WeaponSlotContainerWidget.cpp
> 신규: Public/UI/Ingame/SlotContainerWidget.h  Private/UI/Ingame/SlotContainerWidget.cpp

### 클래스: USlotContainerWidget : public URSBaseWidget

### BindWidget (WBP에서 이름 맞춤 필수)
```
SkillSlotWidget_0   — UCharacterSkillSlotWidget (Q)
SkillSlotWidget_1   — UCharacterSkillSlotWidget (E)
SlotWidget_0        — UWeaponSlotWidget (무기0)  ← 기존 이름 유지
SlotWidget_1        — UWeaponSlotWidget (무기1)
SlotWidget_2        — UWeaponSlotWidget (무기2)
```

### 인터페이스
```cpp
UWeaponSlotWidget*         GetWeaponSlotWidget(int32 SlotIndex) const;   // 기존 GetSlotWidget → 이름 변경
UCharacterSkillSlotWidget* GetSkillSlotWidget(int32 SlotIndex) const;    // 신규
```

### NativeConstruct()
```
무기 슬롯: SlotWidget_0~2 InitSlot(0~2) 호출 (기존)
스킬 슬롯: SkillSlotWidget_0~1 InitSlot(0~1) 호출 (신규)
```

---

## [MODULE-4] WeaponSlotWidget 경로 이동 + UX 수정
> 이동: Public/UI/WeaponSlotWidget.h  → Public/UI/Ingame/WeaponSlotWidget.h
>       Private/UI/WeaponSlotWidget.cpp → Private/UI/Ingame/WeaponSlotWidget.cpp

### UX: 빈 슬롯 숨김 (UpdateSlot 상단에 추가)
```cpp
if (!SlotData || SlotData->IsEmpty())
{
    SetVisibility(ESlateVisibility::Collapsed);
    return;
}
SetVisibility(ESlateVisibility::SelfHitTestInvisible);
// 이하 기존 로직
```

---

## [MODULE-5] RSHUDWidget + RSPlayerController 연결
> 수정: RSHUDWidget.h, RSPlayerController.h/.cpp

### RSHUDWidget
```
UWeaponSlotContainerWidget → USlotContainerWidget 교체
GetSlotContainerWidget() 반환 타입 변경
```

### RSPlayerController
```cpp
// 추가 함수
void OnSkillSlotUpdated(int32 SlotIndex);
void RefreshSkillSlotUI(int32 SlotIndex);

// BeginPlay: 기존 EquipSys 구독 옆에
SkillManagerSys->OnSkillSlotUpdatedDel.AddUniqueDynamic(this, &ARSPlayerController::OnSkillSlotUpdated);

// RefreshSkillSlotUI 구현
// HUD → SlotContainerWidget → GetSkillSlotWidget(SlotIndex) → UpdateSlot(SkillSys->GetSkillSlotState(SlotIndex))

// RefreshSlotUI 기존 함수: GetSlotWidget → GetWeaponSlotWidget 이름 변경
```

---

## [에디터 작업] ← 시니 담당
```
1. WBP_WeaponSlotContainer:
   - 부모 클래스: USlotContainerWidget으로 변경
   - SkillSlotWidget_0, SkillSlotWidget_1 위젯 추가 (UCharacterSkillSlotWidget)
   - 좌측: 스킬 2개 → 우측: 무기 3개 레이아웃 구성

2. WBP_CharacterSkillSlot 신규 생성:
   - 부모: UCharacterSkillSlotWidget
   - BindWidget 이름 맞춤: Img_SkillIcon / Img_CooldownOverlay / Txt_CooldownRemaining
   - Img_CooldownOverlay에 쿨타임 머티리얼 인스턴스 적용 (WBP_WeaponSlot과 동일 머티리얼)

3. WBP_WeaponSlot:
   - 경로 변경에 따른 재컴파일 확인
```

---

## 변경 파일 요약
| 작업 | 파일 |
|------|------|
| 수정 | DataTableStructs.h, RuntimeDataStructs.h, GameDataSubsystem.cpp |
| 수정 | SkillManagerSubsystem.h/.cpp |
| 신규 | Public/UI/Ingame/CharacterSkillSlotWidget.h |
| 신규 | Private/UI/Ingame/CharacterSkillSlotWidget.cpp |
| 신규(기존 대체) | Public/UI/Ingame/SlotContainerWidget.h |
| 신규(기존 대체) | Private/UI/Ingame/SlotContainerWidget.cpp |
| 이동+수정 | Public/UI/Ingame/WeaponSlotWidget.h |
| 이동+수정 | Private/UI/Ingame/WeaponSlotWidget.cpp |
| 수정 | RSHUDWidget.h/.cpp |
| 수정 | RSPlayerController.h/.cpp |
| 삭제 | Public/UI/WeaponSlotContainerWidget.h |
| 삭제 | Private/UI/WeaponSlotContainerWidget.cpp |
