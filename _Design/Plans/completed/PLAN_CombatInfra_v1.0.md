# PLAN_CombatInfra_v1.0
```yaml
date:    2026-04-17
sprint:  SPRINT-PORTFOLIO
status:  ACTIVE
designs: [게임 시스템 개선안 v2.0.md]
```

## GOAL
> 스킬 전투 연출의 기반이 되는 피격 반응·투사체 스킬 타입·속성 FX·장판 Actor 4가지 공통 인프라를 구축한다.

## SCOPE
```yaml
new_files:
  - Source/RoastStaffGAS/Public/Objects/GroundEffect/GroundEffectActor.h
  - Source/RoastStaffGAS/Private/Objects/GroundEffect/GroundEffectActor.cpp

modified_files:
  - Source/RoastStaffGAS/Public/Subsystems/SkillManagerSubsystem.h
  - Source/RoastStaffGAS/Private/Subsystems/SkillManagerSubsystem.cpp
  - Source/RoastStaffGAS/Public/Character/Player/RSPlayerController.h
  - Source/RoastStaffGAS/Private/Character/Player/RSPlayerController.cpp
  - Source/RoastStaffGAS/Public/UI/InGame/SlotContainerWidget.h
  - Source/RoastStaffGAS/Private/UI/InGame/SlotContainerWidget.cpp
  - Source/RoastStaffGAS/Public/Objects/Projectile/BaseProjectile.h
  - Source/RoastStaffGAS/Private/Objects/Projectile/BaseProjectile.cpp
  - Source/RoastStaffGAS/Public/Data/EnumTypes.h
  - Source/RoastStaffGAS/Public/Data/DataTableStructs.h
  - Source/RoastStaffGAS/Public/Data/RuntimeDataStructs.h
  - Source/RoastStaffGAS/Private/Subsystems/GameDataSubsystem.cpp
  - Source/RoastStaffGAS/Public/GAS/Attributes/EnemyAttributeSet.h
  - Source/RoastStaffGAS/Private/GAS/Attributes/EnemyAttributeSet.cpp
  - Source/RoastStaffGAS/Public/Character/Enemy/EnemyBaseCharacter.h
  - Source/RoastStaffGAS/Private/Character/Enemy/EnemyBaseCharacter.cpp
  - Source/RoastStaffGAS/Public/GAS/Abilities/GA_CharacterSkill.h
  - Source/RoastStaffGAS/Private/GAS/Abilities/GA_CharacterSkill.cpp
  - Source/RoastStaffGAS/Public/GAS/Tags/RSGameplayTags.h
  - Source/RoastStaffGAS/Private/GAS/Tags/RSGameplayTags.cpp
  - Config/DefaultGame.ini
  - Source/RoastStaffGAS/Private/Objects/Projectile/EnemyProjectile.cpp
  - Source/RoastStaffGAS/Private/Character/Enemy/BossEnemy.cpp
  - Source/RoastStaffGAS/Private/Character/Enemy/EliteEnemy.cpp
  - Source/RoastStaffGAS/Private/Character/Enemy/EnemyAIController.cpp
  - Source/RoastStaffGAS/Private/Subsystems/PoolingSubsystem.cpp

new_datatables:
  - DT_CharacterSkill 컬럼 추가 (ElementTag / ProjectileClass / PierceCount / ProjectileCount / FireInterval / GroundEffectActorClass)

new_tags:
  - Element.Fire
  - Element.Ice
  - Element.Thunder
```

