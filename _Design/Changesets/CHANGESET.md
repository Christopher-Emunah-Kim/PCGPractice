# CHANGESET — RoastStaffGAS
> 에이전트용 코드 변화 추적.
> 세션 시작 시: PENDING_COMMIT 항목만 확인 (COMMITTED는 건너뜀).
> 최신 항목이 위에.

## READ_STRATEGY
```
세션 시작: status=PENDING_COMMIT 항목만 읽기
compact 트리거: COMMITTED 항목 5개 초과 시
compact 방법: COMMITTED 항목 → 별도 확인 없이 제거 (Plans/completed/에 이미 반영)
```

## PENDING_COMMIT

- date: 2026-05-06
  plan: ad-hoc (Painter06 HomingBounce)
  status: COMMITTED
  commits: ["0cbfc7167", "a44116c67"]
  summary: "fix(painter06): HomingBounce Lifetime 연장 — 유도 전 소멸 수정"
  files:
    modified:
      - ExternalSource/DT_Character_Skill_Static_Data.csv

- date: 2026-05-06
  plan: PLAN_LevelUpSubsystemReinit_v1.0
  status: COMMITTED
  commits: ["6aaad8f19", "467f7f0c3", "314359656", "3df788e94"]
  summary: "fix(levelup): EXP 구독 누락 수정 + fix(vortex): FX Z오프셋 + chore: 에디터 에셋"
  files:
    modified:
      - Source/RoastStaffGAS/Public/Subsystems/LevelUpSubsystem.h
      - Source/RoastStaffGAS/Private/Subsystems/LevelUpSubsystem.cpp
      - Source/RoastStaffGAS/Private/Core/RSGameMode.cpp
      - Source/RoastStaffGAS/Public/Objects/GroundEffect/PullVortexActor.h
      - Source/RoastStaffGAS/Private/Objects/GroundEffect/PullVortexActor.cpp

- date: 2026-05-06
  plan: PLAN_PauseBugFix_v1.0
  status: COMMITTED
  commits: ["b32c3208e", "64962955c"]
  summary: "fix(ui-pause): TimeDilation 중 쿨타임·회전 버그 수정 + docs"
  files:
    modified:
      - Source/RoastStaffGAS/Public/UI/RSBaseWidget.h
      - Source/RoastStaffGAS/Public/Subsystems/UIManagerSubsystem.h
      - Source/RoastStaffGAS/Private/Subsystems/UIManagerSubsystem.cpp
      - Source/RoastStaffGAS/Private/Character/Player/RSPlayerController.cpp
      - Source/RoastStaffGAS/Private/UI/InGame/WeaponSlotWidget.cpp
      - Source/RoastStaffGAS/Private/UI/InGame/CharacterSkillSlotWidget.cpp
      - Content/UI/Ingame/Levelup/WBP_LevelUpWeaponSelect.uasset
      - Content/UI/Ingame/Levelup/WBP_WeaponReplaceUI.uasset
    created:
      - _Design/Plans/active/PLAN_PauseBugFix_v1.0.md

- date: 2026-05-06
  plan: PLAN_EnemyHitMontage_v1.0
  status: COMMITTED
  commits: ["6c2406d1a", "1f8fa07f9", "bd76571ee", "2e1ff5447"]
  summary: "fix(ga): GA 좀비 상태 수정 + feat(enemy): HitMontage/AttackMontage + ABP 에셋"
  files:
    modified:
      - Source/RoastStaffGAS/Private/GAS/Abilities/GA_CharacterSkill.cpp
      - Source/RoastStaffGAS/Public/Data/DataTableStructs.h
      - Source/RoastStaffGAS/Public/Character/Enemy/EnemyBaseCharacter.h
      - Source/RoastStaffGAS/Private/Character/Enemy/EnemyBaseCharacter.cpp
      - Source/RoastStaffGAS/Public/Character/Enemy/EnemyAIController.h
      - Source/RoastStaffGAS/Public/Character/Enemy/MeleeEnemy.h/.cpp
      - Source/RoastStaffGAS/Public/Character/Enemy/RangedEnemy.h/.cpp
      - Source/RoastStaffGAS/Public/Character/Enemy/EliteEnemy.h/.cpp
      - Source/RoastStaffGAS/Public/Character/Enemy/BossEnemy.h/.cpp
      - Content/Data/Enemy/DT_Enemy_Static_Data.uasset
      - Content/Data/Enemy/DT_Enemy_ExtData.uasset
      - ExternalSource/DT_Enemy_Static_Data.csv
      - ExternalSource/DT_Enemy_ExtData.csv
      - Content/Blueprint/Enemy/{Melee,Ranged,Elite,Boss}/*.uasset
      - Content/Assets/HFLizardCreatures/**/*.uasset

