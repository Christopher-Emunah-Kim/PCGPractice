# PLAN_PullVortexFXZOffset_v1.0
```yaml
date:    2026-05-06
sprint:  SPRINT-N
status:  ACTIVE
designs: []
```

## GOAL
> PullVortexActor FX가 지형 표면에 묻히는 현상을 Z 오프셋 프로퍼티 추가로 수정한다.

## SCOPE
```yaml
new_files:      []
modified_files:
  - Source/RoastStaffGAS/Public/Objects/GroundEffect/PullVortexActor.h
  - Source/RoastStaffGAS/Private/Objects/GroundEffect/PullVortexActor.cpp
new_datatables: []
new_tags:       []
```

## INTEGRATION_POINTS
```yaml
owner:       APullVortexActor
entry:       InitEffect() — ISkillEffectInterface
depends_on:  UNiagaraFunctionLibrary::SpawnSystemAttached
ref_pattern: 기존 EditDefaultsOnly float 프로퍼티 패턴 (PullRadius, PullStrength)
arch_impact: 없음 — ARCH_SNAPSHOT 갱신 불필요 (내부 구현 세부사항)
```

## FLOW
```
InitEffect() 호출
    │
    ▼
SpawnSystemAttached(FX, Root, NAME_None,
    FVector(0.f, 0.f, FXSpawnZOffset),  ← 수정 (기존: ZeroVector)
    FRotator::ZeroRotator,
    EAttachLocation::SnapToTarget, true)
    │
    ▼
FX가 Actor 루트 기준 Z+30cm 위치에 부착
(PullTick/HitTick의 OverlapMultiByChannel 중심은 Actor 루트 유지 — 판정 범위 불변)
```

## EDGE_CASES
```
| 상황 | 처리 | 비고 |
|------|------|------|
| EAttachLocation::SnapToTarget에서 RelativeLocation 무시 | KeepRelativeOffset으로 교체 | 빌드 후 플레이테스트 확인 필요 |
| FXSpawnZOffset = 0 설정 시 | 오프셋 없음 — 기존 동작과 동일 | 의도적 하한값 없음 |
```

## REVIEW_NOTES
```
기획서 일관성: - (연관 기획서 없음)
누락 예외처리: 없음
기획서 정정:   없음
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
