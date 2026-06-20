# PLAN_Phase1_InGame_v1.0
> 작성일: 2026-04-10
> 기획서: _Design/References/Systems/게임 시스템 개선안 v1.0.md
> 목표: PHASE-1 인게임 루프 완성 (5대 시스템)

---

## 아키텍처 흐름

```
CSV/DT_Weapon ──→ GDS
  → EquipmentSubsystem::StartAutoFireLoop(SlotIndex)
    └─ FindNearestEnemy() → FireSlot() → GA_ProjectileAttack

CSV/DT_CharacterSkill ──→ GDS
  → SkillManagerSubsystem::InitializeSkills(CharID)
    → ASC.GiveAbility(GA_CharacterSkill)
    → ActivateSkill(Slot) ─┬─ InstantAoE/SelfBuff → GA 즉발
                           └─ SpawnPreview → SummonPreviewObject 재활용
                               ├─ LMB 확정 → GA 발동 + 쿨타임
                               └─ RMB 취소 → 쿨타임 없음

CSV/DT_LevelUpCard + DT_Passive ──→ LevelUpSubsystem::BuildCardPool()
  ├─ 정적: StatUpgrade + PassiveAdd(슬롯<4)
  ├─ 동적: 장착무기 업그레이드 + 새무기 획득
  └─ 최소 보장: 무기 카드 1장 강제 포함
     → PassiveAdd 선택 → PassiveSlotSubsystem::TryAddPassive()
                         → ASC.ApplyGE(영구)

GE_WeaponDamage / GE_EnemyDamage
  → RS_DamageExecCalc
    ├─ 플레이어→에너미: BaseDmg × (1+ATK/100) × CritMult
    └─ 에너미→플레이어: max(1, EnemyDmg - DEF)
```

---

## 설계 결정 (시니 확정 2026-04-10)

| # | 결정 | 내용 |
|---|------|------|
| SD1 | 무기 슬롯 수 | SLOT_COUNT = **2** (기존 3 → 2로 변경) |
| SD2 | 캐릭터 스킬 슬롯 | 무기 슬롯과 **별개** 2슬롯. Q/E 키 고정. 캐릭터 전환 시 교체. |
| SD3 | SpawnPreview 구현체 | **SummonPreviewObject 재활용** (신규 PreviewActor 미제작) |
| SD4 | EvolutionTag 전환 | **병행 유지**: EWeaponBaseType 존치 + FString EvolutionTag 신규 추가. 완전 제거는 추후. |

---

## 통합 지점

| 역할 | 소유 | 진입점 |
|------|------|--------|
| 자동발사 | UEquipmentSubsystem | CommitSlot() → StartAutoFireLoop() |
| 스킬 초기화 | USkillManagerSubsystem (신규) | ARSPlayerCharacter::InitializeAbilitySystem() |
| ExecCalc | GE_WeaponDamage / GE_EnemyDamage BP | Executions 배열 교체 |
| 카드풀 | ULevelUpSubsystem | CheckLevelUp() → BuildCardPool() |
| 패시브 적용 | UPassiveSlotSubsystem (신규) | LevelUpSubsystem::OnCardSelected(PassiveAdd) |

---

## 모듈 목록

### MODULE-1 [P0] DataTable 스키마 확장
> 선행 필수. 이후 모든 모듈이 의존.

**수정 파일**
- `Source/RoastStaffGAS/Public/Data/EnumTypes.h`
- `Source/RoastStaffGAS/Public/Data/DataTableStructs.h`
- `Source/RoastStaffGAS/Public/Data/RuntimeDataStructs.h`

**태스크**
- [ ] EnumTypes.h: `ESkillActivationType { InstantAoE, SpawnPreview, SelfBuff }` 추가
- [ ] EnumTypes.h: `ELevelUpCardType { StatUpgrade, PassiveAdd, WeaponUpgrade, WeaponNew }` 추가
- [ ] DataTableStructs.h: FWeaponStaticData — `FString EvolutionTag` 추가 (EWeaponBaseType 병행 유지, SD4)
- [ ] DataTableStructs.h: FWeaponStaticData — `bool IsUnlocked = false`, `int32 UnlockCost = 0` 추가
- [ ] DataTableStructs.h: `FCharacterSkillLevelData` USTRUCT 신규 (기본값 필수)
- [ ] DataTableStructs.h: `FCharacterSkillStaticData : FTableRowBase` 신규
- [ ] DataTableStructs.h: `FPassiveStaticData : FTableRowBase` 신규
- [ ] DataTableStructs.h: `FLevelUpCardStaticData : FTableRowBase` 신규
- [ ] RuntimeDataStructs.h: `FCharacterSkillExecData` USTRUCT 신규
- [ ] RuntimeDataStructs.h: `FLevelUpCardDisplayData` USTRUCT 신규

