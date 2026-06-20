# PLAN_EnemyExpansion_v1.0
```yaml
date:    2026-04-06
sprint:  SPRINT-5
status:  ACTIVE
designs: [AI_에너미 시스템 기획 v1.1.md, 스킬 시스템 기획 v1.4.md, 게임 데이터 시스템 기획 v1.2.md]
```

## GOAL
> ARangedEnemy / AEliteEnemy / ABossEnemy 3종 신규 제작 + 에너미 전용 투사체 풀링 + 각 AI 행동트리 구현으로 인게임 전투 다양성 확보.

## SCOPE
```yaml
new_files:
  - Source/RoastStaffGAS/Public/Character/Enemy/RangedEnemy.h
  - Source/RoastStaffGAS/Private/Character/Enemy/RangedEnemy.cpp
  - Source/RoastStaffGAS/Public/Character/Enemy/EliteEnemy.h
  - Source/RoastStaffGAS/Private/Character/Enemy/EliteEnemy.cpp
  - Source/RoastStaffGAS/Public/Character/Enemy/BossEnemy.h
  - Source/RoastStaffGAS/Private/Character/Enemy/BossEnemy.cpp
  - Source/RoastStaffGAS/Public/Objects/Projectile/EnemyProjectile.h
  - Source/RoastStaffGAS/Private/Objects/Projectile/EnemyProjectile.cpp
  - Source/RoastStaffGAS/Public/AI/BTTask_RangedReposition.h
  - Source/RoastStaffGAS/Private/AI/BTTask_RangedReposition.cpp
  - Source/RoastStaffGAS/Public/AI/BTTask_FireProjectile.h
  - Source/RoastStaffGAS/Private/AI/BTTask_FireProjectile.cpp
  - Source/RoastStaffGAS/Public/AI/BTTask_MeleeCharge.h
  - Source/RoastStaffGAS/Private/AI/BTTask_MeleeCharge.cpp
  - Source/RoastStaffGAS/Public/AI/BTTask_ExecuteShockwave.h
  - Source/RoastStaffGAS/Private/AI/BTTask_ExecuteShockwave.cpp
  - Source/RoastStaffGAS/Public/AI/BTDecorator_ShockwaveReady.h
  - Source/RoastStaffGAS/Private/AI/BTDecorator_ShockwaveReady.cpp
  - Source/RoastStaffGAS/Public/AI/BTDecorator_IsPhase2.h
  - Source/RoastStaffGAS/Private/AI/BTDecorator_IsPhase2.cpp
  - Source/RoastStaffGAS/Public/AI/BTDecorator_RandomChance.h
  - Source/RoastStaffGAS/Private/AI/BTDecorator_RandomChance.cpp

modified_files:
  - Source/RoastStaffGAS/Public/Data/DataTableStructs.h        # FEnemyStaticData(bIsBoss) + FEnemyExtData USTRUCT
  - Source/RoastStaffGAS/Public/Data/EnumTypes.h               # EAIType::BOSS 추가
  - Source/RoastStaffGAS/Public/Subsystems/GameDataSubsystem.h # GetEnemyExtData 선언
  - Source/RoastStaffGAS/Private/Subsystems/GameDataSubsystem.cpp
  - Source/RoastStaffGAS/Private/Core/RSGameMode.cpp           # AEnemyProjectile 풀 사전 등록
  - Source/RoastStaffGAS/Public/System/EnemySpawner.h          # 보스 HUD 연동
  - Source/RoastStaffGAS/Private/System/EnemySpawner.cpp

new_datatables:
  - DT_EnemyExtData (FEnemyExtData — Ranged/Elite/Boss 확장 수치)

new_tags: []
```

## 에너미 공격 패턴 확정
```
MeleeEnemy  (기존): Chase → 근접 공격
RangedEnemy (신규): 거리 유지 → 투사체
EliteEnemy  (신규): 거리 유지(기본) + 확률적 Chase → 강력 근접 공격
BossEnemy   (신규):
  Phase1: Chase + Shockwave (근접/범위)
  Phase2: Chase → 8방향 투사체(중거리 우선) or Shockwave(근접범위 진입 시 우선)
```

## FLOW

### RangedEnemy
```
[BT_RangedEnemy]
    │
    ▼
BTTask_RangedReposition
    ├─ 거리 < PreferredRange  → 후퇴 이동
    ├─ 거리 > MaxAttackRange  → 전진 이동
    └─ 범위 내               → Succeed 즉시
    │
    ▼
BTTask_FireProjectile (AttackCooldown 서비스로 제어)
    └─ ARangedEnemy::FireProjectile()
         ├─ PoolingSubsystem.AcquireActor<AEnemyProjectile>()
         │    └─ 풀 고갈 → 경고 로그 + 스킵
         └─ AEnemyProjectile::InitEnemyProjectile(Dir, Speed, Lifetime, Damage)
              └─ OnHit → 플레이어 ASC GE 적용 → ReturnToPool
```