- date: 2026-05-06
  plan: PLAN_EnemyHitMontage_v1.0 (hotfix)
  status: COMMITTED
  commits: ["eb929aa3c"]
  summary: "fix(pooling): 오토마톤 투사체 PreWarm 누락 수정"
  files:
    modified:
      - Source/RoastStaffGAS/Public/Objects/AutomatonActor.h
      - Source/RoastStaffGAS/Private/Core/RSGameMode.cpp

- date: 2026-05-04
  plan: PLAN_Hawkeye_Skills_v1.0 MODULE-7
  status: COMMITTED
  commits: ["4efe08474"]
  summary: "feat(snipe): GA_CharacterSkill_Charge + PC LMB 브릿지 + SkillMgr ChargeAndRelease"
  files:
    created:
      - Source/RoastStaffGAS/Public/GAS/Abilities/GA_CharacterSkill_Charge.h
      - Source/RoastStaffGAS/Private/GAS/Abilities/GA_CharacterSkill_Charge.cpp
    modified:
      - Source/RoastStaffGAS/Public/GAS/Tags/RSGameplayTags.h
      - Source/RoastStaffGAS/Private/GAS/Tags/RSGameplayTags.cpp
      - Source/RoastStaffGAS/Private/Subsystems/SkillManagerSubsystem.cpp
      - Source/RoastStaffGAS/Public/Character/Player/RSPlayerController.h
      - Source/RoastStaffGAS/Private/Character/Player/RSPlayerController.cpp
      - Source/RoastStaffGAS/Public/UI/RSHUDWidget.h
      - Source/RoastStaffGAS/Private/UI/RSHUDWidget.cpp

- date: 2026-05-04
  plan: PLAN_Hawkeye_Skills_v1.0 MODULE-8
  status: COMMITTED
  commits: ["0eac6728c"]
  summary: "feat(charge-gauge): ChargeGaugeWidget + RSHUDWidget 실구현"
  files:
    created:
      - Source/RoastStaffGAS/Public/UI/InGame/ChargeGaugeWidget.h
      - Source/RoastStaffGAS/Private/UI/InGame/ChargeGaugeWidget.cpp
      - Content/UI/Ingame/Player/WBP_ChargeGuage.uasset
    modified:
      - Content/UI/Ingame/WBP_HUD.uasset

- date: 2026-05-04
  plan: PLAN_Hawkeye_Skills_v1.0 MODULE-9
  status: COMMITTED
  commits: ["ca97eb737"]
  summary: "data(hawkeye): 스나이프 DT 행 + GE BP + 에디터 에셋"
  files:
    created:
      - Content/Animation/Character/Hawkeye/AM_HawkEye_Skill06.uasset
      - Content/Blueprint/Objects/Projectiles/CharacterSkill/BP_Projectile_HawkEye06.uasset
      - Content/GAS/GA/Character/HawkEye/GA_CharacterSkill_HawkEye06.uasset
    modified:
      - Content/Data/Skill/Character/DT_Character_Skill_Static_Data.uasset
      - ExternalSource/DT_Character_Skill_Static_Data.csv
      - Content/Input/IA_Attack.uasset
      - Content/Data/Enemy/DT_Enemy_Static_Data.uasset

