# PLAN_SkillActivationRefactor_v1.0
```yaml
date:    2026-04-26
sprint:  SPRINT-9
status:  ACTIVE
designs: [스킬 시스템 기획 v1.4.md, Temp_변경스킬계획.md]
```

## GOAL
> ESkillActivationType 단일 Enum(조준+효과 혼합)을 3축(TargetingType × EffectType × ProjectileMoveType)으로 분리하고, 캐릭터 스킬 데이터를 DT_CharacterSkill 단일 완결 구조로 통폐합해 GA Execute 분기 지옥을 해소한다.

## SCOPE
```yaml
new_files: []
modified_files:
  - Source/RoastStaffGAS/Public/Data/EnumTypes.h
  - Source/RoastStaffGAS/Public/GAS/Tags/RSGameplayTags.h
  - Source/RoastStaffGAS/Public/Data/DataTableStructs.h
  - Source/RoastStaffGAS/Public/Data/RuntimeDataStructs.h
  - Source/RoastStaffGAS/Public/Subsystems/GameDataSubsystem.h
  - Source/RoastStaffGAS/Private/Subsystems/GameDataSubsystem.cpp
  - Source/RoastStaffGAS/Private/Subsystems/SkillManagerSubsystem.cpp
  - Source/RoastStaffGAS/Public/GAS/Abilities/GA_CharacterSkill.h
  - Source/RoastStaffGAS/Private/GAS/Abilities/GA_CharacterSkill.cpp
  - ExternalSource/DT_Character_Skill_Static_Data.csv
new_datatables: []
new_tags:
  - Skill.State.Charging
```

## INTEGRATION_POINTS
```yaml
owner:       UGA_CharacterSkill
entry:       UGA_CharacterSkill::OnAbilityActivated → ResolveTargeting(TargetingType)
depends_on:  UGameDataSubsystem, UPoolingSubsystem, ISkillEffectInterface, IPoolableInterface
ref_pattern: |
  기존 StartSkillWithMontage / ExecuteSpawnPreview::PendingTargetLocation 패턴 승계
  투사체 GE 처리는 투사체 Actor 내부 위임 유지 (GA EndAbility 타이밍 독립)
arch_impact: |
  CLASS_REGISTRY:
    - ESkillActivationType: DEPRECATED 표기 (무기 스킬 격리 완료 후 삭제)
    - ESkillTargetingType / ESkillEffectType / EProjectileMoveType / ESkillSpawnPattern: 신규 등록
    - FCharacterSkillStaticData: ActivationType → TargetingType+EffectType+ProjectileMoveType+SpawnPattern+SpawnCount 교체
    - UGA_CharacterSkill: Execute 5개 → ResolveTargeting/ResolveEffect 2단계 재편
  DESIGN_DECISIONS:
    - SD4 무효화: DT_CharacterSkill CSV 임포트 가능 구조로 전환됨
    - SD5 추가: ESkillActivationType 2축 분리 결정
    - SD6 추가: DT_CharacterSkill 단일 완결 구조 확정 (무기 스킬 분산 테이블 격리 유지)
  INTEGRATION_MAP:
    - GDS.GetCharacterSkillExecData 반환 번들 필드 변경 (ActivationType → 3축 필드)
```

## FLOW
```
[OnAbilityActivated]
    │
    ▼
ResolveTargeting(TargetingType)
    ├─ Instant        → ResolveEffect() 즉시 호출
    ├─ AimPreview     → 프리뷰 Actor 스폰 (EffectActorClass or PreviewActorClass)
    │                    → LMB 확정 이벤트 수신
    │                    → ResolveEffect() 호출
    ├─ LaunchProjectile → SpawnPattern/SpawnCount 기반 투사체 스폰
    │                    → 투사체 내부에서 GE 처리 (GA EndAbility와 독립)
    └─ ChargeAndRelease → [DEFERRED]

ResolveEffect(EffectType, TargetLocation)
    ├─ RadialAoE   → SphereOverlap(EffectRadius) + GE Apply (SkillGEClass)
    ├─ SelfBuff    → GE Apply Self (SkillGEClass)
    ├─ Teleport    → SetActorLocation(TargetLocation) + SpawnSkillFX
    ├─ SpawnActor  → Pool에서 Actor 꺼내 Cast<ISkillEffectInterface> + InitEffect(FSkillEffectInitData)
    └─ Projectile  → 투사체 내부 처리 (ProjectileMoveType 분기는 투사체 Actor 책임)

[예외]
    ├─ TargetingType 미지원 → KHS_WARN + EndAbility
    ├─ EffectType 미지원   → KHS_WARN + EndAbility
    ├─ EffectActorClass null (SpawnActor) → KHS_WARN + EndAbility
    └─ Cast<ISkillEffectInterface> 실패  → KHS_WARN + ReturnToPool + EndAbility
```