## INTEGRATION_POINTS
```yaml
owner:       "UEnemyAttributeSet / AEnemyBaseCharacter / UGA_CharacterSkill"
entry:       "UEnemyAttributeSet::PostGameplayEffectExecute() → AEnemyBaseCharacter::ApplyHitReact() /
              UGA_CharacterSkill::OnAbilityActivated() switch 확장"
depends_on:  "PoolingSubsystem, UPlayerAttributeSet(패턴 참조), ABaseProjectile"
ref_pattern: "UPlayerAttributeSet::PostGameplayEffectExecute — Super 후 반응 처리 패턴 /
              기존 SpawnSkillFX SetVariableFloat 패턴"
arch_impact: >
  CLASS_REGISTRY 추가:
    UEnemyAttributeSet — PostGameplayEffectExecute 오버라이드, Actor 반응 위임 게이트
    AARS_GroundEffectActor — 장판 Actor 공용 클래스, PoolableInterface 구현
  INTEGRATION_MAP 추가:
    UEnemyAttributeSet::PostGameplayEffectExecute → AEnemyBaseCharacter::ApplyHitReact
    UGA_CharacterSkill::ExecuteProjectileSpawn → PoolingSubsystem::SpawnFromPool<ABaseProjectile>
    UGA_CharacterSkill::ExecuteGroundEffect → PoolingSubsystem::SpawnFromPool<AARS_GroundEffectActor>
```

## FLOW

### MODULE-2 피격 반응
```
[GE Apply to Enemy]
    │
    ▼
UEnemyAttributeSet::PostGameplayEffectExecute()
    ├─ Super::PostGameplayEffectExecute() 호출
    ├─ HP 감소 감지 (NewHP < OldHP && NewHP > 0)
    ├─ GetOwningAbilitySystemComponent()->GetOwner() → Cast<AEnemyBaseCharacter>
    │    └─ 실패 → KHS_WARN + return
    └─ InstigatorLocation 계산 (EffectContext.GetInstigator())
         └─ ApplyHitReact(ImpactDir = (OwnerLoc - InstigatorLoc).GetSafeNormal())

AEnemyBaseCharacter::ApplyHitReact(FVector ImpactDir)
    ├─ LaunchCharacter(ImpactDir * KnockbackForce, true, true)
    ├─ CustomTimeDilation = 0.0f
    │    └─ HitstopTimerHandle → HitstopDuration 후 CustomTimeDilation = 1.0f 복원
    └─ MaterialEmissiveFlash()
         ├─ GetMesh()->GetMaterials() 순회 → CreateAndSetMaterialInstanceDynamic
         ├─ CachedMIDs에 저장 (UPROPERTY)
         ├─ SetScalarParameterValue("EmissiveIntensity", FlashIntensity)
         └─ FlashTimerHandle → FlashDuration 후 0.f 복원
```

### MODULE-3 ProjectileSpawn
```
[DT_CharacterSkill.ProjectileClass, PierceCount, ProjectileCount, FireInterval]
    │
    ▼
GDS::GetCharacterSkillExecData() → FCharacterSkillExecData (신규 필드 포함)
    │
    ▼
GA_CharacterSkill::OnAbilityActivated()
    └─ case ProjectileSpawn → ExecuteProjectileSpawn()
         ├─ ExecData.ProjectileClass.LoadSynchronous()
         │    └─ 실패 → KHS_WARN + EndAbility(cancelled)
         ├─ FProjectileInitData 조립
         │    (Instigator, GEClass, Damage, PierceCount 등)
         ├─ ProjectileCount == 1 → SpawnFromPool 즉시
         └─ ProjectileCount > 1 → SetTimer(FireInterval) × ProjectileCount
              └─ 마지막 발사 후 EndAbility
```

### MODULE-4 ElementTag FX
```
ExecData.ElementTag (FGameplayTag)
    │
    ▼
GA_CharacterSkill::SpawnSkillFX(FXClass, Location, Radius, ElementTag)
    ├─ SpawnSystemAtLocation(FX, Location)
    ├─ SetVariableFloat("Radius", Radius)
    └─ ElementTag 분기:
         Fire    → SetVariableLinearColor("ElementColor", {1,0.3,0,1})
         Ice     → SetVariableLinearColor("ElementColor", {0.3,0.8,1,1})
         Thunder → SetVariableLinearColor("ElementColor", {1,1,0,1})
         None    → SetVariableLinearColor("ElementColor", White)
```