- date: 2026-05-04
  plan: PLAN_Hawkeye_Skills_v1.0 MODULE-6
  status: COMMITTED
  commits: ["8adcab3e1", "50bcf157e"]
  summary: "feat(automaton): AutomatonActor C++ 구현 + 에디터 에셋"
  files:
    created:
      - Source/RoastStaffGAS/Public/Objects/AutomatonActor.h
      - Source/RoastStaffGAS/Private/Objects/AutomatonActor.cpp
      - Content/Blueprint/Objects/SummonObjects/BP_AutomatonActor.uasset
      - Content/Blueprint/Objects/Projectiles/CharacterSkill/BP_Projectile_Automaton.uasset
      - Content/GAS/GA/Character/HawkEye/GA_CharacterSkill_HawkEye05.uasset
      - Content/Animation/Character/Hawkeye/AM_HawkEye_Skill05.uasset
    modified:
      - Source/RoastStaffGAS/Public/Data/RuntimeDataStructs.h
      - Source/RoastStaffGAS/Private/GAS/Abilities/GA_CharacterSkill.cpp
      - Content/Data/Skill/Character/DT_Character_Skill_Static_Data.uasset
      - Content/Assets/LootandPickupVFXPack/LootVFX/Glows/RingsTheme/NS_RingsGlow01_Once.uasset

- date: 2026-05-04
  plan: PLAN_Hawkeye_Skills_v1.0 MODULE-5
  status: COMMITTED
  commits: ["7baba80e8", "7a75bde6a"]
  summary: "feat(hawkeye): 애로우레인 C++ + bUseRootMotion + 에디터 에셋 + GE 경로 정리"
  files:
    modified:
      - Source/RoastStaffGAS/Public/GAS/Abilities/GA_CharacterSkill.h
      - Source/RoastStaffGAS/Private/GAS/Abilities/GA_CharacterSkill.cpp
      - ExternalSource/DT_Character_Skill_Static_Data.csv
      - Content/Data/Skill/Character/DT_Character_Skill_Static_Data.uasset
      - Content/GAS/GA/Character/HawkEye/GA_CharacterSkill_HawkEye02.uasset
      - Content/GAS/GA/Character/HawkEye/GA_CharacterSkill_HawkEye03.uasset
      - Content/GAS/GA/Character/Painter/GA_CharacterSkill_Painter01.uasset
      - Content/GAS/GA/Character/GA_CharacterSkill_SpawnProjectile.uasset
      - Content/Blueprint/Core/BP_RSGameMode.uasset
    created:
      - Content/Animation/Character/Hawkeye/AM_HawkEye_Skill04.uasset
      - Content/Blueprint/Objects/Projectiles/CharacterSkill/BP_Projectile_HawkEye04.uasset
      - Content/GAS/GA/Character/HawkEye/GA_CharacterSkill_HawkEye04.uasset
      - Content/GAS/GE/Skill/GE_Slow.uasset
      - Content/GAS/GE/Skill/GE_AutomatonHeal.uasset
    renamed:
      - Content/GAS/GE/GE_Stun.uasset → Content/GAS/GE/Skill/GE_Stun.uasset
      - Content/GAS/GE/GE_Damage_KnockDown.uasset → Content/GAS/GE/Skill/GE_Damage_KnockDown.uasset

- date: 2026-05-04
  plan: PLAN_Hawkeye_Skills_v1.0 skill-slot-name
  status: COMMITTED
  commits: ["51beed498"]
  summary: "feat(skill-slot-name): 캐릭터 스킬 슬롯 DisplayName 표시"
  files:
    modified:
      - Source/RoastStaffGAS/Public/Data/DataTableStructs.h
      - Source/RoastStaffGAS/Public/Data/RuntimeDataStructs.h
      - Source/RoastStaffGAS/Private/Subsystems/GameDataSubsystem.cpp
      - Source/RoastStaffGAS/Public/UI/InGame/CharacterSkillSlotWidget.h
      - Source/RoastStaffGAS/Private/UI/InGame/CharacterSkillSlotWidget.cpp
      - ExternalSource/DT_Character_Skill_Static_Data.csv
      - Content/Data/Skill/Character/DT_Character_Skill_Static_Data.uasset
      - Content/UI/Ingame/SkillSlot/WBP_CharacterSkillSlot.uasset