---

### MODULE-2 [P0] GDS 신규 DT 통합
> MODULE-1 완료 후. M-3/M-4는 M-2 완료 후 병렬 진행 가능.

**수정 파일**
- `Source/RoastStaffGAS/Public/Data/GameDataConfig.h`
- `Source/RoastStaffGAS/Public/Subsystems/GameDataSubsystem.h`
- `Source/RoastStaffGAS/Private/Subsystems/GameDataSubsystem.cpp`

**태스크**
- [ ] GameDataConfig.h: DT_CharacterSkill / DT_LevelUpCard / DT_Passive 에셋 경로 추가
- [ ] GameDataSubsystem.h: 신규 테이블 UPROPERTY() UDataTable* 3개 추가
- [ ] GameDataSubsystem.h: TMap 캐시 3종 추가 (CharacterSkill / LevelUpCard / Passive)
- [ ] GameDataSubsystem.h: 조회 함수 7개 선언
- [ ] GameDataSubsystem.cpp: LoadDataTables() 신규 3개 추가
- [ ] GameDataSubsystem.cpp: CacheAllData() 신규 3개 추가
- [ ] GameDataSubsystem.cpp: GetCharacterSkillExecData() 구현 (Level 클램프 1~3)
- [ ] GameDataSubsystem.cpp: GetSkillsByCharacter() 구현 (SkillSlot 정렬)

---

### MODULE-3 [P0] 무기 자동발사 전환
> MODULE-2 완료 후. MODULE-4와 병렬 가능.

**수정 파일**
- `Source/RoastStaffGAS/Public/Subsystems/EquipmentSubsystem.h`
- `Source/RoastStaffGAS/Private/Subsystems/EquipmentSubsystem.cpp`
- `Source/RoastStaffGAS/Public/Character/Player/RSPlayerController.h`
- `Source/RoastStaffGAS/Private/Character/Player/RSPlayerController.cpp`

**태스크**
- [ ] EquipmentSubsystem: SLOT_COUNT = 2로 변경 (SD1)
- [ ] EquipmentSubsystem: `RequestManualFire()` 제거
- [ ] EquipmentSubsystem: `FindNearestEnemy(float SearchRadius) -> AActor*` 헬퍼 추가
- [ ] EquipmentSubsystem: `StartAutoFire()` — FindNearestEnemy() 기반으로 교체, 타겟 없으면 스킵
- [ ] EquipmentSubsystem: `CommitSlot()` 이후 StartAutoFire() 자동 호출
- [ ] EquipmentSubsystem: `FireSlot()` — AimLocation → FindNearestEnemy() 결과 위치 사용
- [ ] RSPlayerController: `IA_Attack` UPROPERTY 제거
- [ ] RSPlayerController: `OnShootStart()` / `IA_Slot1/2/3` 바인딩 제거
- [ ] RSPlayerController: IA_SkillQ / IA_SkillE UPROPERTY 추가 (M-5 진입점 준비)

---

### MODULE-4 [P0] ExecCalc 데미지 공식
> MODULE-1 완료 후. MODULE-3과 병렬 가능.

**신규 파일**
- `Source/RoastStaffGAS/Public/GAS/Calculations/RS_DamageExecCalc.h`
- `Source/RoastStaffGAS/Private/GAS/Calculations/RS_DamageExecCalc.cpp`

**수정 파일**
- `Source/RoastStaffGAS/Public/GAS/Tags/RSGameplayTags.h`
- `Source/RoastStaffGAS/Private/GAS/Abilities/GA_ProjectileAttack.cpp`

