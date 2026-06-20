# PLAN_CharacterMeshApply_v1.0
```yaml
date:    2026-05-03
sprint:  SPRINT-1
status:  ACTIVE
designs: []
```

## GOAL
> DT_CharacterStatic의 Mesh/AnimBP 필드를 인게임 진입 시 RSGameMode::InitializePlayer에서 PlayerCharacter에 동적으로 적용한다.

## SCOPE
```yaml
new_files:      []
modified_files:
  - Source/RoastStaffGAS/Public/Core/RSGameMode.h
  - Source/RoastStaffGAS/Private/Core/RSGameMode.cpp
new_datatables: []
new_tags:       []
```

## INTEGRATION_POINTS
```yaml
owner:       ARSGameMode
entry:       InitializePlayer(FName CharID)
depends_on:  UGameDataSubsystem::GetCharacterStaticData, ARSPlayerCharacter::GetMesh
ref_pattern: InitDefaultWeapon — GDS->GetCharacterStaticData 동일 패턴
arch_impact: |
  CLASS_REGISTRY: ARSGameMode 책임란에 "캐릭터 Mesh/AnimBP 동적 적용" 추가
  INTEGRATION_MAP: ARSGameMode::ApplyCharacterMesh → ARSPlayerCharacter::GetMesh() 신규
```

## FLOW
```
InitializePlayer(CharID)
    │
    ├─ PS->ApplyCharacterStats(CharID)
    ├─ ApplyCharacterMesh(CharID)        ← 신규
    │     │
    │     ├─ GDS->GetCharacterStaticData(CharID, CharData) 실패 → KHS_WARN + return
    │     ├─ CharData.Mesh.IsNull()      → KHS_WARN + return
    │     ├─ CharData.AnimBP.IsNull()    → KHS_WARN + return
    │     ├─ PC->GetPawn<ARSPlayerCharacter>() 실패 → KHS_WARN + return
    │     ├─ Mesh.LoadSynchronous()      → GetMesh()->SetSkeletalMesh
    │     └─ AnimBP.LoadSynchronous()    → GetMesh()->SetAnimInstanceClass
    └─ InitDefaultWeapon(CharID)
```

## EDGE_CASES
```
| 상황                          | 처리                           | 근거             |
|-------------------------------|--------------------------------|------------------|
| DT 행 없음                    | KHS_WARN + return              | 엄격 정책 합의   |
| Mesh null                     | KHS_WARN + return              | 엄격 정책 합의   |
| AnimBP null                   | KHS_WARN + return              | 엄격 정책 합의   |
| PC->GetPawn 실패              | KHS_WARN + return              | L1 null 체크     |
| 런중 캐릭터 교체              | 미지원 (1회성 진입 한정)       | 범위 외          |
```

## REVIEW_NOTES
```
기획서 일관성: ✓ (기술적 연동 작업, 기획서 없음)
누락 예외처리: 없음
기획서 정정:   없음
Gemini 반영:   해당 없음
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