- date: 2026-05-03
  plan: PLAN_Hawkeye_Skills_v1.0 MODULE-4 + PLAN_CharacterMeshApply_v1.0
  status: COMMITTED
  commits: ["fbafe9985", "3ddca93d1", "3624c6080", "718aca3ac"]
  summary: "feat(chain-trap): ChainTrapVortexActor + fix(backstep) + feat(character-mesh) + data(hawkeye)"
  files:
    created:
      - Source/RoastStaffGAS/Public/Objects/GroundEffect/ChainTrapVortexActor.h
      - Source/RoastStaffGAS/Private/Objects/GroundEffect/ChainTrapVortexActor.cpp
      - Content/Animation/Character/Hawkeye/AM_HawkEye_Skill01.uasset
      - Content/Animation/Character/Hawkeye/AM_HawkEye_Skill02.uasset
      - Content/Animation/Character/Hawkeye/AM_HawkEye_Skill03.uasset
      - Content/Blueprint/Objects/GroundedEffectActor/BP_ChainTrapActor.uasset
      - Content/GAS/GA/Character/HawkEye/GA_CharacterSkill_HawkEye03.uasset
      - Content/GAS/GE/GE_Stun.uasset
      - Content/Assets/Free_Magic/VFX_Niagara/NS_Free_Magic_Circle3_Once.uasset
      - _Design/Plans/active/PLAN_CharacterMeshApply_v1.0.md
    modified:
      - Source/RoastStaffGAS/Public/Core/RSGameMode.h
      - Source/RoastStaffGAS/Private/Core/RSGameMode.cpp
      - Source/RoastStaffGAS/Private/GAS/Abilities/GA_CharacterSkill.cpp
      - ExternalSource/DT_Character_Skill_Static_Data.csv
      - ExternalSource/DT_Character_Static_Data.csv
      - Content/Data/Character/DT_Character_Static_Data.uasset
      - Content/Data/Skill/Character/DT_Character_Skill_Static_Data.uasset
      - Content/GAS/GA/Character/HawkEye/GA_CharacterSkill_HawkEye01.uasset
      - Content/GAS/GA/Character/HawkEye/GA_CharacterSkill_HawkEye02.uasset
      - Content/Blueprint/Character/BP_RSPlayer.uasset
    deleted:
      - Content/Animation/Character/Hawkeye/AM_HawkEye_BurstArrow.uasset

- date: 2026-04-30
  plan: PLAN_Hawkeye_Skills_v1.0
  status: COMMITTED
  commits: ["155ec828a", "f77f5da8c", "d48c1d4a3", "f0c987c38"]
  summary: "feat(hawkeye): AN_HitCheck AnimNotify + 버스트애로우 MODULE-3 완료"
  files:
    created:
      - Source/RoastStaffGAS/Public/Animation/AN_HitCheck.h
      - Source/RoastStaffGAS/Private/Animation/AN_HitCheck.cpp
      - Content/Animation/Character/Hawkeye/AM_HawkEye_BurstArrow.uasset
      - Content/GAS/GA/Character/HawkEye/GA_CharacterSkill_HawkEye02.uasset
      - Content/Blueprint/Objects/GroundedEffectActor/BP_HawkEye_BurstArrow.uasset
      - Content/FX/Skill/HawkEye/ (FX 3종)
    modified:
      - Content/Assets/Archer/Animation/Sequence/02_Attack/07_Skill_Attack/AS_Skill_01_Seq.uasset
      - Content/Blueprint/Character/BP_RSPlayer.uasset
      - Content/Template/Characters/Mannequins/Anims/Unarmed/ABP_Unarmed.uasset
      - ExternalSource/DT_Character_Skill_Static_Data.csv
      - Content/Data/Skill/Character/DT_Character_Skill_Static_Data.uasset
      - Source/RoastStaffGAS/Private/Character/Player/RSPlayerCharacter.cpp
      - Source/RoastStaffGAS/Private/Core/Transition/RSTransitionGameMode.cpp

- date: 2026-04-29
  plan: PLAN_DamageIndicator_v1.0
  status: COMMITTED
  commits: ["621229423", "b05088290", "402fa1e55"]
  summary: "feat(damage-indicator): HUD 피격 비네트 인디케이터 구현 + WBP_HUD 에셋"
  files:
    modified:
      - Source/RoastStaffGAS/Public/UI/RSHUDWidget.h
      - Source/RoastStaffGAS/Private/UI/RSHUDWidget.cpp
      - Source/RoastStaffGAS/Public/Character/Player/RSPlayerController.h
      - Source/RoastStaffGAS/Private/Character/Player/RSPlayerController.cpp
      - Source/RoastStaffGAS/Private/Character/BaseCharacter.cpp
      - Content/UI/Ingame/WBP_HUD.uasset
      - Content/Data/Skill/Character/DT_Character_Skill_Static_Data.uasset
    new:
      - Content/Assets/etc/Material/M_UI_DamageIndicator.uasset
      - _Design/Plans/active/PLAN_DamageIndicator_v1.0.md

