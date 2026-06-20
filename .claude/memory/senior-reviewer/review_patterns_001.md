---
name: 프로젝트 전체 리뷰 반복 패턴
description: SR_2026-03-23~25에서 발견된 반복 가능 패턴 - UPROPERTY 누락, 하드코딩, 풀링 리셋 누락, 기획서 경계값 불일치, switch fall-through, 배열 다목적 오용
type: feedback
---

## 발견된 패턴 (2026-03-23)

1. **TMap/TArray 컨테이너의 UPROPERTY() 누락**: ActorPool에서 발견. UObject 포인터를 담는 컨테이너는 반드시 UPROPERTY() 필요.
   **Why:** GC가 루트에서 도달 불가한 UObject를 수거함
   **How to apply:** 새 TMap/TArray<TObjectPtr> 멤버 추가 시 UPROPERTY() 여부 반드시 확인

2. **const 멤버 하드코딩**: SPAWN_OFFSET = 200.f. CLAUDE.md 하드코딩 금지 규칙 위반.
   **Why:** 데이터 드리븐 원칙
   **How to apply:** 수치 상수는 DataTable 또는 EditDefaultsOnly로 외부화

3. **무한 for 루프 패턴**: CheckIsActiveSlot에서 `for(;;)` + null break. 컨테이너 크기 기반 루프가 더 안전.
   **Why:** 데이터 구조 변경 시 무한 루프 위험
   **How to apply:** 슬롯/배열 순회 시 명시적 상한 사용

4. **기획서 대조 필수**: 자동 타겟팅 적 없을 때 동작이 기획서와 불일치 발견.
   **Why:** 기획서에서 "발동 생략" 명시했으나 코드는 전방 소환
   **How to apply:** GA 동작 분기마다 기획서 예외처리 목록과 대조

## 발견된 패턴 (2026-03-24)

5. **USTRUCT 내 TWeakObjectPtr UPROPERTY() 누락**: FProjectileInitData.HomingTarget에서 발견. TWeakObjectPtr도 GC 추적을 위해 UPROPERTY() 필요.
   **Why:** UPROPERTY 없으면 GC가 참조를 추적하지 않아 IsValid() 오동작 가능
   **How to apply:** USTRUCT에 UObject 관련 스마트 포인터 추가 시 항상 UPROPERTY() 확인 (패턴 1의 확장)

6. **OnPoolDeactivate 리셋 불완전**: HOMING 설정(bIsHomingProjectile, HomingTargetComponent)과 ARC 설정(ProjectileGravityScale)이 풀 반환 시 리셋되지 않아 다른 타입으로 재사용 시 오동작.
   **Why:** 풀링은 Spawn/Destroy 대신 Activate/Deactivate이므로, 이전 상태가 잔류
   **How to apply:** 새 컴포넌트 프로퍼티를 InitProjectile에서 설정할 때, OnPoolDeactivate에도 리셋 코드 추가 여부를 반드시 확인

7. **기획서 경계값 연산자 불일치**: "30% 미만" vs `> 0.3f`, "70% 이상" vs `> 0.7f`. 기획서의 "미만/이상" 표현과 코드의 비교 연산자가 불일치.
   **Why:** 기획서가 한글로 "미만(<)", "이상(>=)" 을 명시할 때 코드가 "초과(>)"로 구현하면 경계값에서 다른 결과
   **How to apply:** 기획서 데미지 감쇠/구간 규칙 구현 시 경계값 포함 여부를 기획서 문구와 정확히 대조

8. **다중 분기의 bSuccess 덮어쓰기**: HandleExtraParametersByType에서 독립적 if문으로 분기할 때, 이전 실패 결과가 이후 성공으로 덮어써짐.
   **Why:** 독립 분기 결과를 단일 변수로 관리하면 이전 실패가 소실됨
   **How to apply:** 독립적 파라미터 조회 시 각 결과를 AND 연산하거나, 실패 즉시 early return

## 발견된 패턴 (2026-03-25)

9. **switch case break 누락 (fall-through)**: GA_ProjectileAttack.cpp HandleExtraParametersByType의 EHitType::PIERCE 케이스에 break 누락.
   **Why:** C++ switch는 명시적 break 없이 다음 case로 실행이 흘러내림. default에 로직 추가 시 PIERCE가 의도치 않은 분기 실행
   **How to apply:** switch case 블록 작성 시 항상 break 또는 [[fallthrough]] 명시. 특히 새 타입 케이스 추가 후 리뷰 시 break 유무를 첫 번째로 체크

10. **물리 배열(MoveIgnoreActors)을 카운터로 오용**: HandlePierceHit에서 CopyArrayOfMoveIgnoreActors().Num()으로 타격 횟수를 추적. 발사자가 배열에 선등록되어 HitCount가 항상 1 오염됨. 기획서 "첫 타격 100%" 요구사항 불일치.
    **Why:** MoveIgnoreActors는 물리 충돌 제외 목적의 배열이지 카운팅 도구가 아님. 배열 원소에 발사자 등 비전투 액터가 섞일 수 있음
    **How to apply:** 타격 횟수 추적은 전용 int32 멤버 변수로 분리. 물리 배열과 카운팅 책임을 혼합하지 말 것. OnPoolDeactivate에서 해당 변수도 리셋 필수

11. **DataTableStructs 기본값 미설정**: FSkillAttackHitTypeParamsPierce의 PierceCount, DamageDecay에 기본값 없음. DataTable 누락 행 로드 시 0으로 초기화되어 즉시 소멸 또는 무한 감쇠.
    **Why:** UE DataTable에서 존재하지 않는 행을 로드하면 GENERATED_BODY() 기본 생성자가 호출되어 0 초기화
    **How to apply:** FTableRowBase 상속 구조체의 수치 필드에는 항상 안전한 기본값 지정 (PierceCount=1, HitRadius=100.f 등)

## 발견된 패턴 (2026-03-30) — SR_WeaponUpgradeReplace

12. **UI 오픈/종료 쌍 처리 누락 (TimeDilation)**: RSPlayerController::OnWeaponSlotFull에서 교체 UI 오픈 시 TimeDilation = 0.f 미적용. 레벨업 UI와 동일 패턴인데 교체 UI만 빠진 케이스.
    **Why:** 서로 다른 함수에 각각 TimeDilation을 넣는 분산 패턴 → 신규 UI 추가 시 누락 위험
    **How to apply:** UI 오픈+일시정지는 항상 쌍으로 체크리스트 적용. "UI 오픈 → TimeDilation/SetPause 설정 여부" 리뷰 시 최우선 확인 항목으로 추가.

13. **PLAN 문서와 코드 구현의 RowName 규칙 불일치**: PLAN SCHEMA 섹션 "Lv1 WeaponID 기준" 기술 vs 실제 코드 EWeaponBaseType DisplayName 기준 조회 불일치. 코드 구현 후 PLAN 문서 미갱신.
    **Why:** 구현 단계에서 설계가 변경될 때 PLAN 문서를 즉시 업데이트하지 않으면 문서-코드 드리프트 발생
    **How to apply:** CurveTable/DataTable RowName 규칙 구현 완료 후 PLAN SCHEMA 섹션과 반드시 대조. 코드가 실제 키라면 문서를 코드에 맞춰 갱신.