### MODULE-5 GroundEffect
```
[DT_CharacterSkill.GroundEffectActorClass + Duration + OverlapGEClass]
    │
    ▼
GA_CharacterSkill::ExecuteGroundEffect()
    ├─ ExecData.GroundEffectActorClass.LoadSynchronous()
    ├─ PoolingSubsystem::SpawnFromPool<AARS_GroundEffectActor>(Class, Location)
    ├─ InitGroundEffect(OwnerASC, Duration, OverlapGEClass, Radius, FXClass)
    └─ EndAbility 즉시 (장판 Actor가 독립 수명 관리)

AARS_GroundEffectActor 수명:
    OnPoolActivate()
        ├─ OverlapSphere 활성화
        ├─ Niagara FX 스폰 Attach
        └─ DurationTimerHandle → Duration 후 OnPoolDeactivate + ReturnToPool

    OnComponentBeginOverlap(적 진입)
        └─ InstigatorASC->ApplyGameplayEffectToActor(OverlapGEClass, TargetASC)

    OnComponentEndOverlap(적 이탈)
        └─ [bRemoveOnEndOverlap] RemoveActiveGameplayEffect(Handle)
```

## SCHEMA

### DT_CharacterSkill 추가 컬럼
| 컬럼 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| ElementTag | FGameplayTag | EmptyTag | 속성 태그 (없으면 FX 색상 White) |
| ProjectileClass | TSoftClassPtr\<ABaseProjectile\> | None | ProjectileSpawn 타입 전용 |
| PierceCount | int32 | 0 | 관통 횟수 (0 = 비관통) |
| ProjectileCount | int32 | 1 | 연속 발사 수 |
| FireInterval | float | 0.0 | 연속 발사 간격 (초) |
| GroundEffectActorClass | TSoftClassPtr\<AARS_GroundEffectActor\> | None | GroundEffect 타입 전용 |

## EDGE_CASES
| 상황 | 처리 | 근거 |
|------|------|------|
| HP 0 도달 시 ApplyHitReact 호출 | HP == 0 판정에서 ApplyHitReact 생략, OnDeathDel만 발행 | 사망 애니와 충돌 방지 |
| ProjectileClass 로드 실패 | KHS_WARN + EndAbility(bWasCancelled=true) | GAS 규칙: EndAbility 누락 금지 |
| GroundEffectActorClass None | KHS_WARN + EndAbility(bWasCancelled=true) | 동일 |
| ProjectileCount 타이머 중 GA 종료 | 타이머 클리어 후 스폰 중단 | 쿨타임은 첫 발사 시 시작 |
| CustomTimeDilation 복원 전 에너미 사망 | OnPoolDeactivate에서 CustomTimeDilation=1.f 강제 복원 | 풀 재사용 에너미 속도 비정상 방지 |
| Flash 중 에너미 사망 | OnPoolDeactivate에서 CachedMIDs 전체 0.f 복원 | 동일 |

## REVIEW_NOTES
```
기획서 일관성: ✓ 기획서 v2.0 섹션 3,4,5 반영
누락 예외처리: HP==0 시 ApplyHitReact 생략 (에지 케이스에 추가)
기획서 정정:   피격반응 "EnemyBaseCharacter::PostGameplayEffectExecute" → "UEnemyAttributeSet::PostGameplayEffectExecute→ApplyHitReact 위임" (C++ GAS 구조상)
Gemini 반영:   미진행
```

---
## MODULE 진행 현황
```
[x] MODULE-1: EnemySpawnFix 커밋
[x] MODULE-2: 피격 반응 공통 구조
[x] MODULE-3: ProjectileSpawn 타입 추가          (57b0a00a2)
[x] MODULE-4: ElementTag + SpawnSkillFX 색상 분기 (57b0a00a2)
[x] MODULE-5: ARS_GroundEffectActor 공통 클래스   (57b0a00a2)
[ ] MODULE-에디터: 에디터 작업 (진행 중)
[x] MODULE-6: SkillSlot 2→6 확장 + 숫자키 1~6 바인딩
[x] MODULE-7: 환영의 문 텔레포트 + 콩콩이 HOMING_BOUNCE
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