- date: 2026-04-27
  plan: PLAN_Hawkeye_Skills_v1.0
  status: COMMITTED
  commits: ["31cf0df31", "7e7b0810e", "b621a8427", "6f999e416", "6cf6e91be"]
  summary: "feat(hawkeye): MODULE-1+2 DT 스키마 + BackstepShot + 에셋"

- date: 2026-04-26
  plan: PLAN_SkillActivationRefactor_v1.0
  status: COMMITTED
  commits: ["73b04c3b7", "d7d0e50b5", "691f6e1ef", "eea16f8d6", "93b86a62e", "83b270b00"]
  summary: "refactor(skill): ESkillActivationType 3축 분리 + GA 2단계 재편 + DT 통폐합 + Pierce BUG_FIX"
  files:
    modified:
      - Source/RoastStaffGAS/Public/Data/EnumTypes.h
      - Source/RoastStaffGAS/Public/Data/DataTableStructs.h
      - Source/RoastStaffGAS/Public/Data/RuntimeDataStructs.h
      - Source/RoastStaffGAS/Public/GAS/Tags/RSGameplayTags.h
      - Source/RoastStaffGAS/Private/GAS/Tags/RSGameplayTags.cpp
      - Source/RoastStaffGAS/Public/GAS/Abilities/GA_CharacterSkill.h
      - Source/RoastStaffGAS/Private/GAS/Abilities/GA_CharacterSkill.cpp
      - Source/RoastStaffGAS/Private/Subsystems/GameDataSubsystem.cpp
      - Source/RoastStaffGAS/Private/Subsystems/SkillManagerSubsystem.cpp
      - Config/DefaultGame.ini
      - ExternalSource/DT_Character_Skill_Static_Data.csv
      - Content/Data/Skill/Character/DT_Character_Skill_Static_Data.uasset
      - _Design/References/ARCH_SNAPSHOT.md
      - _Design/Learning/KnowledgeGaps.md
      - _Design/Portfolio/DEVLOG.md
      - .claude/settings.local.json

- date: 2026-04-26
  plan: PLAN_BossHPBarRefactor_v1.0
  status: COMMITTED
  commits: ["3ba19c363", "72f7479b2", "e4ec76175", "fec8946ac", "3a2eef361"]
  summary: "refactor(boss-hpbar): BossHPBarWidget UMS 의존성 제거 + RSHUDWidget 자식 편입 + 최적화 잔여분"
  files:
    modified:
      - Source/RoastStaffGAS/Public/UI/Enemy/BossHPBarWidget.h
      - Source/RoastStaffGAS/Private/UI/Enemy/BossHPBarWidget.cpp
      - Source/RoastStaffGAS/Public/UI/RSHUDWidget.h
      - Source/RoastStaffGAS/Private/UI/RSHUDWidget.cpp
      - Source/RoastStaffGAS/Public/System/EnemySpawner.h
      - Source/RoastStaffGAS/Private/System/EnemySpawner.cpp
      - Content/UI/Ingame/Enemy/WBP_BossHPBar.uasset
      - Content/UI/Ingame/WBP_HUD.uasset