## SCHEMA
```
DataTable: DT_CharacterSkill (FCharacterSkillStaticData)

── 스탯 (항상 메모리 상주) ──────────────────────────────────────────
| 컬럼               | 타입                    | 기본값              | 설명                              |
|--------------------|-------------------------|---------------------|-----------------------------------|
| SkillID            | FName                   | NAME_None           | PK                                |
| CharacterID        | FName                   | NAME_None           | FK → DT_Character                 |
| SlotIndex          | int32                   | 0                   | 캐릭터 스킬 슬롯 번호 (1~6)       |
| TargetingType      | ESkillTargetingType     | Instant             | 조준방식                          |
| EffectType         | ESkillEffectType        | RadialAoE           | 결과 타입                         |
| ProjectileMoveType | EProjectileMoveType     | Linear              | EffectType==Projectile 시만 유효  |
| SpawnPattern       | ESkillSpawnPattern      | Single              | 투사체 발사 패턴                  |
| SpawnCount         | int32                   | 1                   | Burst/Spread/Circle 시 발사 수    |
| Cooldown           | float                   | 1.0                 | 쿨타임 (초)                       |
| DamageMultiplier   | float                   | 1.0                 | 데미지 배율                       |
| EffectRadius       | float                   | 0.0                 | AoE/SpawnActor 효과 반경          |
| Duration           | float                   | 0.0                 | 지속 시간 (초)                    |
| ProjectileSpeed    | float                   | 1200.0              | 투사체 속도                       |
| ProjectileRange    | float                   | 1500.0              | 투사체 최대 사거리                |
| FireInterval       | float                   | 0.1                 | Burst 발사 간격 (초)              |
| ElementTag         | FGameplayTag            | (Empty)             | 속성 태그                         |

── 리소스 SoftPtr (발동 시 LoadSynchronous) ───────────────────────
| GAClass            | TSoftClassPtr<UGameplayAbility>  | null | GA 클래스                    |
| SkillGEClass       | TSoftClassPtr<UGameplayEffect>   | null | 메인 GE                      |
| StatusGEClass      | TSoftClassPtr<UGameplayEffect>   | null | 상태이상 GE (선택)           |
| EffectActorClass   | TSoftClassPtr<AActor>            | null | SpawnActor/AimPreview 액터   |
| ProjectileClass    | TSoftClassPtr<AActor>            | null | 투사체 BP 클래스             |
| SkillFX            | TSoftObjectPtr<UNiagaraSystem>   | null | 발동 FX                      |
| SkillIcon          | TSoftObjectPtr<UTexture2D>       | null | UI 아이콘                    |

삭제 컬럼: ActivationType / SkillEffectID(FK) / LevelData(TArray)
```

## NEW_ENUMS
```cpp
// ESkillTargetingType — 조준방식
enum class ESkillTargetingType : uint8
{
    Instant,           // 즉시 발동 (위치 지정 없음)
    AimPreview,        // 프리뷰 위치 지정 후 확정
    LaunchProjectile,  // 투사체 발사
    ChargeAndRelease,  // 차징 후 발사 [Stub — Execute 구현 DEFERRED]
};

// ESkillEffectType — 결과
enum class ESkillEffectType : uint8
{
    RadialAoE,   // 범위 GE
    SelfBuff,    // 자신 GE
    Teleport,    // 확정 위치로 이동
    SpawnActor,  // EffectActorClass 스폰 + InitEffect (장판/지뢰 등)
    Projectile,  // 투사체 계열 (ProjectileMoveType으로 세분화)
};

// EProjectileMoveType — 투사체 이동+착탄 방식
enum class EProjectileMoveType : uint8
{
    Linear,       // 직선
    Pierce,       // 직선 관통
    Homing,       // 유도
    HomingBounce, // 유도 + 바운스 (콩콩이)
    Explode,      // 착탄 폭발 AoE
};

// ESkillSpawnPattern — 투사체 발사 패턴
enum class ESkillSpawnPattern : uint8
{
    Single,  // 단발
    Burst,   // 순차 연속 (FireInterval 간격)
    Spread,  // 동시 부채꼴
    Circle,  // 동시 원형
};
```

