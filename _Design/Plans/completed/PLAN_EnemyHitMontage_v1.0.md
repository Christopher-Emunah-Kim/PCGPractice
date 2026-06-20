# PLAN_EnemyHitMontage_v1.0
```yaml
date:    2026-05-05
status:  ACTIVE
designs: [AI_에너미 시스템 기획 v1.1.md]
```

## GOAL
> FEnemyStaticData에 HitMontage 필드를 추가해 data-driven으로 로드하고, ApplyHitReact에서 재생. 히트스탑은 주석처리(테스트 후 제거 결정).

## SCOPE
```yaml
new_files:      []
modified_files:
  - Source/RoastStaffGAS/Public/Data/DataTableStructs.h
  - Source/RoastStaffGAS/Public/Character/Enemy/EnemyBaseCharacter.h
  - Source/RoastStaffGAS/Private/Character/Enemy/EnemyBaseCharacter.cpp
  - Source/RoastStaffGAS/Public/Objects/AutomatonActor.h
  - Source/RoastStaffGAS/Private/Core/RSGameMode.cpp
  - Source/RoastStaffGAS/Private/GAS/Abilities/GA_Base.cpp
  - Source/RoastStaffGAS/Private/GAS/Abilities/GA_CharacterSkill.cpp
  - Source/RoastStaffGAS/Private/Subsystems/SkillManagerSubsystem.cpp
  - Source/RoastStaffGAS/Public/Character/Enemy/EnemyAIController.h
  - Source/RoastStaffGAS/Public/Character/Enemy/MeleeEnemy.h
  - Source/RoastStaffGAS/Private/Character/Enemy/MeleeEnemy.cpp
  - Source/RoastStaffGAS/Public/Character/Enemy/RangedEnemy.h
  - Source/RoastStaffGAS/Private/Character/Enemy/RangedEnemy.cpp
  - Source/RoastStaffGAS/Public/Character/Enemy/EliteEnemy.h
  - Source/RoastStaffGAS/Private/Character/Enemy/EliteEnemy.cpp
  - Source/RoastStaffGAS/Public/Character/Enemy/BossEnemy.h
  - Source/RoastStaffGAS/Private/Character/Enemy/BossEnemy.cpp
new_datatables: []
new_tags:       []
editor_work:
  - DT_Enemy_Static_Data: HitMontage 컬럼 추가 후 에너미별 몽타주 할당
```

## INTEGRATION_POINTS
```yaml
owner:       AEnemyBaseCharacter
entry:       ApplyStatData() — DT 로드 직후 / ApplyHitReact() — 피격 진입
depends_on:  UGameDataSubsystem, FEnemyStaticData
ref_pattern: ApplyKnockdown() + KnockdownMontage 패턴 동일 구조 (로드만 DT data-driven)
arch_impact:
  - CLASS_REGISTRY: AEnemyBaseCharacter 책임에 "피격 몽타주 재생" 추가
```

## FLOW
```
[EnemyAttributeSet::PostGameplayEffectExecute]
    │  CC 태그 없음
    ▼
AEnemyBaseCharacter::ApplyHitReact(ImpactDir)
    ├─ HitMontage 유효 → PlayAnimMontage(HitMontage)
    │   없음           → 생략 (경고 없음)
    ├─ LaunchCharacter(ImpactDir * KnockbackForce)
    │   // [히트스탑 주석처리] CustomTimeDilation = 0 → 복원 타이머
    └─ MaterialEmissiveFlash()

[ApplyStatData — 초기화 시]
    DT 조회 성공
    └─ EnemyData.HitMontage.IsNull() == false
           → LoadSynchronous() → this->HitMontage 캐싱
         true → 캐싱 생략 (null 허용)
```

## SCHEMA
```
DataTable: DT_Enemy_Static_Data (FEnemyStaticData 신규 컬럼)
| 컬럼       | 타입                        | 기본값 | 설명                          |
|------------|-----------------------------|--------|-------------------------------|
| HitMontage | TSoftObjectPtr<UAnimMontage>| null   | 일반 피격 몽타주. 미할당 시 생략 |
```

## EDGE_CASES
```
| 상황                        | 처리                              | 근거           |
|-----------------------------|-----------------------------------|----------------|
| HitMontage 미할당           | 재생 생략, 경고 없음               | 선택 사항      |
| 연속 피격 (빠른 연타)        | 매번 처음부터 재시작               | 사용자 확정    |
| 히트스탑 코드               | 주석처리 유지 (테스트 후 제거 결정) | 사용자 지시    |
| ApplyKnockdown 중 ApplyHitReact 호출 | EnemyAttributeSet에서 분기됨 — 중복 없음 | 기존 로직 |
```

## REVIEW_NOTES
```
기획서 일관성: ✓ (DT_EnemyResource.HitMontage → FEnemyStaticData 통합 사전 합의)
누락 예외처리: 없음
기획서 정정:   없음
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