- date: 2026-04-24
  plan: PLAN_GameMsOpt_v1.0
  status: COMMITTED
  commits: ["8b6c5c06f", "70c8790b5", "888c88484", "f55a7967b", "0cad93d20"]
  summary: "opt(game-ms): AIC/BT Tick 간격 + 거리 기반 CMC/Anim + VisibilityBasedAnimTickOption + FlashTimer 최적화"
  files:
    modified:
      - Source/RoastStaffGAS/Public/Character/Enemy/EnemyAIController.h
      - Source/RoastStaffGAS/Private/Character/Enemy/EnemyAIController.cpp
      - Source/RoastStaffGAS/Public/Character/Enemy/EnemyBaseCharacter.h
      - Source/RoastStaffGAS/Private/Character/Enemy/EnemyBaseCharacter.cpp
  changes:
    - "AIC 생성자: PrimaryActorTick.TickInterval = 0.1f (매 프레임 → 10Hz)"
    - "StartAI: BrainComponent SetComponentTickInterval(0.2f) (BT 결정 5Hz)"
    - "AdjustPawnTickRates: 거리 기반 CMC/Anim 틱 간격 (근거리 매 프레임 / 중거리 30Hz·20Hz / 원거리 20Hz·10Hz)"
    - "EnemyBaseCharacter 생성자: VisibilityBasedAnimTickOption = OnlyTickPoseWhenRendered"
    - "TickEmissiveFade 타이머: 0.016f → FlashTickInterval(0.05f) — 60Hz → 20Hz"

## COMMITTED

- date: 2026-04-24
  plan: PLAN_AsyncLoadOpt_v1.0
  commits: ["15a2e7198", "0734f2ab6", "004886f61", "0f5d568d9", "42db1f8e7"]
  status: COMMITTED
  summary: "opt(async-load) + fix(gc-spike) + chore(config/ppfree) + docs(opt): 퍼포먼스 최적화 세션"

## COMMITTED

- date: 2026-04-22
  plan: PLAN_SkillSystemArch_v1.0 ElementColor 에디터 작업
  commits: ["df93b7515", "1f5cf3bc1", "47de7546b", "e0c48354a", "10184ec32"]
  status: COMMITTED
  files:
    modified:
      - Content/FX/Skill/Painter/NS_Painter_Skill02.uasset
      - Content/FX/Skill/Painter/NS_Painter_Skill03.uasset
      - Content/FX/Skill/Painter/NS_Painter_Skill05.uasset
      - Content/Data/Skill/Character/DT_Character_Skill_Static_Data.uasset
      - Content/Data/Skill/DT_Skill_Common_Resource_Data.uasset
      - Content/Data/Stage/DT_Wave_Static_Data.uasset
      - Content/Blueprint/Enemy/BP_EnemySpawner.uasset
      - Content/Map/Map_Lobby.umap
      - Content/UI/Lobby/StageSelect/WBP_StageSelectPage.uasset
      - ExternalSource/DT_Wave_Static_Data.csv
    new:
      - Content/Blueprint/Objects/Projectiles/CharacterSkill/BP_Painter_Skill04.uasset
      - Content/Assets/Mixed_Magic_VFX_Pack/VFX/NS_Shattering_Painter04.uasset
      - Content/Assets/Necropolis/Materials/MI_PinterMoon.uasset
      - Content/Assets/LootandPickupVFXPack/LootVFX/Glows/FlareTheme/NS_FlareGlow05.uasset
    deleted:
      - Content/Blueprint/Objects/Projectiles/BP_Painter_Skill04.uasset
  summary: "feat(element-color): 도화가 FX ElementColor + DT ElementTag + 스킬4 BP 이동 + Wave 데이터 갱신"



