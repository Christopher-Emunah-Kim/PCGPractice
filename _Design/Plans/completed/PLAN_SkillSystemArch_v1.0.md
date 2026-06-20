# PLAN_SkillSystemArch_v1.0
```yaml
date:    2026-04-21
sprint:  SPRINT-5
status:  ACTIVE
designs: [스킬 시스템 기획 v1.4.md]
```

## GOAL
> GA / SkillEffectActor / GE 3레이어 분리 — SkillGEClass를 DataTable로 이동하고 SkillEffectActor에 공통 Init 인터페이스를 적용해 새 스킬 추가 시 C++ 클래스 신설 없이 BP만으로 처리 가능하도록 아키텍처 개선

## SCOPE
```yaml
new_files:
  - Source/RoastStaffGAS/Public/Interface/SkillEffectInterface.h
  - Source/RoastStaffGAS/Public/Objects/GroundEffect/PullVortexActor.h
  - Source/RoastStaffGAS/Private/Objects/GroundEffect/PullVortexActor.cpp

modified_files:
  - Source/RoastStaffGAS/Public/Data/DataTableStructs.h
  - Source/RoastStaffGAS/Public/Data/RuntimeDataStructs.h
  - Source/RoastStaffGAS/Public/Subsystems/GameDataSubsystem.h
  - Source/RoastStaffGAS/Private/Subsystems/GameDataSubsystem.cpp
  - Source/RoastStaffGAS/Private/Subsystems/SkillManagerSubsystem.cpp
  - Source/RoastStaffGAS/Public/GAS/Abilities/GA_CharacterSkill.h
  - Source/RoastStaffGAS/Private/GAS/Abilities/GA_CharacterSkill.cpp
  - Source/RoastStaffGAS/Public/Objects/GroundEffect/GroundEffectActor.h
  - Source/RoastStaffGAS/Private/Objects/GroundEffect/GroundEffectActor.cpp

new_datatables: []
new_tags: []
```

## INTEGRATION_POINTS
```yaml
owner:       UGA_CharacterSkill
entry:       ExecuteGroundEffect() / ExecuteInstantAoE() / ExecuteSpawnPreview()
depends_on:  UGameDataSubsystem, UPoolingSubsystem, IPoolableInterface
ref_pattern: FProjectileInitData 조립 패턴 준용 → FSkillEffectInitData 번들로 대체
arch_impact: |
  CLASS_REGISTRY 추가:
    - ISkillEffectInterface: SkillEffect Actor 공통 Init 계약 (InitEffect 단일 메서드)
    - APullVortexActor: 흡입+다단데미지+넉다운 장판 Actor, ISkillEffectInterface + IPoolableInterface 구현
  INTEGRATION_MAP 추가:
    - GA_CharacterSkill::ExecuteGroundEffect → ISkillEffectInterface::InitEffect(FSkillEffectInitData)
    - GDS::GetCharacterSkillExecData → DT_CharacterSkill.SkillGEClass 로드
  DESIGN_DECISIONS 추가:
    - SkillGEClass → DT_CharacterSkill 컬럼 이전. GA BP EditDefaultsOnly 제거.
    - FCharacterSkillLevelData 삭제 + 필드 평탄화 (스킬레벨 시스템 미구현)
```

## MODULES

### MODULE-1 — DataTable 스키마 + 구조체 정리 [P0] ← 현재
```
변경:
  FCharacterSkillLevelData 삭제
  FCharacterSkillStaticData: LevelData 배열 → 평탄화 (DamageMultiplier/EffectRadius/Duration/SkillFX)
                              SkillGEClass + StatusGEClass 추가
                              GroundEffectActorClass → EffectActorClass (타입 유지, MODULE-3에서 확장)
  FCharacterSkillExecData:   동일 평탄화 + GE 필드 추가
  GDS.GetCharacterSkillExecData: SkillLevel 파라미터 제거
  SkillManagerSubsystem: 호출부 파라미터 제거
  GA_CharacterSkill.cpp: ExecData.LevelData.* → flat 필드
```

### MODULE-2 — ISkillEffectInterface 신설 [P0]
```
신규: Source/RoastStaffGAS/Public/Interface/SkillEffectInterface.h
  InitEffect(const FSkillEffectInitData&) = 0 순수 가상 메서드
```

### MODULE-3 — GroundEffectActor 인터페이스 적용 [P0]
```
수정: GroundEffectActor.h/.cpp
  ISkillEffectInterface 상속
  InitEffect() 구현 (기존 InitGroundEffect() 로직 이전)
  InitGroundEffect() 제거
  EffectActorClass 타입 → TSoftClassPtr<AActor> 확장
```