## SKILL_MAPPING
```
도화가 (Painter):
  흩뿌리기  (Skill01): Instant        + RadialAoE   + -           + Single
  해그리기  (Skill02): Instant        + SelfBuff    + -           + Single
  환영의문  (Skill03): AimPreview     + Teleport    + -           + Single
  범가르기  (Skill04): LaunchProjectile + Projectile + Pierce      + Single
  먹물세례  (Skill05): AimPreview     + SpawnActor  + -           + Single
  콩콩이    (Skill06): LaunchProjectile + Projectile + HomingBounce + Single

호크아이 (Hawkeye):
  래피드샷    (Skill01): LaunchProjectile + Projectile + Pierce  + Burst(5발)
  아토믹애로우(Skill02): LaunchProjectile + Projectile + Explode + Single
  호크샷      (Skill03): LaunchProjectile + Projectile + Homing  + Single
  애로우해일  (Skill04): AimPreview      + SpawnActor + -        + Single
  크레모아    (Skill05): AimPreview      + SpawnActor + -        + Single
  스나이프    (Skill06): ChargeAndRelease + Projectile + Pierce  + Single [DEFERRED]
```

## MODULES

### MODULE-1 — EnumRefactor [P0]
수정: EnumTypes.h / RSGameplayTags.h / DefaultGameplayTags.ini
  - [ ] ESkillTargetingType 추가 (Instant/AimPreview/LaunchProjectile/ChargeAndRelease)
  - [ ] ESkillEffectType 추가 (RadialAoE/SelfBuff/Teleport/SpawnActor/Projectile)
  - [ ] EProjectileMoveType 추가 (Linear/Pierce/Homing/HomingBounce/Explode)
  - [ ] ESkillSpawnPattern 추가 (Single/Burst/Spread/Circle)
  - [ ] ESkillActivationType에 DEPRECATED 주석 추가
  - [ ] Skill.State.Charging GameplayTag 등록

### MODULE-2 — StructMigration [P0]
> ⚠️ MODULE-3(GDSMigration)과 연속 작업 필수 — 이 모듈 완료 시 빌드 에러 상태
수정: DataTableStructs.h / RuntimeDataStructs.h
  - [ ] FCharacterSkillStaticData: ActivationType 제거 → TargetingType+EffectType+ProjectileMoveType+SpawnPattern+SpawnCount 추가
  - [ ] FCharacterSkillStaticData: ProjectileSpeed/ProjectileRange/FireInterval 필드 추가
  - [ ] FCharacterSkillStaticData: bTeleportOnConfirm 멤버 삭제 (EffectType::Teleport로 대체)
  - [ ] FCharacterSkillStaticData: SkillEffectID(FK) 필드 삭제
  - [ ] 모든 신규 필드 기본값 설정 (USTRUCT 규칙)
  - [ ] FCharacterSkillExecData: 동일 필드 교체 (ActivationType → 3축 + SpawnPattern + SpawnCount)
  - [ ] FSkillEffectInitData: 필요 필드 갱신 확인

### MODULE-3 — GDSMigration [P0]
> ⚠️ MODULE-2 완료 직후 연속 처리 (빌드 복구)
수정: GameDataSubsystem.h / GameDataSubsystem.cpp / SkillManagerSubsystem.cpp
  - [ ] GetCharacterSkillExecData: 3축 + SpawnPattern + SpawnCount 필드 매핑
  - [ ] 캐릭터 스킬 경로에서 SkillEffectID 복합 조회 코드 제거
  - [ ] DT_Skill_Attack_Common_Param_Data 등 분산 테이블 캐릭터 스킬 조회 경로 제거
  - [ ] SkillManagerSubsystem: GetSlotExecData 반환 번들 갱신