### EliteEnemy
```
[BT_EliteEnemy] Parallel 실행
    ├─ [기본 루프] BTTask_RangedReposition → BTTask_FireProjectile
    └─ [확률 브랜치] BTDecorator_RandomChance
         └─ Succeed 시 → BTTask_MeleeCharge
              └─ AEliteEnemy::MeleeCharge()
                   └─ 빠른 이동 → 근접 범위 진입 → 강력 MeleeAttack GE 적용
```

### BossEnemy Phase1
```
[BT_BossEnemy Phase1]
    │
    ▼
Chase (플레이어 추적)
    │
    ├─ 거리 ≤ ShockwaveRadius → BTTask_ExecuteShockwave
    │    └─ PrepareTime 선딜 → ABossEnemy::ExecuteShockwave()
    └─ 계속 Chase
```

### BossEnemy Phase2 전환
```
[ABossEnemy::OnHealthChanged()]
    └─ HP비율 ≤ Phase2HPRatio + !bPhaseTransitioned
         → StopAI()
         → Phase2TransitionMontage 재생 + Phase2TransitionFX 스폰
         → ApplyPhase2Params() (MoveSpeedMult / DamageMult 적용)
         → BBKey bIsPhase2 = true
         → StartAI()
         → bPhaseTransitioned = true
```

### BossEnemy Phase2
```
[BT_BossEnemy Phase2] BTDecorator_IsPhase2로 브랜치 진입
    │
    ▼
Chase (계속)
    │
    ├─ 거리 ≤ ShockwaveRadius (근접) → BTTask_ExecuteShockwave (우선)
    └─ 거리 ≤ MaxAttackRange (중거리) → BTTask_Fire8WayProjectile
         └─ ABossEnemy::Fire8WayProjectile()
              └─ 45도 간격 8방향 AEnemyProjectile 발사 (Phase2DamageMult 적용)
```

## SCHEMA
```
DataTable: DT_EnemyExtData  (Row Key = EnemyID)
| 컬럼                  | 타입                          | 사용 대상      | 기본값 |
|-----------------------|-------------------------------|----------------|--------|
| PreferredRange        | float                         | Ranged, Elite, Boss | 0 |
| MaxAttackRange        | float                         | Ranged, Elite, Boss | 0 |
| ProjectileSpeed       | float                         | Ranged, Elite, Boss | 0 |
| ProjectileLifetime    | float                         | Ranged, Elite, Boss | 0 |
| ShockwaveRadius       | float                         | Boss           | 0      |
| ShockwaveDamage       | float                         | Boss           | 0      |
| ShockwaveCooldown     | float                         | Boss           | 0      |
| ShockwavePrepareTime  | float                         | Boss           | 0      |
| Phase2HPRatio         | float                         | Boss           | 0.5    |
| Phase2MoveSpeedMult   | float                         | Boss           | 1.0    |
| Phase2DamageMult      | float                         | Boss           | 1.0    |
| Phase2TransitionFX    | TSoftObjectPtr<UNiagaraSystem>| Boss           | null   |
| Phase2TransitionMontage | TSoftObjectPtr<UAnimMontage>| Boss           | null   |

DataTable: DT_Enemy (기존, 컬럼 추가)
| 추가 컬럼 | 타입 | 기본값 |
|-----------|------|--------|
| bIsBoss   | bool | false  |
```

## EDGE_CASES
```
| 상황                              | 처리                                      | 기획서 근거 |
|-----------------------------------|-------------------------------------------|-------------|
| AEnemyProjectile 풀 고갈          | 경고 로그 + 발사 스킵 (크래시 방지)       | 풀링 정책   |
| Phase2 전환 중 보스 사망           | HandleDeath 오버라이드 → 연출 중단 즉시   | -           |
| EliteEnemy 근접 돌진 중 사망       | HandleDeath → 돌진 중단                   | -           |
| bPhaseTransitioned 중복 트리거     | bool 플래그로 1회만 실행                  | -           |
| UIManager ShowBossHUD 미존재       | MODULE-8 착수 전 UIManager 확장 선행      | -           |
```

## REVIEW_NOTES
```
기획서 일관성: ✗
  - DT_Enemy_Ranged/Elite/Boss 3개 테이블 → FEnemyExtData 단일 통합 (사용자 확정)
  - DT_Enemy_StatusEffect 미구현 (이번 범위 제외)
  - EAIType::BOSS 추가 (기획서에 미정의 → 사용자 확정)
  - EliteEnemy 원거리 투사체 로직 (기획서 미정의 → 사용자 확정)

누락 예외처리:
  - UIManager ShowBossHUD/HideBossHUD 존재 여부 미확인 → MODULE-8 전 확인 필요

기획서 정정:
  - AI_에너미 시스템 기획 v1.1 DT 섹션: 3개 별도 테이블 → FEnemyExtData 단일 통합으로 수정 권장
  - EliteEnemy 공격 패턴 섹션: 원거리 투사체 + 확률 근접 돌진 추가 권장
```

---
## REVIEW_STATUS
```
| 단계          | 상태 | 날짜       | 주요 지적         |
|---------------|------|------------|-------------------|
| Cross-Review  | -    | -          | -                 |
| Senior-Review | -    | -          | -                 |
| Learn-Report  | -    | -          | -                 |

verdict:   PENDING
unresolved: []
```