### MODULE-4 — GA_CharacterSkill SkillGEClass 탈착 [P1]
```
수정: GA_CharacterSkill.h/.cpp
  SkillGEClass UPROPERTY(EditDefaultsOnly) 제거
  ExecData.SkillGEClass 경유로 변경
  Cast<ISkillEffectInterface> + InitEffect 호출
```

### MODULE-5 — GDS SkillGEClass/StatusGEClass 채우기 [P1]
```
수정: GameDataSubsystem.cpp
  GetCharacterSkillExecData: SkillGEClass + StatusGEClass 전달
```

### MODULE-6 — APullVortexActor 구현 [P1]
```
신규: PullVortexActor.h/.cpp
  IPoolableInterface + ISkillEffectInterface 구현
  PullTick + HitTick + KnockdownGE (마지막 히트)
  EditDefaultsOnly: PullRadius/PullStrength/PullTickRate/HitCount/HitInterval
```

### MODULE-7 — 도화가 스킬 2·4·6 DT 행 등록 [DEFERRED]
```
deferred: 스킬 수치 미확정 + 에디터 작업
```

## FLOW
```
[DT_CharacterSkill] SkillGEClass/StatusGEClass/DamageMultiplier/EffectRadius/Duration/SkillFX/EffectActorClass
    │
    ▼
[GDS::GetCharacterSkillExecData(CharacterID, Slot)]
    │  → FCharacterSkillExecData (평탄화 필드 포함)
    ▼
[GA_CharacterSkill::ActivateAbility]
    │  ExecData.SkillGEClass.LoadSynchronous()
    ├─ InstantAoE   → GE 직접 적용
    ├─ SelfBuff     → GE 직접 적용
    ├─ SpawnPreview → 확정 시 EffectActorClass 스폰 + InitEffect()
    ├─ Projectile   → FProjectileInitData 조립 (기존 유지)
    └─ GroundEffect → EffectActorClass 스폰 + Cast<ISkillEffectInterface> + InitEffect()

[ISkillEffectInterface::InitEffect(FSkillEffectInitData)]
    ├─ AGroundEffectActor (기존 동작 유지)
    └─ APullVortexActor   (PullTick + HitTick + KnockdownGE)
```

## SCHEMA
```
DT_CharacterSkill 변경 컬럼:
| 컬럼              | 타입                            | 기본값 | 설명                        |
|-------------------|---------------------------------|--------|-----------------------------|
| SkillGEClass      | TSoftClassPtr<UGameplayEffect>  | null   | 메인 GE (신규)              |
| StatusGEClass     | TSoftClassPtr<UGameplayEffect>  | null   | 상태이상 GE (신규)          |
| DamageMultiplier  | float                           | 1.0    | 데미지 배율 (평탄화)        |
| EffectRadius      | float                           | 0.0    | 효과 반경 (평탄화)          |
| Duration          | float                           | 0.0    | 지속 시간 (평탄화)          |
| SkillFX           | TSoftObjectPtr<UNiagaraSystem>  | null   | 발동 FX (평탄화)            |
| EffectActorClass  | TSoftClassPtr<AGroundEffectActor>| null  | 효과 액터 (GroundEffectActorClass 대체) |
삭제: LevelData (TArray<FCharacterSkillLevelData>)
```

## EDGE_CASES
```
| 상황                              | 처리                                              | 기획서 근거 |
|-----------------------------------|---------------------------------------------------|------------|
| SkillGEClass null (텔레포트 스킬) | GA: GE 적용 생략, FX/이동만 수행                  | SD2        |
| Cast<ISkillEffectInterface> 실패  | KHS_WARN + ReturnToPool + return                  | 방어적 코딩 |
| EffectActorClass null             | GE/FX 분기 건너뜀                                 | 기존 동작  |
| PullVortex KnockdownGEClass null  | 마지막 히트에서 KnockdownGE 생략 (경고 없음)       | 선택적 사용 |
```

## REVIEW_NOTES
```
기획서 일관성: ✓ (FCharacterSkillLevelData 삭제 — 스킬레벨 미구현 확인)
누락 예외처리: 없음
기획서 정정:   없음
Gemini 반영:   해당없음
```

## DEFERRED_TODO
```
[~] PullVortex 파라미터 DT 컬럼화 검토
    (PullRadius/PullStrength/PullTickRate/HitCount/HitInterval → DT_CharacterSkill 또는 별도 테이블)
    현재: APullVortexActor.EditDefaultsOnly | [P3] | REF: SkillSystemArch
```

---
## REVIEW_STATUS
```
| 단계          | 상태 | 날짜       | 주요 지적 |
|---------------|------|------------|-----------|
| Cross-Review  | -    | -          | -         |
| Senior-Review | -    | -          | -         |
| Learn-Report  | -    | -          | -         |

verdict:    PENDING
unresolved: []
```