### MODULE-4 — GARefactor [P1]
수정: GA_CharacterSkill.h / GA_CharacterSkill.cpp
  - [ ] OnAbilityActivated: switch(ActivationType) → ResolveTargeting(TargetingType) 교체
  - [ ] ResolveTargeting_Instant() 구현
  - [ ] ResolveTargeting_AimPreview() 구현 (기존 ExecuteSpawnPreview 로직 + PendingTargetLocation 승계)
  - [ ] ResolveTargeting_LaunchProjectile() 구현 (SpawnPattern/SpawnCount 분기)
  - [ ] ResolveEffect(EffectType) 통합 진입점 구현
  - [ ] ExecuteEffect_RadialAoE() (기존 ExecuteInstantAoE 이관)
  - [ ] ExecuteEffect_SelfBuff() (기존 ExecuteSelfBuff 이관)
  - [ ] ExecuteEffect_Teleport() (bTeleportOnConfirm 로직 독립 분리)
  - [ ] ExecuteEffect_SpawnActor() (기존 ExecuteGroundEffect 이관)
  - [ ] ExecuteEffect_Projectile() (기존 ExecuteProjectileSpawn 이관 + ProjectileMoveType 분기)
  - [ ] 기존 Execute* 함수 5개 제거
  - [ ] bTeleportOnConfirm UPROPERTY 제거

### MODULE-5 — CSVMigration [P1]
수정: ExternalSource/DT_Character_Skill_Static_Data.csv
  - [ ] 신규 스키마 컬럼 헤더 작성 (SKILL_MAPPING 기준)
  - [ ] 도화가 6개 스킬 데이터 이전 (구 ActivationType → 3축 매핑)
  - [ ] 호크아이 6개 스킬 데이터 이전 (스나이프는 ChargeAndRelease Stub)
  - [ ] CSV UTF-8-BOM 인코딩 확인
  - [ ] 에디터에서 DT_CharacterSkill 리임포트 + 검증

### MODULE-6 — LegacyIsolation [P2]
수정: GameDataSubsystem.cpp (MODULE-3 검증)
  - [ ] 캐릭터 스킬 조회 경로에서 DT_Skill_* 참조 완전 제거 확인
  - [ ] 무기 스킬 조회 경로(DT_Skill_*)는 그대로 유지 확인
  - [ ] ARCH_SNAPSHOT SD4 무효화 + SD5/SD6 추가 갱신

### [DEFERRED] MODULE-7 — ChargeAndRelease Execute
  - [~] ResolveTargeting_ChargeAndRelease() 구현 (WaitInputPress + ChargeTimer + DamageMultiplier Lerp)
  - [~] 스나이프 DT 데이터 완성
  - [~] 차징 HUD 오버레이 + FOV 변화 연출
  > 트리거: 호크아이 스킬 구현 스프린트 착수 시

## EDGE_CASES
```
| 상황                                     | 처리                                        |
|------------------------------------------|---------------------------------------------|
| TargetingType 미지원 값                  | KHS_WARN + EndAbility(취소)                 |
| EffectType 미지원 값                     | KHS_WARN + EndAbility(취소)                 |
| EffectActorClass null (SpawnActor)       | KHS_WARN + EndAbility                       |
| Cast<ISkillEffectInterface> 실패         | KHS_WARN + ReturnToPool + EndAbility        |
| AimPreview 도중 GA 취소                  | OnCancelled → 프리뷰 Actor 풀 반환          |
| LaunchProjectile + Burst 도중 GA 취소   | OnCancelled → 타이머 클리어 + EndAbility    |
| ProjectileMoveType이 EffectType!=Projectile에서 참조 | 필드는 존재하나 GA에서 참조 안 함 (무해)  |
| 유효하지 않은 조합 (AimPreview+SelfBuff) | 런타임 KHS_WARN (설계상 DT 입력 오류)       |
```

## REVIEW_NOTES
```
기획서 일관성: ✓ (스킬 시스템 기획 v1.4 + Temp_변경스킬계획.md와 정합)
누락 예외처리: 없음
기획서 정정:   없음
Gemini 반영:
  ① TargetingType::Projectile → LaunchProjectile 이름 변경 — 반영 (EffectType::Projectile과 충돌 방지)
  ② MODULE-2→3 컴파일 오류 구간 명시 — 반영 (MODULE-2 주석에 경고 추가)
  ③ bTeleportOnConfirm / FXActorClass 처리 — 반영 (bTeleportOnConfirm 삭제, FXActorClass는 EffectActorClass로 통합)
  ④ SpawnCount vs SpawnPattern 분리 — 반영 (ESkillSpawnPattern + SpawnCount 두 필드로 분리)
```

---
## REVIEW_STATUS
```
| 단계          | 상태        | 날짜       | 주요 지적         |
|---------------|-------------|------------|-------------------|
| Cross-Review  | DONE        | 2026-04-26 | 4개 지적 전원 반영 |
| Senior-Review | -           | -          | -                 |
| Learn-Report  | -           | -          | -                 |

verdict:    PENDING
unresolved: []
```