- date: 2026-04-21
  plan: PLAN_SkillSystemArch_v1.0 MODULE-1~6
  commits: ["0826c050a", "206cca116", "6ba8f1487", "eb9fb975a", "23a46d884"]
  status: COMMITTED
  files:
    modified:
      - Source/RoastStaffGAS/Public/Data/DataTableStructs.h
      - Source/RoastStaffGAS/Public/Data/RuntimeDataStructs.h
      - Source/RoastStaffGAS/Public/Subsystems/GameDataSubsystem.h
      - Source/RoastStaffGAS/Private/Subsystems/GameDataSubsystem.cpp
      - Source/RoastStaffGAS/Private/Subsystems/SkillManagerSubsystem.cpp
      - Source/RoastStaffGAS/Public/GAS/Abilities/GA_CharacterSkill.h
      - Source/RoastStaffGAS/Private/GAS/Abilities/GA_CharacterSkill.cpp
      - Source/RoastStaffGAS/Public/Objects/GroundEffect/GroundEffectActor.h
      - Source/RoastStaffGAS/Private/Objects/GroundEffect/GroundEffectActor.cpp
      - ExternalSource/DT_Character_Skill_Static_Data.csv
      - Content/Assets/Scene_Saloon/Assets/MS/3D/Res_Sto_Chest_Wood_Worn_08/SM_Res_Sto_Chest_Wood_Worn_08.uasset
      - Content/Map/Map_Lobby.umap
    new:
      - Source/RoastStaffGAS/Public/Interface/SkillEffectInterface.h
      - Source/RoastStaffGAS/Public/Objects/GroundEffect/PullVortexActor.h
      - Source/RoastStaffGAS/Private/Objects/GroundEffect/PullVortexActor.cpp
      - _Design/Plans/active/PLAN_SkillSystemArch_v1.0.md
    deleted:
      - Content/Assets/Scene_Saloon/Assets/Blueprints/BP_His_Sal_Configuration_Table_01.uasset
      - Content/Assets/Scene_Saloon/Assets/Blueprints/BP_His_Sal_Configuration_Table_02.uasset
      - Content/Assets/Scene_Saloon/Assets/MS/3D/His_Wil_Furniture_Table_Wood_Worn_01/* (×4)
  summary: "refactor(skill-arch): ISkillEffectInterface 도입 + GA SkillGEClass 데이터드리븐 전환 + APullVortexActor 구현"

- date: 2026-04-21
  plan: PLAN_CombatInfra_v1.0 MODULE-스킬점검
  commits: ["b17d85a38", "e958af9fc", "516e2b78e"]
  status: COMMITTED
  files:
    modified:
      - ExternalSource/DT_Character_Skill_Static_Data.csv
      - Content/Data/Skill/Character/DT_Character_Skill_Static_Data.uasset
      - Content/Data/Character/DT_Character_Static_Data.uasset
      - Content/Data/Character/CT_BaseStatCurve.uasset
      - Content/Map/Map_Lobby.umap
    new:
      - Content/GAS/GA/Character/Painter/GA_CharacterSkill_Painter05.uasset
  summary: "data(skill/character): Painter 03/05 GA 분리 + 캐릭터 데이터 + 로비 맵 갱신"

- date: 2026-04-21
  plan: PLAN_OutgameLobby3D_v1.0
  commits: ["c6fd4228c", "9c6e1a738", "810436c81", "a35bfc02b", "3a0265743"]
  status: COMMITTED
  files:
    new:
      - Source/RoastStaffGAS/Public/Character/Player/LobbyCharacterActor.h
      - Source/RoastStaffGAS/Private/Character/Player/LobbyCharacterActor.cpp
      - Source/RoastStaffGAS/Public/UI/OutGame/LobbyCharInfoPanel.h
      - Source/RoastStaffGAS/Private/UI/OutGame/LobbyCharInfoPanel.cpp
    modified:
      - Source/RoastStaffGAS/Public/Data/DataTableStructs.h
      - Source/RoastStaffGAS/Public/Data/EnumUITypes.h
      - Source/RoastStaffGAS/Public/Core/OutGame/RSOutGamePlayerController.h
      - Source/RoastStaffGAS/Private/Core/OutGame/RSOutGamePlayerController.cpp
      - Source/RoastStaffGAS/Public/UI/OutGame/RSLobbyWidget.h
      - Source/RoastStaffGAS/Private/UI/OutGame/RSLobbyWidget.cpp
      - Source/RoastStaffGAS/Public/UI/OutGame/RSStageSelectWidget.h
      - Source/RoastStaffGAS/Private/UI/OutGame/RSStageSelectWidget.cpp
  summary: "feat(outgame): 3D 로비 캐릭터 인터랙션 + 스테이지 선택 개편 + Scene_Saloon 에셋 임포트"
  design_notes:
    - "LobbyCharInfoPanel: UIManager 풀스크린 대신 BindWidget Show/Hide 패턴으로 변경"
    - "Hover 감지: bEnableMouseOverEvents 대신 PlayerTick GetHitResultUnderCursor 수동 트레이스"
    - "아웃라인: CustomDepth 깊이차 비교 → CustomStencil 이진 마스크로 변경"

- date: 2026-04-20
  plan: PLAN_CombatInfra_v1.0 MODULE-2 보강
  commits: ["385652b6e", "f6b45a9bf", "bf84ceca2"]
  status: COMMITTED
  files:
    modified:
      - Source/RoastStaffGAS/Public/Character/Enemy/EnemyBaseCharacter.h
      - Source/RoastStaffGAS/Private/Character/Enemy/EnemyBaseCharacter.cpp
    editor:
      - Content/Assets/.../M_Enemy 6종 (EmissiveIntensity Add 노드)
      - Config/DefaultEngine.ini (시작맵 Map_Lobby)
  summary: "fix(HitReact): 이미시브 Fade Out + 머티리얼 Add 노드 세팅"

- date: 2026-04-19
  plan: PLAN_CombatInfra_v1.0 MODULE-CC + 스킬점검 + 에디터
  commits: ["bba4030c9", "b60ae6522", "303a59e87"]
  status: COMMITTED
  summary: "feat(combat): CC 시스템 + 몽타주 캐스팅 구조 + 스킬1~3 점검 + 숫자키 바인딩"

- date: 2026-04-17
  plan: PLAN_CombatInfra_v1.0 MODULE-1
  commits: ["75ba1d80b", "6ecf988c7"]
  status: COMMITTED
  files:
    modified:
      - Config/DefaultGame.ini
      - Content/Blueprint/Enemy/Boss/BP_BossEnemy.uasset
      - Content/UI/Ingame/Enemy/WBP_BossHPBar.uasset
      - Source/RoastStaffGAS/Private/System/EnemySpawner.cpp
  summary: "fix(EnemySpawn): NavMesh 투영 + LineTrace 바닥 검증 + Z 범위 제한 + 보스 캡슐 충돌 Block 수정"

- date: 2026-04-15
  plan: PLAN_PassiveSlotUI_v1.0
  commits: ["0a9533b9b", "7c36f7fd3", "ab9d95674", "c2a58ec1a", "5b45d6edd", "ccb38598c"]
  status: COMMITTED

## COMMITTED

- date: 2026-04-15
  plan: PLAN_Phase1_InGame_v1.0
  commits: ["cc4ab96c4", "f0efdb971", "fd502de74", "9d449833e", "5cea35082"]
  status: COMMITTED
  summary: "refactor(GAS-Delegate) + fix(HP-Behavior) + feat(CharacterStat) + data(Passive) + chore(에디터): ASC delegate 일원화, HP 버그 수정, 스탯팝업 Base+Bonus 표시, 패시브 magnitude 원복"
  bugs_fixed:
    - GAS Multiplicative 공식 오진 — magnitude 0.2x(80%감소)→1.2x(20%증가) 원복
    - MaxHP StatUpgrade 적용 시 CurHP=MaxHP 회복 전용 처리
    - MaxHP 패시브 적용 시 CurHP 델타만큼 연동
    - 레벨업 카드 선택 후 스탯 창 미갱신 — ASC attribute delegate로 교체

- date: 2026-04-14
  plan: PLAN_CharacterStatPopup_v1.0
  commits: ["a6b407a34", "6a35704d7", "58de4f52b", "d2be49f02", "5d1ba8d47", "8b1e18e42"]
  status: COMMITTED
  summary: "fix(FloatingDamage) + data(Phase1-Editor) + feat(CharacterStat): 스탯 팝업 HUD 구현 + Phase1 에디터 완료"
  bugs_fixed:
    - FloatingDamageWidget PreWarm/스폰 클래스 이중 관리 제거

- date: 2026-04-14
  plan: PLAN_LevelUpCardPool_v1.0
  commits: ["54c0698f", "4865e460", "8dc709e02"]
  status: COMMITTED
  summary: "feat(LevelUp): 카드풀 확장 — StatUpgrade/PassiveAdd/WeaponUpgrade/WeaponNew 혼합 + 4장 선택"

---
<!-- 이전 항목들은 compact됨 (2026-04-14) -->

## FORMAT
```yaml
- date: YYYY-MM-DD
  plan: PLAN_[시스템명]_vX.X
  commit: null | "abc1234"
  files:
    modified: []
    created:  []
    deleted:  []
  summary: "한 줄 요약"
  status: PENDING_COMMIT | COMMITTED | REVERTED
  bugs_found: []
  bugs_fixed: []
```