**태스크**
- [ ] RSGameplayTags.h: `Data.WeaponBaseDamage` / `Data.EnemyAttackDamage` SetByCaller 태그 추가
- [ ] RS_DamageExecCalc.h: UGameplayEffectExecutionCalculation 상속, 어트리뷰트 캡처 정의 (ATK / DEF / CritRate / CritDmg)
- [ ] RS_DamageExecCalc.cpp: 플레이어→에너미 공식: `BaseDmg × (1 + ATK/100) × CritMult`
- [ ] RS_DamageExecCalc.cpp: 에너미→플레이어 공식: `max(1, EnemyDmg - DEF)`
- [ ] RS_DamageExecCalc.cpp: Source/Target 타입 체크로 분기 결정
- [ ] GA_ProjectileAttack.cpp: WeaponBaseDamage를 SetByCallerMagnitude로 GE에 주입
- [ ] GE_WeaponDamage / GE_EnemyDamage BP: Executions 배열에 URS_DamageExecCalc 추가 — 빌드 후 에디터 작업

---

### MODULE-5 [P1] 캐릭터 스킬 시스템
> MODULE-1, 2 완료 후. MODULE-7과 병렬 가능.

**신규 파일**
- `Source/RoastStaffGAS/Public/Subsystems/SkillManagerSubsystem.h`
- `Source/RoastStaffGAS/Private/Subsystems/SkillManagerSubsystem.cpp`
- `Source/RoastStaffGAS/Public/GAS/Abilities/GA_CharacterSkill.h`
- `Source/RoastStaffGAS/Private/GAS/Abilities/GA_CharacterSkill.cpp`

**수정 파일**
- `Source/RoastStaffGAS/Public/Character/Player/RSPlayerController.h`
- `Source/RoastStaffGAS/Private/Character/Player/RSPlayerController.cpp`
- `Source/RoastStaffGAS/Public/Character/Player/RSPlayerCharacter.h`
- `Source/RoastStaffGAS/Private/Character/Player/RSPlayerCharacter.cpp`
- `Source/RoastStaffGAS/Public/GAS/Tags/RSGameplayTags.h`

**태스크**
- [ ] RSGameplayTags.h: `Skill.Character.Slot1/Slot2`, `Skill.Character.Preview.Active` 태그 추가
- [ ] SkillManagerSubsystem.h: UWorldSubsystem 상속, 핵심 API 5개 선언
- [ ] SkillManagerSubsystem.cpp: InitializeSkills() — GDS 조회 → ASC.GiveAbility() × 2
- [ ] SkillManagerSubsystem.cpp: ActivateSkillSlot() — ActivationType 분기 (InstantAoE/SelfBuff/SpawnPreview)
- [ ] SkillManagerSubsystem.cpp: SpawnPreview 진입 → SummonPreviewObject 재활용 (SD3)
- [ ] SkillManagerSubsystem.cpp: ConfirmSkillPreview(WorldLocation) — GA 발동 + 쿨타임 GE 적용
- [ ] SkillManagerSubsystem.cpp: CancelSkillPreview() — FX 제거, 쿨타임 미소모
- [ ] GA_CharacterSkill.h/.cpp: UGA_Base 상속, InstantAoE / SelfBuff 구현
- [ ] RSPlayerController: IA_SkillQ/E 바인딩 → SkillManagerSubsystem::ActivateSkillSlot(1|2)
- [ ] RSPlayerController: IsPreviewActive() 시 LMB → Confirm, RMB → Cancel 분기
- [ ] RSPlayerCharacter::InitializeAbilitySystem(): SkillManagerSubsystem::InitializeSkills() 호출 추가

---

### MODULE-6 [P1] 레벨업 카드풀 확장
> MODULE-7 완료 후 (IsSlotFull() 의존).

**수정 파일**
- `Source/RoastStaffGAS/Public/Subsystems/LevelUpSubsystem.h`
- `Source/RoastStaffGAS/Private/Subsystems/LevelUpSubsystem.cpp`
- `Source/RoastStaffGAS/Public/Character/Player/RSPlayerController.h`
- `Source/RoastStaffGAS/Private/Character/Player/RSPlayerController.cpp`
- `Source/RoastStaffGAS/Public/UI/LevelUpWeaponSelectWidget.h`

