# PLAN_EnemySpawnFix_v1.0
> 작성일: 2026-04-16
> 목표: EnemySpawner 스폰 위치 계산 버그 수정 + NavMesh 유효성 검사 추가

---

## 문제 요약

1. **Y축 오프셋 버그** (`EnemySpawner.cpp:190`) — `FMath::Sin(AngleRad)`에 `OffScreenDistance` 미곱. Y 오프셋이 -1~+1 유닛으로 고정되어 적이 플레이어 근처 오브젝트 내부에 스폰됨.
2. **NavMesh 유효성 검사 없음** — 계산된 위치가 NavMesh 위인지 확인하지 않아 이동 불가 지점에 스폰됨.
3. **Z축 고정 0** — 실제 맵 지형 높이 무시.

---

## 수정 범위

| 파일 | 변경 내용 |
|------|-----------|
| `Source/RoastStaffGAS/Private/System/EnemySpawner.cpp` | `CalculateOffScreenSpawnLocation` 재작성, `NavigationSystem.h` include 추가 |
| `Source/RoastStaffGAS/Public/System/EnemySpawner.h` | 함수 시그니처에 `MaxAttempts` 파라미터 추가 |
| `Source/RoastStaffGAS/Private/Character/Enemy/EnemyBaseCharacter.cpp` | `OnPoolDeactivate`에서 CharacterMovement 비활성화 추가 (풀 대기 중 낙하 방지) |
| `Source/RoastStaffGAS/Private/Character/Enemy/BossEnemy.cpp` | 진단 로그 추가 |
| `Source/RoastStaffGAS/Public/Character/Enemy/BossEnemy.h` | 진단용 Tick 선언 |
| `Source/RoastStaffGAS/Private/Core/RSGameMode.cpp` | OnPreWarmCompleted: 스트리밍 레벨 로드 완료 후 StartStageFlow |
| `Source/RoastStaffGAS/Public/Core/RSGameMode.h` | bWaitingForLevelLoad 플래그 + AreAllStreamingLevelsLoaded 선언 |
| `Source/RoastStaffGAS/Private/Subsystems/StageManagerSubsystem.cpp` | 프로파일링 북마크 추가 |

---

## 설계

`CalculateOffScreenSpawnLocation`:
1. 랜덤 각도 + `OffScreenDistance` 로 X/Y 모두 오프셋 계산 (버그 수정)
2. `UNavigationSystemV1::ProjectPointToNavigation()` 으로 NavMesh 위 유효 위치 투영
3. 투영 실패 시 각도를 바꿔 `MaxAttempts`회 재시도
4. 전부 실패 시 `FVector::ZeroVector` 반환

`SpawnEnemy`:
- `CalculateOffScreenSpawnLocation` 반환값이 `ZeroVector`이면 스폰 스킵 + KHS_WARN

---

## MODULE

- [x] MODULE-1: h 시그니처 수정 ✓
- [x] MODULE-2: cpp 버그 수정 + NavMesh 투영 로직 추가 ✓
- [x] MODULE-3: EnemyBaseCharacter OnPoolDeactivate Movement 정지 + OnPoolActivate 복원 ✓
- [x] MODULE-4: EnemySpawner Boss 직접 스폰 분기 (풀 바이패스) ✓
- [x] MODULE-5: RSGameMode OnPreWarmCompleted → 스트리밍 레벨 로드 대기 후 StartStageFlow ✓