**태스크**
- [ ] LevelUpSubsystem: FOnWeaponCandidatesReady → `FOnCardPoolReady(TArray<FLevelUpCardDisplayData>)` 교체
- [ ] LevelUpSubsystem: BuildStaticCardPool() — DT_LevelUpCard 전체 + 패시브 슬롯 포화 필터
- [ ] LevelUpSubsystem: BuildDynamicWeaponCards() — 장착 무기 업그레이드 + 새무기 획득 카드 생성
- [ ] LevelUpSubsystem: EnsureWeaponCardGuarantee() — 무기 카드 최소 1장 강제
- [ ] LevelUpSubsystem: PickFinalCards() — 가중 랜덤 3장 (중복 제거)
- [ ] LevelUpSubsystem: OnCardSelected(CardID) — 카드 타입별 분기 (StatUpgrade/PassiveAdd/WeaponUpgrade/WeaponNew)
- [ ] RSPlayerController: OnCardPoolReady 핸들러로 교체
- [ ] LevelUpWeaponSelectWidget: FLevelUpCardDisplayData 수신, CardType별 UI 분기

---

### MODULE-7 [P1] 패시브 슬롯 시스템
> MODULE-1, 2 완료 후. MODULE-5와 병렬 가능. MODULE-6 선행 필수.

**신규 파일**
- `Source/RoastStaffGAS/Public/Subsystems/PassiveSlotSubsystem.h`
- `Source/RoastStaffGAS/Private/Subsystems/PassiveSlotSubsystem.cpp`

**수정 파일**
- `Source/RoastStaffGAS/Public/Character/Player/RSPlayerCharacter.h`
- `Source/RoastStaffGAS/Private/Character/Player/RSPlayerCharacter.cpp`
- `Source/RoastStaffGAS/Public/GAS/Tags/RSGameplayTags.h`
- `Source/RoastStaffGAS/Public/UI/InGame/CharacterStatPopupWidget.h`
- `Source/RoastStaffGAS/Private/UI/InGame/CharacterStatPopupWidget.cpp`
- `Source/RoastStaffGAS/Public/GAS/Attributes/BaseAttributeSet.h`
- `Source/RoastStaffGAS/Public/GAS/Attributes/PlayerAttributeSet.h`
- `Source/RoastStaffGAS/Private/GAS/Attributes/BaseAttributeSet.cpp`
- `Source/RoastStaffGAS/Private/GAS/Attributes/PlayerAttributeSet.cpp`
- `Source/RoastStaffGAS/Private/Subsystems/LevelUpSubsystem.cpp`
- `Source/RoastStaffGAS/Private/Character/Enemy/BossEnemy.cpp`
- `Source/RoastStaffGAS/Public/Character/Enemy/BossEnemy.h`

**태스크**
- [ ] RSGameplayTags.h: `Passive.SlotFull` 태그 추가
- [ ] PassiveSlotSubsystem.h: UWorldSubsystem 상속, MAX_SLOTS=4, TryAddPassive / IsSlotFull / GetEquippedPassives 선언
- [ ] PassiveSlotSubsystem.cpp: TryAddPassive() — GDS 조회 → GE LoadSynchronous → ASC.ApplyGE(영구)
- [ ] PassiveSlotSubsystem.cpp: IsSlotFull() — EquippedPassiveIDs.Num() >= MAX_SLOTS
- [ ] PassiveSlotSubsystem.cpp: OnPassiveSlotChangedDel 브로드캐스트
- [ ] RSPlayerCharacter: InitializeAbilitySystem()에서 PassiveSlotSubsystem::InitializeSubsystem(ASC) 호출
- [ ] RSPlayerController: OnPassiveSlotChangedDel 구독 → HUD UI 갱신 트리거

---

## 미해결 사항 (구현 중 확인)

| # | 항목 | 확인 방법 |
|---|------|---------|
| U1 | CharacterID 런타임 접근 경로 | RuntimeDataSubsystem vs SaveGameSubsystem 중 어디서 조회 |
| U2 | WeaponBaseDamage 주입 방식 | GA_ProjectileAttack::BuildInitData() 기존 Amount 파라미터 확인 |
| U3 | StatUpgrade 카드 GE 적용 방식 | 기존 레벨업 GE 재사용 vs 신규 GE 7종 여부 |
| U4 | 패시브 슬롯 HUD 위치 | RSHUDWidget 통합 vs 별도 위젯 |
| U5 | SpawnPreview FX 스폰 주체 | SkillManagerSubsystem 직접 vs SummonPreviewObject |
